import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';

import '../ssh/host_key.dart';
import '../ssh/ssh_connection.dart';
import '../ssh/ssh_connection_state.dart';
import '../ssh/ssh_target.dart';
import 'output_coalescer.dart';
import 'terminal_modifiers.dart';

/// How many lines of scrollback a live session keeps.
///
/// Deliberately generous: the reason anyone scrolls up in a terminal is to
/// find something that has already gone past, and a buffer that drops it is a
/// buffer that was not worth having. Bounded all the same, because a session
/// left running `tail -f` for a day should not grow without limit.
const int kScrollbackLines = 5000;

/// What a session is doing, for the UI.
enum TerminalSessionStatus { connecting, running, closed, failed }

/// One interactive shell on one host, and the terminal it draws into.
///
/// This is the seam the prior-art survey argued for. Everything above it — the
/// terminal view, the tab strip, the key bar — talks to *this*, not to
/// `SSHSession`. What it needs from a transport is small and general: a byte
/// stream in, a byte sink out, a resize signal and a lifecycle. Mosh, or a
/// WebSocket bridge for web, can satisfy that contract later without the UI
/// learning anything new.
class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this.id,
    required this.title,
    required this.hostId,
    required this.connection,
    this.startupCommand,
    this.scrollbackLines = kScrollbackLines,
  }) {
    terminal = Terminal(maxLines: scrollbackLines);

    // Ctrl and Alt from the mobile modifier bar reach the terminal here, so
    // that a latched chord is translated by exactly the same chain as a
    // hardware one. See [LatchedModifierInputHandler].
    terminal.inputHandler = LatchedModifierInputHandler(modifiers);

    // Keystrokes and pasted text out to the remote shell.
    terminal.onOutput = (data) {
      final session = _session;
      if (session == null) return;
      session.write(Uint8List.fromList(const Utf8Encoder().convert(data)));
    };

    // The remote side has to be told the window changed, or full-screen
    // programs draw to the wrong size and everything wraps strangely.
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _session?.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

    _coalescer = OutputCoalescer(
      onData: (data) {
        _receivedOutput = true;
        terminal.write(data);
      },
    );

    _stateSubscription = connection.states.listen((state) {
      if (_disposed) return;
      _connectionState = state;
      if (state.status == SshConnectionStatus.disconnected &&
          _status == TerminalSessionStatus.running) {
        _writeNotice('\r\n[connection lost]\r\n');
        _status = TerminalSessionStatus.closed;
      }
      notifyListeners();
    });
  }

  /// Stable id, used as the tab's key.
  final String id;

  /// What the tab says — the host's label.
  final String title;

  /// The saved host this session is talking to.
  ///
  /// Kept alongside [connection] rather than parsed back out of [id] — port
  /// forwarding needs to find "is there already a live session to this
  /// host?" without depending on the id's format staying `hostId-counter`.
  final String hostId;

  final SshConnection connection;

  /// Run once the shell is open. `tmux new -A -s main` is the reason this
  /// exists: it is the practical answer to a phone killing a backgrounded app.
  final String? startupCommand;

  final int scrollbackLines;

  /// The terminal this session draws into. Owned here, so a tab that is
  /// scrolled off screen keeps its buffer.
  late final Terminal terminal;

  /// Ctrl and Alt latched by the mobile modifier bar, if any is on screen.
  ///
  /// Lives on the session rather than in the bar because the terminal's own
  /// input path has to see it — a key typed on the software keyboard never
  /// passes through the bar. See [TerminalModifiers].
  final modifiers = TerminalModifiers();

  late final OutputCoalescer _coalescer;
  StreamSubscription<SshConnectionState>? _stateSubscription;
  StreamSubscription<Uint8List>? _stdoutSubscription;
  StreamSubscription<Uint8List>? _stderrSubscription;
  SSHSession? _session;

  /// Set in [dispose]. A session's `done` future can complete *after* the tab
  /// was closed — the remote side hangs up while teardown is in flight — and
  /// notifying a disposed ChangeNotifier throws. Nothing is listening by then
  /// anyway.
  bool _disposed = false;

  /// Whether the remote side has ever sent anything.
  ///
  /// Decides where a notice belongs. With a scrollback full of output, a line
  /// marking where it stopped is genuinely useful — it says *when* the link
  /// died relative to what you were doing. With an empty buffer it is the same
  /// sentence the status bar is already showing, in red, twice.
  bool _receivedOutput = false;

  TerminalSessionStatus _status = TerminalSessionStatus.connecting;
  TerminalSessionStatus get status => _status;

  SshConnectionState _connectionState = const SshConnectionState.idle();
  SshConnectionState get connectionState => _connectionState;

  String? _error;

  /// Why the session failed, if it did. Safe to display — it never contains a
  /// credential.
  String? get error => _error;

  HostKeyRejected? _hostKeyRejection;

  /// Set when the failure was a refused host key.
  ///
  /// Kept as the typed cause rather than left inside the message, because a
  /// *changed* key needs its own dialog and its own words. Flattening it into
  /// a string would make the single most important failure this app reports
  /// indistinguishable from a network glitch.
  HostKeyRejected? get hostKeyRejection => _hostKeyRejection;

  SshTarget get target => connection.target;

  bool get isLive => _status == TerminalSessionStatus.running;

  /// Opens the shell.
  ///
  /// Safe to call again after a failure — that is the retry button.
  Future<void> start() async {
    if (_status == TerminalSessionStatus.running) return;
    _status = TerminalSessionStatus.connecting;
    _error = null;
    _hostKeyRejection = null;
    notifyListeners();

    try {
      final client = await connection.client();

      final session = await client.shell(
        pty: SSHPtyConfig(
          // 256 colours, because everything anyone will run in here assumes
          // them — a prompt, `ls --color`, vim, htop.
          type: 'xterm-256color',
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
      );
      _session = session;

      _stdoutSubscription = session.stdout.listen(
        _coalescer.add,
        onError: (Object _) {},
      );
      // stderr goes to the same terminal, interleaved, exactly as a real tty
      // does. Splitting them would put a command's errors somewhere the user
      // is not looking.
      _stderrSubscription = session.stderr.listen(
        _coalescer.add,
        onError: (Object _) {},
      );

      unawaited(session.done.then((_) => _handleClosed()));

      _status = TerminalSessionStatus.running;
      notifyListeners();

      final command = startupCommand?.trim();
      if (command != null && command.isNotEmpty) {
        session.write(Uint8List.fromList(utf8.encode('$command\n')));
      }
    } on SshConnectionException catch (e) {
      final cause = e.cause;
      if (cause is HostKeyRejected) _hostKeyRejection = cause;
      _fail(e.message);
    } on Object catch (e) {
      _fail('Could not open a shell: ${e.runtimeType}');
    }
  }

  /// Sends raw bytes, for the key bar's Ctrl and escape sequences.
  void send(String data) {
    final session = _session;
    if (session == null) return;
    session.write(Uint8List.fromList(utf8.encode(data)));
  }

  /// Ends the session but leaves the tab, so the scrollback can still be read.
  Future<void> disconnect() async {
    _session?.close();
    await connection.reset();
    _handleClosed();
  }

  void _handleClosed() {
    if (_disposed) return;
    if (_status == TerminalSessionStatus.failed) return;
    if (_status == TerminalSessionStatus.closed) return;
    _status = TerminalSessionStatus.closed;
    _writeNotice('\r\n[session closed]\r\n');
    notifyListeners();
  }

  void _fail(String message) {
    if (_disposed) return;
    _status = TerminalSessionStatus.failed;
    _error = message;
    // Into the terminal as well as onto the status line: the scrollback is
    // where a user looks for what happened, and an error that exists only in a
    // banner is gone as soon as the banner is.
    _writeNotice('\r\n\x1b[31m$message\x1b[0m\r\n');
    notifyListeners();
  }

  /// Writes app text into the terminal, bypassing the coalescer so a notice
  /// cannot be dropped by the pending-byte cap.
  ///
  /// Skipped entirely when nothing has ever arrived: the pane's status bar is
  /// already saying it, and a failure printed into an otherwise blank terminal
  /// is the same sentence twice.
  void _writeNotice(String text) {
    if (!_receivedOutput) return;
    terminal.write(text);
  }

  @override
  void dispose() {
    _disposed = true;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _stateSubscription?.cancel();
    _coalescer.dispose();
    modifiers.dispose();
    _session?.close();
    unawaited(connection.close());
    super.dispose();
  }
}
