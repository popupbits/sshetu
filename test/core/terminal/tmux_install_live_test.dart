@Tags(['live'])
library;

import 'dart:convert';
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
import 'package:sshetu/core/terminal/tmux_install.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/sessions/tmux_install_assistant.dart';

/// Offering to install tmux, against a **real server** whose package manager
/// and sudo are simulated.
///
/// The server must be set up so that tmux is missing from the account's
/// PATH, a fake `apt-get` "installs" it (by linking the real binary into a
/// directory on that PATH) and a fake `sudo` either works without a password
/// or asks for one on the terminal. Nothing real is ever installed. A setup
/// script on the server switches between the cases:
///
///     SSHETU_LIVE_INSTALL_SSH       user@host:port of that server
///     SSHETU_LIVE_KEY               an unencrypted private key it accepts
///     SSHETU_LIVE_INSTALL_SETUP     a script on the server, run as
///                                   `<script> nopass|password|root`: removes
///                                   tmux from the PATH and picks how the
///                                   fake sudo behaves
///     SSHETU_LIVE_INSTALL_PASSWORD  the password the fake sudo accepts
///
/// Skipped without them. Run deliberately:
///
///     flutter test --tags live test/core/terminal/tmux_install_live_test.dart
void main() {
  final env = Platform.environment;
  final address = env['SSHETU_LIVE_INSTALL_SSH'];
  final keyPath = env['SSHETU_LIVE_KEY'];
  final setup = env['SSHETU_LIVE_INSTALL_SETUP'];
  final fakePassword = env['SSHETU_LIVE_INSTALL_PASSWORD'];
  final skip =
      address == null ||
          keyPath == null ||
          setup == null ||
          fakePassword == null
      ? 'SSHETU_LIVE_INSTALL_SSH, SSHETU_LIVE_KEY, SSHETU_LIVE_INSTALL_SETUP '
            'and SSHETU_LIVE_INSTALL_PASSWORD are not set'
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

  /// Runs [command] on its own connection — never the session under test.
  Future<ExecResult> exec(String command) async {
    final connection = connect();
    try {
      await connection.client();
      return await ConnectionExec(connection).run(command);
    } finally {
      await connection.close();
    }
  }

  Future<void> prepare(String mode) async {
    final result = await exec('${shellQuote(setup!)} $mode');
    expect(result.exitCode, 0, reason: 'setup $mode: ${result.stdout}');
    final probe = await exec(posixShell('command -v tmux || echo none'));
    expect(probe.stdout.trim(), 'none', reason: 'tmux must start missing');
  }

  String text(TerminalSession session) => session.terminal.buffer.getText();

  Future<void> until(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String? what,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('timed out waiting for ${what ?? 'a condition'}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// A tab that wants tmux, and the assistant a pane would give it.
  Future<(TerminalSession, TmuxInstallAssistant)> openTab(String id) async {
    final connection = connect();
    final session = TerminalSession(
      id: id,
      title: 'live',
      hostId: 'live-host',
      connection: connection,
      keepOnServer: true,
      tmuxName: newTmuxSessionName('lvtest'),
    );
    // Ended, not disposed: the tmux session this test created is killed by
    // its own name when the tab closes.
    addTearDown(() async {
      session.end();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await session.start();
    expect(session.status, TerminalSessionStatus.running);
    expect(session.shellOrigin, ShellOrigin.plainWithoutTmux);

    final assistant = TmuxInstallAssistant(
      exec: ConnectionExec(connection),
      installExec: ConnectionExec(connection, timeout: kTmuxInstallTimeout),
      typeIntoTerminal: session.send,
      setNever: () async {},
      snooze: () {},
      restartInTmux: session.restartInTmux,
    );
    addTearDown(assistant.dispose);
    return (session, assistant);
  }

  /// Proves [session] now lives in tmux on the server: a marker typed into
  /// it comes back, and the server has a session by its name.
  Future<void> expectInTmux(TerminalSession session) async {
    expect(session.shellOrigin, ShellOrigin.tmuxCreated);
    expect(session.isLive, isTrue);
    final marker = 'in-tmux-${DateTime.now().millisecondsSinceEpoch}';
    // Split in the command so only the shell's output, not the echo of what
    // was typed, can match.
    session.send("echo '$marker''-ok'\r");
    await until(
      () => text(session).contains('$marker-ok'),
      what: 'the marker echoed from the new shell',
    );
    // Attached: this tab is a client of that session right now.
    final attached = await exec(
      posixShell(
        'tmux -L $kTmuxSocket display-message -p '
        '-t ${shellQuote('=${session.tmuxName}:')} '
        "'#{session_attached}'",
      ),
    );
    expect(int.tryParse(attached.stdout.trim()), greaterThanOrEqualTo(1));
  }

  test(
    'passwordless sudo: detect, offer, install with sudo -n, restart in tmux',
    () async {
      await prepare('nopass');
      final (session, assistant) = await openTab('live-nopass');
      expect(text(session), contains('tmux is not installed'));

      await assistant.detect();
      final offer = (assistant.stage as TmuxInstallOffered).offer as RunInstall;
      expect(
        offer.command,
        'sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
      );

      await assistant.install();
      expect(
        assistant.stage,
        isA<TmuxInstallSucceeded>(),
        reason: switch (assistant.stage) {
          TmuxInstallFailed(:final output) => output,
          _ => null,
        },
      );
      expect((await exec(posixShell('command -v tmux'))).exitCode, 0);

      await assistant.restart();
      await expectInTmux(session);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'root: runs without sudo',
    () async {
      await prepare('root');
      final (session, assistant) = await openTab('live-root');
      await assistant.detect();
      final offer = (assistant.stage as TmuxInstallOffered).offer as RunInstall;
      expect(
        offer.command,
        'env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
      );
      await assistant.install();
      expect(assistant.stage, isA<TmuxInstallSucceeded>());
      await assistant.restart();
      await expectInTmux(session);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'sudo wants a password: typed and run in the terminal, where sudo asks; '
    'then Restart in tmux',
    () async {
      await prepare('password');
      final (session, assistant) = await openTab('live-password');

      await assistant.detect();
      final offer =
          (assistant.stage as TmuxInstallOffered).offer
              as TypeInstallInTerminal;
      expect(
        offer.command,
        'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
      );

      await assistant.install();
      expect(assistant.stage, isA<TmuxInstallTyped>());
      // sudo is asking, in the terminal, for a password SSHetu never sees.
      await until(
        () => text(session).contains('[sudo] password'),
        what: 'the sudo prompt in the terminal',
      );
      expect((await exec(posixShell('command -v tmux'))).exitCode, isNot(0));

      // The user types it — into the terminal, as they would at a keyboard.
      session.send('$fakePassword\r');
      await until(
        () => text(session).contains('Setting up tmux'),
        what: 'the install to finish',
      );
      expect((await exec(posixShell('command -v tmux'))).exitCode, 0);

      // "Restart in tmux", as from the tab's menu.
      await session.restartInTmux();
      await expectInTmux(session);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'the probe over a real exec channel reads the simulated server',
    () async {
      await prepare('password');
      final result = await exec(tmuxInstallProbeCommand());
      final facts = parseTmuxInstallProbe(result.stdout)!;
      expect(facts.managers, [PackageManager.aptGet]);
      expect(facts.access, RootAccess.sudoNeedsPassword);
      expect(facts.tmuxPresent, isFalse);
      expect(facts.uid, isNot(0));
      expect(facts.kernel, 'Linux');
      // Proof the probe never prompted: it came back at all, over a channel
      // with no terminal to prompt on.
      expect(utf8.encode(result.stdout), isNotEmpty);
    },
    skip: skip,
  );
}
