import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/core/terminal/tmux_install.dart';
import 'package:sshetu/features/hosts/data/host_repository.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/sessions/tmux_install_assistant.dart';
import 'package:sshetu/features/sessions/widgets/tmux_install_banner.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../server_info/fake_server_exec.dart';
import '../support/fake_shell.dart';
import '../support/test_database.dart';
import '../support/tmux_probe_fixture.dart';

/// The banner as a tab shows it: when it appears, and what its answers do.
void main() {
  final now = DateTime.utc(2026);

  SshHost host({HostTmuxMode mode = HostTmuxMode.followDefault}) => SshHost(
    id: 'h1',
    label: 'build-box',
    hostname: 'build.example.com',
    username: 'me',
    tmuxMode: mode,
    createdAt: now,
    updatedAt: now,
  );

  late FakeServerExec exec;
  late FakeLauncher launcher;

  Future<(TerminalSession, ProviderContainer)> pump(
    WidgetTester tester, {
    ShellOrigin origin = ShellOrigin.plainWithoutTmux,
    HostTmuxMode mode = HostTmuxMode.followDefault,
    Size size = const Size(360, 800),
  }) async {
    exec = FakeServerExec(
      (command, _) => ExecResult(
        stdout: probe(managers: ['apt-get'], sudo: 'password'),
        exitCode: 0,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        hostsProvider.overrideWith((ref) async => [host(mode: mode)]),
        tmuxInstallAssistantsProvider.overrideWith(
          (ref) => TmuxInstallAssistants(ref, exec: (_) => exec),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = TerminalSession(
      id: 'h1-0',
      title: 'build-box',
      hostId: 'h1',
      keepOnServer: true,
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher = FakeLauncher()..origins = [origin],
      probe: () async => true,
    );
    addTearDown(session.dispose);
    await session.start();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Column(
              children: [
                TmuxInstallBanner(session: session),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (session, container);
  }

  final banner = find.byKey(const Key('tmuxInstall.banner'));

  for (final (name, size) in [
    ('phone', const Size(360, 800)),
    ('desktop', const Size(1280, 900)),
  ]) {
    testWidgets('at $name width: asks once tmux turns out to be missing', (
      tester,
    ) async {
      await pump(tester, size: size);
      expect(banner, findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(exec.calls.single.command, tmuxInstallProbeCommand());
      expect(
        find.text(
          'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a tab in tmux, or a plain one by choice, is never asked', (
    tester,
  ) async {
    for (final origin in [
      ShellOrigin.plain,
      ShellOrigin.tmuxCreated,
      ShellOrigin.tmuxReattached,
    ]) {
      await pump(tester, origin: origin);
      expect(banner, findsNothing);
      expect(exec.calls, isEmpty, reason: '$origin: nothing asked');
    }
  });

  testWidgets('a host set to never is never asked', (tester) async {
    await pump(tester, mode: HostTmuxMode.never);
    expect(banner, findsNothing);
    expect(exec.calls, isEmpty);
  });

  testWidgets('Not now hides it for the host, for this run', (tester) async {
    final (_, container) = await pump(tester);
    await tester.tap(find.byKey(const Key('tmuxInstall.notNow')));
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    expect(container.read(tmuxInstallSnoozeProvider), {'h1'});
  });

  testWidgets('Run in terminal types the command and presses Enter', (
    tester,
  ) async {
    final (session, _) = await pump(tester);
    final shell = (session.shellOrigin, session.isLive);
    expect(shell, (ShellOrigin.plainWithoutTmux, true));
    await tester.tap(find.byKey(const Key('tmuxInstall.install')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Enter your sudo password in the terminal'),
      findsOneWidget,
    );
    // Only the probe ran over exec; the install went to the terminal, with
    // Enter, so sudo asks for the password there.
    expect(exec.calls, hasLength(1));
    expect(launcher.shells.single.written, [
      '\x15sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux\r',
    ]);
  });

  test('Never is saved on the host', () async {
    final database = await openTestDatabase();
    addTearDown(database.raw.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(InMemorySecretVault()),
      ],
    );
    addTearDown(container.dispose);
    final repository = HostRepository(
      database: database.raw,
      vault: InMemorySecretVault(),
    );
    await repository.save(host());

    final setNever = FutureProvider<void>((ref) => setHostTmuxNever(ref, 'h1'));
    await container.read(setNever.future);

    expect((await repository.byId('h1'))!.tmuxMode, HostTmuxMode.never);
    expect((await database.raw.query('hosts')).single['tmux_mode'], 'never');
  });
}
