@Tags(['live'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/host_key_verifier.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/core/terminal/tmux_commands.dart';
import 'package:sshetu/features/sessions/server_sessions.dart';

/// Session names, reopening by name, the server's session list, ending a
/// session, and per-host environment variables — against a **real server**
/// with tmux.
///
/// Configured like `tmux_live_test.dart`, and skipped without it:
///
///     SSHETU_LIVE_SSH   user@host:port of a server with tmux
///     SSHETU_LIVE_KEY   path to an unencrypted private key it accepts
///
///     flutter test --tags live test/core/terminal/tmux_sessions_live_test.dart
void main() {
  final env = Platform.environment;
  final address = env['SSHETU_LIVE_SSH'];
  final keyPath = env['SSHETU_LIVE_KEY'];
  final skip = address == null || keyPath == null
      ? 'SSHETU_LIVE_SSH and SSHETU_LIVE_KEY are not set'
      : null;

  late SshTarget target;
  late SecretVault vault;
  final knownHosts = InMemoryKnownHostsStore();
  // This run's "device", so nothing here collides with a real install's
  // sessions — or with the last run's.
  final device = randomTmuxToken(kTmuxDeviceIdLength);

  setUpAll(() async {
    if (skip != null) return;
    final match = RegExp(r'^([^@]+)@([^:]+):(\d+)$').firstMatch(address!)!;
    target = SshTarget(
      hostname: match[2]!,
      port: int.parse(match[3]!),
      username: match[1]!,
      identityId: 'live-key',
      credentialId: 'live-host',
    );
    vault = InMemorySecretVault();
    await vault.write(
      const SecretRef.identityPrivateKey('live-key'),
      await File(keyPath!).readAsString(),
    );
  });

  SshConnection connect() => SshConnection(
    target: target,
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

  /// A separate connection for asking the server things, never the tab's.
  Future<ServerSessions> server() async {
    final connection = connect();
    addTearDown(connection.close);
    await connection.client();
    return ServerSessions(connection);
  }

  TerminalSession tab({
    String? name,
    bool keep = true,
    bool resuming = false,
    bool owns = true,
    Map<String, String> vars = const {},
    String? startupCommand,
  }) {
    final session = TerminalSession(
      id: 'live-${DateTime.now().microsecondsSinceEpoch}',
      title: 'live',
      hostId: 'live-host',
      connection: connect(),
      keepOnServer: keep,
      tmuxName: name ?? newTmuxSessionName(device),
      resuming: resuming,
      ownsTmuxSession: owns,
      env: vars,
      startupCommand: startupCommand,
    );
    addTearDown(() => session.dispose());
    return session;
  }

  String text(TerminalSession session) => session.terminal.buffer.getText();

  Future<String> pidOf(TerminalSession session, String tag) async {
    session.send('echo "$tag=\$\$"\r');
    final pattern = RegExp('$tag=(\\d+)');
    await _waitFor(
      () => pattern.hasMatch(text(session)),
      describe: () => text(session),
    );
    return pattern.firstMatch(text(session))![1]!;
  }

  // Everything this run started, ended at the close whatever happened.
  tearDownAll(() async {
    if (skip != null) return;
    final connection = connect();
    try {
      final sessions = ServerSessions(connection);
      for (final session in (await sessions.list()).sessions) {
        if (session.name.startsWith('sshetu-$device-')) {
          await sessions.end(session.name);
        }
      }
    } finally {
      await connection.close();
    }
  });

  test(
    'two tabs get distinct names on this device, and the list shows both',
    () async {
      final a = tab();
      final b = tab();
      expect(a.tmuxName, isNot(b.tmuxName));
      expect(a.tmuxName, startsWith('sshetu-$device-'));
      await a.start();
      await b.start();
      expect(a.shellOrigin, ShellOrigin.tmuxCreated, reason: a.error);
      expect(b.shellOrigin, ShellOrigin.tmuxCreated, reason: b.error);
      await pidOf(a, 'a');
      await pidOf(b, 'b');

      final listing = await (await server()).list();
      expect(listing.tmuxAvailable, isTrue);
      final mine = {
        for (final s in listing.sessions)
          if (s.name.startsWith('sshetu-$device-')) s.name: s,
      };
      expect(mine.keys, containsAll([a.tmuxName, b.tmuxName]));
      final info = mine[a.tmuxName]!;
      final origin = parseTmuxSessionName(info.name);
      expect(origin, isA<TmuxFromDevice>());
      expect((origin! as TmuxFromDevice).deviceId, device);
      expect(info.isAttached, isTrue, reason: 'the tab is attached');
      expect(info.lastActivity, isNotNull);
      expect(
        DateTime.now().toUtc().difference(info.created).inMinutes,
        lessThan(5),
      );
      // ignore: avoid_print
      print(
        'listed: ${info.name} attached=${info.attachedClients} '
        'command=${info.command} created=${info.created} '
        'activity=${info.lastActivity}',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'reopened by name after the app exits: the same shell, startup not rerun',
    () async {
      final log = '/tmp/sshetu-live-$device-${DateTime.now().millisecond}.log';
      final first = tab(startupCommand: 'echo ran >> $log');
      await first.start();
      expect(first.shellOrigin, ShellOrigin.tmuxCreated, reason: first.error);
      first.send('export MARK=kept\r');
      final before = await pidOf(first, 'pid');
      final name = first.tmuxName;

      // The app exiting: disposed, not ended, so the session stays.
      first.dispose();
      await Future<void>.delayed(const Duration(seconds: 1));

      final again = tab(
        name: name,
        resuming: true,
        startupCommand: 'echo ran >> $log',
      );
      await again.start();
      expect(
        again.shellOrigin,
        ShellOrigin.tmuxReattached,
        reason: again.error,
      );
      expect(again.resumeFailed, isFalse);
      expect(await pidOf(again, 'again'), before);
      again.send('echo "mark=\$MARK"\r');
      await _waitFor(
        () => text(again).contains('mark=kept'),
        describe: () => text(again),
      );
      // The scrollback came back from tmux's history.
      expect(text(again), contains('pid=$before'));

      final ran = (await (await server()).connection.client().then(
        (c) => runRemoteCommand(c, 'cat $log; rm -f $log'),
      )).trim();
      expect(ran.split('\n'), ['ran'], reason: 'startup ran once');
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'reopened after the session was ended: a new shell that says so',
    () async {
      final first = tab();
      await first.start();
      final before = await pidOf(first, 'pid');
      final name = first.tmuxName;
      first.dispose();

      final sessions = await server();
      await sessions.end(name);
      expect(
        (await sessions.list()).sessions.map((s) => s.name),
        isNot(contains(name)),
      );

      final again = tab(name: name, resuming: true);
      await again.start();
      expect(again.shellOrigin, ShellOrigin.tmuxCreated, reason: again.error);
      expect(again.resumeFailed, isTrue);
      expect(text(again), contains('has ended'));
      expect(await pidOf(again, 'again'), isNot(before));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a borrowed session outlives its tab; an owned one does not',
    () async {
      final owner = tab();
      await owner.start();
      await pidOf(owner, 'o');
      final name = owner.tmuxName;
      owner.dispose();

      // Attached from the list: borrowed.
      final borrowed = tab(name: name, resuming: true, owns: false);
      await borrowed.start();
      expect(borrowed.shellOrigin, ShellOrigin.tmuxReattached);
      borrowed.end();
      await Future<void>.delayed(const Duration(seconds: 2));
      final sessions = await server();
      expect(
        (await sessions.list()).sessions.map((s) => s.name),
        contains(name),
        reason: 'closing a borrowed tab leaves the session running',
      );

      final owned = tab(name: name, resuming: true);
      await owned.start();
      expect(owned.shellOrigin, ShellOrigin.tmuxReattached);
      owned.end();
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
        (await sessions.list()).sessions.map((s) => s.name),
        isNot(contains(name)),
        reason: 'closing an owned tab ends it',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  const tricky = {
    'SSN_SPACES': 'two  words here',
    'SSN_QUOTES': 'it\'s "quoted"',
    'SSN_DOLLAR': r'$HOME $(id) `id` \n;&|',
  };

  Future<void> expectVars(TerminalSession session) async {
    session.send(
      'printf "<%s|%s|%s>\\n" "\$SSN_SPACES" "\$SSN_QUOTES" "\$SSN_DOLLAR"\r',
    );
    final expected =
        '<${tricky['SSN_SPACES']}|${tricky['SSN_QUOTES']}|'
        '${tricky['SSN_DOLLAR']}>';
    await _waitFor(
      () => _lines(text(session)).contains(expected),
      describe: () => text(session),
    );
    // Set, not typed: nothing echoed an export into the terminal.
    expect(text(session), isNot(contains('export SSN_')));
  }

  test(
    'environment variables reach a tmux shell exactly',
    () async {
      final session = tab(vars: tricky);
      await session.start();
      expect(
        session.shellOrigin,
        ShellOrigin.tmuxCreated,
        reason: session.error,
      );
      await expectVars(session);
      // And a login shell it still is.
      session.send(
        r'case "$-" in *i*) echo "interactive=yes";; esac'
        '\r',
      );
      await _waitFor(() => text(session).contains('interactive=yes'));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'environment variables reach a plain shell exactly',
    () async {
      final session = tab(keep: false, vars: tricky);
      await session.start();
      expect(session.shellOrigin, ShellOrigin.plain, reason: session.error);
      await expectVars(session);
      // The user's own shell, and a login shell, as the `shell` request
      // would have given — asked the way bash and zsh each answer it.
      session.send(
        r'echo "shell=<$0>"'
        '\r',
      );
      final shell = RegExp(r'shell=<([^>$]+)>');
      await _waitFor(
        () => shell.hasMatch(text(session)),
        describe: () => text(session),
      );
      final name = shell.firstMatch(text(session))![1]!;
      // ignore: avoid_print
      print('plain shell with variables: $name');
      if (name.endsWith('zsh') || name.endsWith('bash')) {
        session.send(
          name.endsWith('zsh')
              ? r'[[ -o login ]] && echo "log""in=yes"'
                    '\r'
              : r'shopt -q login_shell && echo "log""in=yes"'
                    '\r',
        );
        await _waitFor(
          () => _lines(text(session)).contains('login=yes'),
          describe: () => text(session),
        );
      }
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
