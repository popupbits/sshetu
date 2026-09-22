import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../ssh/ssh_connection.dart';
import 'tmux_commands.dart';

/// How a shell came to be, which decides what happens after it opens.
enum ShellOrigin {
  /// An ordinary shell. Nothing survives the connection.
  plain,

  /// A plain shell because tmux was asked for and the server has none.
  plainWithoutTmux,

  /// A new tmux session was created for this tab.
  tmuxCreated,

  /// This tab's tmux session was still running, and was reattached.
  tmuxReattached,
}

/// One open interactive shell, as a terminal session needs it.
///
/// The seam between `TerminalSession` and the transport: bytes in and out, a
/// resize, and an end. Kept this small so a test can stand in for a server,
/// and so a transport other than SSH can satisfy it later.
abstract interface class RemoteShell {
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;

  /// Completes when the channel closes, for whatever reason.
  Future<void> get done;

  /// Whether the remote program reported that it ended — an exit status or
  /// a signal. False when the channel simply went away with the connection.
  ///
  /// This is the line between "the user typed `exit`" and "the network
  /// dropped", and the only reliable one: both look identical from [done].
  bool get exited;

  ShellOrigin get origin;

  /// For a reattached tmux session: its scrollback, captured just before
  /// attaching, as terminal text. Null when there is none to offer.
  String? get history;

  void write(Uint8List data);
  void resize(int width, int height, int pixelWidth, int pixelHeight);
  void close();
}

/// Opens the shell behind one tab — the same one again, when it can.
abstract interface class ShellLauncher {
  Future<RemoteShell> open({required int columns, required int rows});

  /// Ends what [open] left running on the server, if anything outlives the
  /// connection. Called when the user closes the tab or disconnects on
  /// purpose — never when the link merely drops.
  Future<void> discard();
}

/// The SSH [ShellLauncher]: a plain shell, or one kept alive in tmux.
class SshShellLauncher implements ShellLauncher {
  SshShellLauncher({
    required this.connection,
    required this.keepOnServer,
    required this.tmuxName,
    this.env = const {},
    this.ownsSession = true,
    this.probeTimeout = const Duration(seconds: 10),
    this.discardTimeout = const Duration(seconds: 5),
  });

  final SshConnection connection;

  /// Whether to try tmux at all. Decided once per tab: turning the setting
  /// off does not orphan a tab that is already running in tmux, because its
  /// reconnects still reattach.
  final bool keepOnServer;

  /// This tab's tmux session name. See [tmuxSessionName].
  final String tmuxName;

  /// The host's environment variables, set in every *new* shell: a new tmux
  /// session, or a plain shell. See [plainShellCommand].
  final Map<String, String> env;

  /// Whether ending the tab ends the tmux session too.
  ///
  /// False for a tab that attached a session it did not start — picked from
  /// "Sessions on this server", perhaps left running by another device.
  /// Closing that tab lets go of it; ending it is a separate, confirmed act.
  final bool ownsSession;

  final Duration probeTimeout;
  final Duration discardTimeout;

  /// Set once a tmux session has actually been attached, so [discard] knows
  /// there is something on the server to end.
  bool _usedTmux = false;

  @override
  Future<RemoteShell> open({required int columns, required int rows}) async {
    final client = await connection.client();
    final pty = SSHPtyConfig(
      // 256 colours, because everything anyone will run in here assumes
      // them — a prompt, `ls --color`, vim, htop.
      type: 'xterm-256color',
      width: columns,
      height: rows,
    );

    if (!keepOnServer) {
      return SshRemoteShell(await _plainShell(client, pty), ShellOrigin.plain);
    }

    final probe = await _probe(client);
    if (probe == TmuxProbe.unavailable) {
      return SshRemoteShell(
        await _plainShell(client, pty),
        ShellOrigin.plainWithoutTmux,
      );
    }

    final reattaching = probe == TmuxProbe.willReattach;
    // Read before attaching, so it is the history as it stood, not racing
    // the redraw attaching triggers.
    final history = reattaching ? await _history(client) : null;
    final session = await client.execute(
      tmuxAttachCommand(tmuxName, columns: columns, rows: rows, env: env),
      pty: pty,
    );
    _usedTmux = true;
    return SshRemoteShell(
      session,
      reattaching ? ShellOrigin.tmuxReattached : ShellOrigin.tmuxCreated,
      history: history,
    );
  }

  /// An ordinary shell. A `shell` request when there are no variables, not
  /// `exec sh`: a switch or a router has no shell to exec, and must work
  /// exactly as it did before tmux existed. With variables, the login shell
  /// is started with them already set — see [plainShellCommand].
  Future<SSHSession> _plainShell(SSHClient client, SSHPtyConfig pty) =>
      env.isEmpty
      ? client.shell(pty: pty)
      : client.execute(plainShellCommand(env), pty: pty);

  Future<TmuxProbe> _probe(SSHClient client) async {
    try {
      final output = await _run(
        client,
        tmuxProbeCommand(tmuxName),
      ).timeout(probeTimeout);
      return parseTmuxProbe(output);
    } on Object {
      // No exec channel, no sh, a probe that hung: all mean "no tmux here",
      // and the tab gets the plain shell it would have had anyway. A dead
      // link will fail that shell request just as clearly.
      return TmuxProbe.unavailable;
    }
  }

  /// The session's scrollback, or null if it could not be read — in which
  /// case the tab keeps what it already has.
  Future<String?> _history(SSHClient client) async {
    try {
      return await _run(
        client,
        tmuxHistoryCommand(tmuxName),
      ).timeout(probeTimeout);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> discard() async {
    if (!_usedTmux) return;
    _usedTmux = false;
    if (!ownsSession) return;
    // Never dials: a tab closed while offline leaves its session behind
    // rather than raising a host key or password prompt on the way out.
    if (!connection.isConnected) return;
    try {
      final client = await connection.client();
      await _run(client, tmuxKillCommand(tmuxName)).timeout(discardTimeout);
    } on Object {
      // Best effort by design; see above.
    }
  }

  static Future<String> _run(SSHClient client, String command) =>
      runRemoteCommand(client, command);
}

/// Runs [command] over an exec channel (no PTY) and returns its stdout.
///
/// For the short, scripted questions the terminal layer asks a server — is
/// tmux there, what is its history, which sessions are running — never for
/// anything interactive.
Future<String> runRemoteCommand(SSHClient client, String command) async {
  final session = await client.execute(command);
  await session.stdin.close();
  // Bytes first, decoded once: a history full of box drawing and emoji
  // splits characters across chunks, and decoding chunk by chunk would turn
  // each split into a replacement character.
  final out = BytesBuilder(copy: false);
  await Future.wait([
    session.stdout.listen(out.add).asFuture<void>(),
    session.stderr.listen((_) {}).asFuture<void>(),
  ]);
  await session.done;
  return utf8.decode(out.takeBytes(), allowMalformed: true);
}

/// [RemoteShell] over a dartssh2 session.
class SshRemoteShell implements RemoteShell {
  SshRemoteShell(this._session, this.origin, {this.history});

  final SSHSession _session;

  @override
  final ShellOrigin origin;

  @override
  final String? history;

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  Future<void> get done => _session.done;

  @override
  bool get exited => _session.exitCode != null || _session.exitSignal != null;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resize(int width, int height, int pixelWidth, int pixelHeight) =>
      _session.resizeTerminal(width, height, pixelWidth, pixelHeight);

  @override
  void close() => _session.close();
}
