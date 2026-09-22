import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';

import '../ssh/host_key.dart';
import '../ssh/reconnect_loop.dart';
import '../ssh/reconnect_policy.dart';
import '../ssh/ssh_connection.dart';
import '../ssh/ssh_connection_state.dart';
import '../ssh/ssh_target.dart';
import 'output_coalescer.dart';
import 'remote_shell.dart';
import 'terminal_modifiers.dart';
import 'tmux_commands.dart';

/// How many lines of scrollback a live session keeps.
///
/// Deliberately generous: the reason anyone scrolls up in a terminal is to
/// find something that has already gone past, and a buffer that drops it is a
/// buffer that was not worth having. Bounded all the same, because a session
/// left running `tail -f` for a day should not grow without limit.
const int kScrollbackLines = 5000;

/// What a session is doing, for the UI.
///
/// A session waiting to reconnect is [closed] with [TerminalSession.reconnect]
/// active; one attempting to is [connecting] with it active.
enum TerminalSessionStatus { connecting, running, closed, failed }

/// The lines a session writes into its own terminal.
///
/// Supplied by whoever creates the session, because they are user-facing and
/// this layer has no localizations. The defaults are for tests.
class TerminalNotices {
  const TerminalNotices({
    this.connectionLost = '[connection lost — reconnecting]',
    this.sessionEnded = '[session ended]',
    this.sessionClosed = '[session closed]',
    this.reconnected = '[reconnected]',
    this.tmuxUnavailable =
        '[tmux is not installed here; this session will not survive a '
        'dropped connection]',
    this.tmuxSessionGone =
        '[the session kept on the server has ended; this is a new shell]',
  });

  /// The tab expected to pick up a session kept on the server — reopened
  /// from last time, or attached from the server's list — and it was gone.
  final String tmuxSessionGone;

  /// The link dropped, and the session is coming back by itself.
  final String connectionLost;

  /// The remote shell ended — someone typed `exit`.
  final String sessionEnded;

  /// The user ended the session.
  final String sessionClosed;

  /// A dropped session is back, on a fresh shell.
  final String reconnected;

  /// Keeping the session on the server was asked for and is not possible.
  final String tmuxUnavailable;
}

/// One interactive shell on one host, and the terminal it draws into.
///
/// This is the seam the prior-art survey argued for. Everything above it — the
/// terminal view, the tab strip, the key bar — talks to *this*, not to
/// `SSHSession`. What it needs from a transport is small and general: a byte
/// stream in, a byte sink out, a resize signal and a lifecycle. Mosh, or a
/// WebSocket bridge for web, can satisfy that contract later without the UI
/// learning anything new.
///
/// **Surviving a drop.** A session that was running and loses its link comes
/// back by itself, in the same tab and the same buffer, on the schedule in
/// [ReconnectPolicy]. With [keepOnServer] the shell lives in tmux on the
/// server, so what comes back is the *same* shell, with whatever was running
/// in it still running. A session the user ended, or whose shell exited, stays
/// ended.
class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this.id,
    required this.title,
    required this.hostId,
    required this.connection,
    this.startupCommand,
    this.scrollbackLines = kScrollbackLines,
    this.keepOnServer = false,
    String? tmuxName,
    this.env = const {},
    this.resuming = false,
    this.ownsTmuxSession = true,
    this.notices = const TerminalNotices(),
    ReconnectPolicy reconnectPolicy = const ReconnectPolicy(),
    @visibleForTesting ShellLauncher? launcher,
    @visibleForTesting Future<bool> Function()? probe,
    @visibleForTesting ReconnectTimerFactory? reconnectTimer,
    @visibleForTesting DateTime Function()? clock,
  }) : tmuxName = tmuxName ?? tmuxSafeName('$kTmuxNamePrefix$id') {
    _launcher =
        launcher ??
        SshShellLauncher(
          connection: connection,
          keepOnServer: keepOnServer,
          tmuxName: this.tmuxName,
          env: env,
          ownsSession: ownsTmuxSession,
        );
    _probe = probe ?? (() => connection.probe());
    reconnect = ReconnectLoop(
      attempt: _reconnectOnce,
      policy: reconnectPolicy,
      clock: clock,
      timer: reconnectTimer,
      onChanged: _changed,
      onGaveUp: _gaveUp,
    );

    terminal = Terminal(maxLines: scrollbackLines);

    // Ctrl and Alt from the mobile modifier bar reach the terminal here, so
    // that a latched chord is translated by exactly the same chain as a
    // hardware one. See [LatchedModifierInputHandler].
    terminal.inputHandler = LatchedModifierInputHandler(modifiers);

    // Keystrokes and pasted text out to the remote shell.
    terminal.onOutput = (data) {
      final shell = _shell;
      if (shell == null) return;
      shell.write(Uint8List.fromList(const Utf8Encoder().convert(data)));
    };

    // The remote side has to be told the window changed, or full-screen
    // programs draw to the wrong size and everything wraps strangely.
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _shell?.resize(width, height, pixelWidth, pixelHeight);
    };

    _coalescer = OutputCoalescer(
      onData: (data) {
        _receivedOutput = true;
        terminal.write(data);
      },
    );

    // Status only. The *shell* ending is what decides whether this session
    // is over — see [_onShellDone] — because the connection going away is
    // one of several ways that can happen and not the most informative.
    _stateSubscription = connection.states.listen((state) {
      if (_disposed) return;
      _connectionState = state;
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

  /// Run in each *new* shell. With [keepOnServer], only when the tmux session
  /// is created — never on a reattach, where it already ran and whatever it
  /// started is still going.
  final String? startupCommand;

  final int scrollbackLines;

  /// Whether this tab's shell is kept running on the server, in tmux, so a
  /// reconnect reattaches to it. Falls back to a plain shell where the
  /// server has no tmux.
  final bool keepOnServer;

  /// The tmux session this tab lives in on the server, when [keepOnServer].
  ///
  /// Chosen by whoever opens the tab — `sshetu-<device>-<tab>`, see
  /// `tmux_names.dart` — and fixed for its life, which is what lets a
  /// reconnect, or a relaunch, find the same session again.
  final String tmuxName;

  /// The host's environment variables, set in each new shell.
  final Map<String, String> env;

  /// Whether this tab was opened to pick up an existing session — reopened
  /// from last time, or attached from the server's list. If the session is
  /// gone, the fresh shell says so instead of passing for the old one.
  final bool resuming;

  /// Whether closing the tab ends [tmuxName] on the server. False for a
  /// session attached from the server's list, which the tab only borrowed.
  final bool ownsTmuxSession;

  final TerminalNotices notices;

  /// The terminal this session draws into. Owned here, so a tab that is
  /// scrolled off screen keeps its buffer.
  late final Terminal terminal;

  /// Ctrl and Alt latched by the mobile modifier bar, if any is on screen.
  ///
  /// Lives on the session rather than in the bar because the terminal's own
  /// input path has to see it — a key typed on the software keyboard never
  /// passes through the bar. See [TerminalModifiers].
  final modifiers = TerminalModifiers();

  /// The automatic reconnect, for the pane's status bar: whether one is
  /// under way, the countdown, the attempt count.
  late final ReconnectLoop reconnect;

  late final ShellLauncher _launcher;
  late final Future<bool> Function() _probe;
  late final OutputCoalescer _coalescer;
  StreamSubscription<SshConnectionState>? _stateSubscription;
  StreamSubscription<Uint8List>? _stdoutSubscription;
  StreamSubscription<Uint8List>? _stderrSubscription;
  RemoteShell? _shell;

  /// Set in [dispose]. A session's `done` future can complete *after* the tab
  /// was closed — the remote side hangs up while teardown is in flight — and
  /// notifying a disposed ChangeNotifier throws. Nothing is listening by then
  /// anyway.
  bool _disposed = false;

  /// Set while the user is ending the session, so the shell closing is read
  /// as their decision and not as a drop to recover from.
  bool _ending = false;

  /// Whether the remote side has ever sent anything.
  ///
  /// Decides where a notice belongs. With a scrollback full of output, a line
  /// marking where it stopped is genuinely useful — it says *when* the link
  /// died relative to what you were doing. With an empty buffer it is the same
  /// sentence the status bar is already showing, in red, twice.
  bool _receivedOutput = false;

  /// Whether the "no tmux here" line has been printed. Once per tab is
  /// information; once per reconnect is nagging.
  bool _toldNoTmux = false;

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

  bool _resumeFailed = false;

  /// Set when [resuming] found no session to pick up and started a new one.
  bool get resumeFailed => _resumeFailed;

  ShellOrigin? _origin;

  /// How the current (or last) shell was opened — plain, or in tmux.
  ShellOrigin? get shellOrigin => _origin;

  SshTarget get target => connection.target;

  bool get isLive => _status == TerminalSessionStatus.running;

  /// Opens the shell.
  ///
  /// Safe to call again after a failure — that is the retry button. A manual
  /// start is one attempt: it takes over from any automatic reconnect rather
  /// than running beside it.
  Future<void> start() async {
    if (_status == TerminalSessionStatus.running) return;
    if (reconnect.phase == ReconnectPhase.connecting) return;
    reconnect.stop();
    _ending = false;
    try {
      await _open();
    } on Object catch (e) {
      _failWith(e);
    }
  }

  /// One automatic attempt. Throws on failure so the loop can decide what
  /// comes next; the tab goes back to "waiting" meanwhile.
  Future<void> _reconnectOnce() async {
    try {
      await _open();
    } on Object {
      if (!_disposed && _status == TerminalSessionStatus.connecting) {
        _status = TerminalSessionStatus.closed;
      }
      rethrow;
    }
  }

  Future<void> _open() async {
    _status = TerminalSessionStatus.connecting;
    _error = null;
    _hostKeyRejection = null;
    notifyListeners();

    final reconnecting = _shell != null || _origin != null;
    final shell = await _launcher.open(
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
    );
    if (_disposed) {
      shell.close();
      return;
    }
    _detachShell();
    _shell = shell;
    _origin = shell.origin;

    final history = shell.origin == ShellOrigin.tmuxReattached
        ? shell.history
        : null;
    if (history != null) {
      _replaceWithHistory(history, reconnecting: reconnecting);
    } else if (reconnecting) {
      if (shell.origin == ShellOrigin.tmuxReattached) {
        // tmux clears the screen when it attaches and redraws the pane as it
        // is now. Pushing what is on screen up into the scrollback first
        // keeps the last thing seen before the drop — the notice included —
        // instead of letting that redraw erase it.
        _writeNotice('${notices.reconnected}\r\n');
        _writeNotice('\r\n' * terminal.viewHeight);
      } else {
        _writeNotice('${notices.reconnected}\r\n');
      }
    }
    if (shell.origin == ShellOrigin.plainWithoutTmux && !_toldNoTmux) {
      _toldNoTmux = true;
      // Dim, and written even into an empty terminal: nothing else says it.
      terminal.write('\x1b[2m${notices.tmuxUnavailable}\x1b[0m\r\n');
    }
    // Only on the first shell: a later reconnect that creates the session
    // anew has already been explained by the ordinary reconnect notice.
    if (resuming &&
        !reconnecting &&
        shell.origin != ShellOrigin.tmuxReattached &&
        shell.origin != ShellOrigin.plainWithoutTmux) {
      _resumeFailed = true;
      terminal.write('\x1b[2m${notices.tmuxSessionGone}\x1b[0m\r\n');
    }

    final drained = Completer<void>();
    _stdoutSubscription = shell.stdout.listen(
      _coalescer.add,
      onError: (Object _) {},
      onDone: () {
        if (!drained.isCompleted) drained.complete();
      },
    );
    // stderr goes to the same terminal, interleaved, exactly as a real tty
    // does. Splitting them would put a command's errors somewhere the user
    // is not looking.
    _stderrSubscription = shell.stderr.listen(
      _coalescer.add,
      onError: (Object _) {},
    );

    unawaited(
      shell.done.then(
        (_) => _onShellDone(shell, drained.future),
        onError: (Object _) => _onShellDone(shell, drained.future),
      ),
    );

    _status = TerminalSessionStatus.running;
    notifyListeners();

    // A reattached tmux session already ran it, and whatever it started is
    // still there.
    final command = startupCommand?.trim();
    if (command != null &&
        command.isNotEmpty &&
        shell.origin != ShellOrigin.tmuxReattached) {
      shell.write(Uint8List.fromList(utf8.encode('$command\n')));
    }
  }

  /// Replaces this tab's buffer with the scrollback tmux kept for it.
  ///
  /// tmux's history is the complete record: it has the lines a burst of
  /// output scrolled past without tmux ever drawing them here, and whatever
  /// ran while the connection was down. What this buffer holds beyond it is
  /// the part tmux drew, so replacing is lossless and never duplicates —
  /// appending would print everything twice.
  void _replaceWithHistory(String history, {required bool reconnecting}) {
    final lines = history.replaceAll('\r\n', '\n').split('\n');
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    if (lines.isEmpty && !reconnecting) return;

    terminal.write('\x1b[0m\x1b[H\x1b[2J');
    terminal.buffer.clearScrollback();
    if (lines.isNotEmpty) {
      terminal.write('${lines.join('\r\n')}\x1b[0m\r\n');
      _receivedOutput = true;
    }
    if (reconnecting) _writeNotice('${notices.reconnected}\r\n');
    // Up into the scrollback, clear of the redraw attaching is about to do.
    _writeNotice('\r\n' * terminal.viewHeight);
  }

  /// Stops listening to the previous shell. Not awaited: nothing is
  /// delivered after `cancel` returns, and the future it hands back can wait
  /// on a stream that is already finished.
  void _detachShell() {
    unawaited(_stdoutSubscription?.cancel());
    unawaited(_stderrSubscription?.cancel());
    _stdoutSubscription = null;
    _stderrSubscription = null;
  }

  /// The shell's channel closed. Decides whether that is the end.
  Future<void> _onShellDone(RemoteShell shell, Future<void> drained) async {
    // The channel can close with output still in flight — tmux clearing the
    // screen and printing "[exited]", a shell's last words. It lands first,
    // or it paints over the notice written below.
    await drained.timeout(const Duration(seconds: 1), onTimeout: () {});
    while (!_disposed && _coalescer.pendingBytes > 0) {
      _coalescer.flush();
    }
    if (_disposed || !identical(shell, _shell)) return;
    if (_status == TerminalSessionStatus.failed) return;
    if (_status != TerminalSessionStatus.running) return;

    final reason = _ending
        ? DisconnectReason.userInitiated
        : shell.exited
        ? DisconnectReason.remoteExited
        : DisconnectReason.network;

    _status = TerminalSessionStatus.closed;
    switch (reason) {
      case DisconnectReason.userInitiated:
        _writeNotice('\r\n${notices.sessionClosed}\r\n');
      case DisconnectReason.remoteExited:
        _writeNotice('\r\n${notices.sessionEnded}\r\n');
      default:
        _writeNotice('\r\n${notices.connectionLost}\r\n');
    }
    reconnect.dropped(reason);
    notifyListeners();
  }

  /// Something suggests the link may have changed — the app came back to the
  /// foreground, or the network came back.
  ///
  /// A session waiting to reconnect tries now. A session that thinks it is
  /// connected is asked to prove it, because a phone's socket dies silently
  /// while the app is suspended and nothing notices until the next write.
  Future<void> nudge() async {
    if (_disposed) return;
    if (reconnect.phase == ReconnectPhase.waiting) {
      reconnect.retryNow();
      return;
    }
    if (_status == TerminalSessionStatus.running) {
      // A failed probe tears the connection down; the shell closing then
      // starts the reconnect through the ordinary path.
      await _probe();
    }
  }

  /// Stops an automatic reconnect. The tab stays, with its manual Reconnect.
  void stopReconnecting() => reconnect.stop();

  /// Sends raw bytes, for the key bar's Ctrl and escape sequences.
  void send(String data) {
    final shell = _shell;
    if (shell == null) return;
    shell.write(Uint8List.fromList(utf8.encode(data)));
  }

  /// Ends the session but leaves the tab, so the scrollback can still be read.
  ///
  /// The user's decision: nothing reconnects, and a tmux session kept for
  /// this tab is ended on the server too.
  Future<void> disconnect() async {
    _ending = true;
    reconnect.stop();
    await _launcher.discard();
    _shell?.close();
    await connection.reset();
    _handleClosed();
  }

  /// Closes the tab for good: ends the server-side tmux session, if any, then
  /// releases everything. For a tab the user closed — an app that is merely
  /// exiting calls [dispose], which leaves the server-side session to be
  /// reattached later.
  void end() {
    _ending = true;
    reconnect.stop();
    final discard = _launcher.discard();
    dispose(closeConnection: false);
    unawaited(discard.whenComplete(connection.close).catchError((Object _) {}));
  }

  void _handleClosed() {
    if (_disposed) return;
    if (_status == TerminalSessionStatus.failed) return;
    if (_status == TerminalSessionStatus.closed) {
      notifyListeners();
      return;
    }
    _status = TerminalSessionStatus.closed;
    _writeNotice('\r\n${notices.sessionClosed}\r\n');
    notifyListeners();
  }

  void _failWith(Object e) {
    if (e is SshConnectionException) {
      final cause = e.cause;
      if (cause is HostKeyRejected) _hostKeyRejection = cause;
      _fail(e.message);
    } else {
      _fail('Could not open a shell: ${e.runtimeType}');
    }
  }

  /// The automatic reconnect hit something retrying cannot fix.
  void _gaveUp(Object error) {
    if (_disposed) return;
    _failWith(error);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
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
  void dispose({bool closeConnection = true}) {
    if (_disposed) return;
    _disposed = true;
    reconnect.dispose();
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _stateSubscription?.cancel();
    _coalescer.dispose();
    modifiers.dispose();
    _shell?.close();
    if (closeConnection) unawaited(connection.close());
    super.dispose();
  }
}
