@Tags(['live'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/host_key_verifier.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';
import 'package:sshetu/core/ssh/reconnect_loop.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/core/terminal/tmux_commands.dart';

/// Sessions kept in tmux, against a **real server** with tmux installed.
///
/// Everything the unit tests fake is real here: the probe over an exec
/// channel, attach-or-create, a connection killed on the server side, the
/// automatic reconnect reattaching to the same shell, the startup command
/// not running twice, and the session being ended when the tab closes.
///
/// Configured entirely from the environment and skipped without it:
///
///     SSHETU_LIVE_SSH     user@host:port of a server with tmux
///     SSHETU_LIVE_KEY     path to an unencrypted private key it accepts
///     SSHETU_LIVE_KILL    a command that kills the server side of every
///                         connection (a hard drop: the socket closes)
///     SSHETU_LIVE_FREEZE  a command that stops the server side answering
///                         without closing anything (SIGSTOP) — optional
///     SSHETU_LIVE_THAW    undoes FREEZE — optional
///     SSHETU_LIVE_NO_TMUX_PORT  a port on the same host where tmux cannot be
///                         found (e.g. `SetEnv PATH=/nonexistent`) — optional
///
/// The commands run in the platform shell. Run deliberately:
///
///     flutter test --tags live test/core/terminal/tmux_live_test.dart
void main() {
  final env = Platform.environment;
  final address = env['SSHETU_LIVE_SSH'];
  final keyPath = env['SSHETU_LIVE_KEY'];
  final kill = env['SSHETU_LIVE_KILL'];
  final freeze = env['SSHETU_LIVE_FREEZE'];
  final thaw = env['SSHETU_LIVE_THAW'];
  final noTmuxPort = int.tryParse(env['SSHETU_LIVE_NO_TMUX_PORT'] ?? '');
  final skip = address == null || keyPath == null || kill == null
      ? 'SSHETU_LIVE_SSH, SSHETU_LIVE_KEY and SSHETU_LIVE_KILL are not set'
      : null;

  late SshTarget target;
  late SecretVault vault;
  final knownHosts = InMemoryKnownHostsStore();

  setUpAll(() async {
    if (skip != null) return;
    final match = RegExp(r'^([^@]+)@([^:]+):(\d+)$').firstMatch(address!)!;
    target = SshTarget(
      hostname: match[2]!,
      port: int.parse(match[3]!),
      username: match[1]!,
      identityId: 'live-key',
      credentialId: 'live-host',
      // Short, so the watchdog is exercised within the test's patience.
      keepaliveInterval: const Duration(seconds: 5),
    );
    vault = InMemorySecretVault();
    await vault.write(
      const SecretRef.identityPrivateKey('live-key'),
      await File(keyPath!).readAsString(),
    );
  });

  SshConnection connect({int? port}) => SshConnection(
    target: port == null ? target : target.copyWith(port: port),
    verifierFactory: (hostname, port) => SshHostKeyVerifier(
      knownHosts: knownHosts,
      hostname: hostname,
      port: port,
      onUnknownHostKey: (_) => true,
    ),
    credentials: VaultCredentialSource(
      vault: vault,
      catalog: () async => const [],
    ),
  );

  /// Runs [command] on its own, separate connection and returns stdout and
  /// the exit status — never through the session under test.
  Future<({String out, int? code})> exec(String command) async {
    final connection = connect();
    try {
      final client = await connection.client();
      final session = await client.execute(command);
      await session.stdin.close();
      final out = StringBuffer();
      await Future.wait([
        session.stdout
            .listen((d) => out.write(utf8.decode(d)))
            .asFuture<void>(),
        session.stderr.listen((_) {}).asFuture<void>(),
      ]);
      await session.done;
      return (out: out.toString(), code: session.exitCode);
    } finally {
      await connection.close();
    }
  }

  Future<void> run(String command) async {
    final result = await Process.run(command, const [], runInShell: true);
    if (result.exitCode != 0) {
      throw StateError('"$command" failed: ${result.stderr}');
    }
  }

  TerminalSession tab(String id, {String? startupCommand, int? port}) {
    final session = TerminalSession(
      id: id,
      title: 'live',
      hostId: 'live-host',
      connection: connect(port: port),
      keepOnServer: true,
      startupCommand: startupCommand,
    );
    addTearDown(session.end);
    return session;
  }

  String text(TerminalSession session) => session.terminal.buffer.getText();

  test(
    'attach-or-create, reattach after a hard drop, startup once, '
    'killed on close',
    () async {
      final id = 'live${DateTime.now().millisecondsSinceEpoch}';
      final startupLog = '/tmp/sshetu-live-$id.log';
      final session = tab(id, startupCommand: 'echo ran >> $startupLog');
      final name = session.tmuxName;

      await session.start();
      expect(
        session.status,
        TerminalSessionStatus.running,
        reason: session.error,
      );
      expect(session.shellOrigin, ShellOrigin.tmuxCreated);

      // On SSHetu's own tmux server, not the user's default one.
      expect((await exec(tmuxProbeCommand(name))).out, contains('existing'));
      final defaultServer = await exec('tmux ls 2>&1; true');
      expect(defaultServer.out, isNot(contains(name)));

      // Slow output: the alternate-screen trick puts each line in the app's
      // own scrollback as it scrolls.
      session.send(
        'for i in \$(seq 1 40); do echo "slow-\$i"; sleep 0.02; done\r',
      );
      await _waitFor(
        () => _lines(text(session)).contains('slow-40'),
        describe: () => text(session),
      );
      // endsWith: the typed command fills the row exactly, and the buffer
      // joins the next line onto it as a wrap.
      expect(
        _lines(text(session)).any((l) => l.endsWith('slow-1')),
        isTrue,
        reason: 'a line scrolled off the top one at a time is in scrollback',
      );

      // A burst: tmux draws only its last screen, so the app's own buffer
      // misses the start of it — measured here, not assumed.
      session.send('seq 1 300; echo "pid=\$\$"\r');
      await _waitFor(
        () => RegExp(r'pid=\d+').hasMatch(text(session)),
        describe: () => text(session),
      );
      final before = RegExp(r'pid=(\d+)').firstMatch(text(session))![1];
      final burstSeenLive = text(session)
          .split('\n')
          .map((l) => l.trim())
          .contains('1');
      // ignore: avoid_print
      print('burst line 1 in the live buffer before reattach: $burstSeenLive');
      expect(
        session.terminal.buffer.lines.length,
        greaterThan(session.terminal.viewHeight),
      );

      // A hard drop: the server side of the connection is killed.
      await run(kill!);
      await _waitFor(
        () =>
            session.reconnect.phase != ReconnectPhase.idle ||
            session.status != TerminalSessionStatus.running,
        describe: () => '${session.status} ${session.reconnect.phase}',
      );
      expect(text(session), contains('[connection lost — reconnecting]'));

      await _waitFor(
        () =>
            session.status == TerminalSessionStatus.running &&
            session.reconnect.phase == ReconnectPhase.idle,
        timeout: const Duration(seconds: 30),
        describe: () =>
            '${session.status} ${session.reconnect.phase} '
            '${session.error}',
      );
      expect(session.shellOrigin, ShellOrigin.tmuxReattached);

      // The same shell: same PID, and what was set in it is still set.
      session.send('echo "again=\$\$"\r');
      await _waitFor(
        () => RegExp(r'again=\d+').hasMatch(text(session)),
        describe: () => text(session),
      );
      final after = RegExp(r'again=(\d+)').firstMatch(text(session))![1];
      expect(after, before, reason: 'reattached to the same shell');
      // Scrollback from before the drop is still in the buffer.
      expect(text(session), contains('pid=$before'));
      // And the burst tmux never drew here came back from its history: all of
      // it, once.
      final restored = _lines(text(session));
      expect(restored, contains('1'));
      expect(restored.any((l) => l.endsWith('slow-1')), isTrue);
      expect(restored.where((l) => l == '300'), hasLength(1));

      // The startup command ran exactly once, on creation.
      final log = await exec('cat $startupLog; rm -f $startupLog');
      expect(log.out.trim().split('\n'), ['ran']);

      // Closing the tab ends the tmux session on the server.
      session.end();
      // The kill runs over the still-open connection, fire-and-forget.
      await Future<void>.delayed(const Duration(seconds: 2));
      final gone = await exec(tmuxProbeCommand(name));
      expect(gone.out, contains('SSHETU:tmux-new'), reason: 'session killed');
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a server that stops answering is caught by the probe, then '
    'reattached',
    () async {
      final id = 'livefreeze${DateTime.now().millisecondsSinceEpoch}';
      final session = tab(id);
      await session.start();
      expect(
        session.status,
        TerminalSessionStatus.running,
        reason: session.error,
      );
      session.send('echo "pid=\$\$"\r');
      await _waitFor(() => RegExp(r'pid=\d+').hasMatch(text(session)));
      final before = RegExp(r'pid=(\d+)').firstMatch(text(session))![1];

      await run(freeze!);
      try {
        // What the app does on resume: a live-looking connection is asked to
        // prove it. The socket is open, the server is not answering.
        final stopwatch = Stopwatch()..start();
        final alive = await session.connection.probe(
          timeout: const Duration(seconds: 3),
        );
        expect(alive, isFalse);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 6)));

        await _waitFor(
          () =>
              session.status == TerminalSessionStatus.running &&
              session.reconnect.phase == ReconnectPhase.idle &&
              session.shellOrigin == ShellOrigin.tmuxReattached,
          timeout: const Duration(seconds: 30),
          describe: () =>
              '${session.status} ${session.reconnect.phase} '
              '${session.error}',
        );
      } finally {
        await run(thaw!);
      }
      session.send('echo "again=\$\$"\r');
      await _waitFor(() => RegExp(r'again=\d+').hasMatch(text(session)));
      expect(RegExp(r'again=(\d+)').firstMatch(text(session))![1], before);
    },
    skip:
        skip ??
        (freeze == null || thaw == null
            ? 'SSHETU_LIVE_FREEZE / SSHETU_LIVE_THAW are not set'
            : null),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'without tmux: a plain shell, one notice, and a fresh shell after a drop',
    () async {
      final id = 'livenotmux${DateTime.now().millisecondsSinceEpoch}';
      final session = tab(id, port: noTmuxPort);
      await session.start();
      expect(
        session.status,
        TerminalSessionStatus.running,
        reason: session.error,
      );
      expect(session.shellOrigin, ShellOrigin.plainWithoutTmux);
      expect(text(session), contains('tmux is not installed'));
      session.send('echo "pid=\$\$"\r');
      await _waitFor(() => RegExp(r'pid=\d+').hasMatch(text(session)));
      final before = RegExp(r'pid=(\d+)').firstMatch(text(session))![1];

      await run(kill!);
      await _waitFor(
        () =>
            session.status == TerminalSessionStatus.running &&
            session.reconnect.phase == ReconnectPhase.idle &&
            text(session).contains('[reconnected]'),
        timeout: const Duration(seconds: 30),
        describe: () => '${session.status} ${session.reconnect.phase}',
      );
      expect(session.shellOrigin, ShellOrigin.plainWithoutTmux);
      session.send('echo "again=\$\$"\r');
      await _waitFor(() => RegExp(r'again=\d+').hasMatch(text(session)));
      final after = RegExp(r'again=(\d+)').firstMatch(text(session))![1];
      expect(after, isNot(before), reason: 'a plain shell does not survive');
      expect('tmux is not installed'.allMatches(text(session)), hasLength(1));
    },
    skip:
        skip ??
        (noTmuxPort == null ? 'SSHETU_LIVE_NO_TMUX_PORT is not set' : null),
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'typing exit ends the tab without reconnecting',
    () async {
      final id = 'liveexit${DateTime.now().millisecondsSinceEpoch}';
      final session = tab(id);
      await session.start();
      expect(
        session.status,
        TerminalSessionStatus.running,
        reason: session.error,
      );
      session.send('echo ready\r');
      await _waitFor(() => text(session).contains('ready'));

      session.send('exit\r');
      await _waitFor(
        () => session.status == TerminalSessionStatus.closed,
        describe: () => '${session.status}',
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(session.reconnect.phase, ReconnectPhase.idle);
      expect(session.status, TerminalSessionStatus.closed);
      expect(text(session), contains('[session ended]'));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String Function()? describe,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException(
    'condition not met within $timeout'
    '${describe == null ? '' : '; ${describe()}'}',
  );
}

List<String> _lines(String text) =>
    text.split('\n').map((line) => line.trim()).toList();
