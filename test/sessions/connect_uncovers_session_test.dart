import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/host_key_verifier.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/sessions/connect.dart';
import 'package:sshetu/features/sessions/pane_layouts.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/fake_shell.dart';
import '../support/test_database.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// Connecting on a desktop shows the new tab, even with a page open.
///
/// With Files (or any page) selected, tapping a host opened its tab behind
/// the page: the tab strip gained an entry, the terminal stayed covered.
void main() {
  late ProviderContainer container;
  late AppDatabase database;

  setUp(() async {
    database = await openTestDatabase();
    addTearDown(() => database.raw.close());
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final triggers = FakeTriggers();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(InMemorySecretVault()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(triggers),
        sessionManagerProvider.overrideWith(_InstantSessionManager.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(triggers.dispose);
  });

  final host = SshHost(
    id: 'h1',
    label: 'web',
    hostname: 'example.invalid',
    port: 22,
    username: 'me',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Future<void> pumpConnectButton(WidgetTester tester, Size size) async {
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
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => connectToHost(context, ref, host),
                child: const Text('connect'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void openPage() => container
      .read(workspacePagesProvider.notifier)
      .open(
        WorkspacePage(
          id: 'files/x',
          title: 'Files',
          icon: PiconsRegular.folderOpen,
          builder: (_) => const SizedBox(),
        ),
      );

  testWidgets('a page covering the terminal steps aside for the new tab', (
    tester,
  ) async {
    await pumpConnectButton(tester, const Size(1400, 900));
    openPage();
    expect(container.read(workspacePagesProvider.notifier).selected, isNotNull);

    await tester.tap(find.text('connect'));
    await tester.pump();
    await tester.pump();

    expect(container.read(sessionManagerProvider), hasLength(1));
    expect(
      container.read(workspacePagesProvider.notifier).selected,
      isNull,
      reason: 'the new session must not open behind a page',
    );
    // Stepping aside is not closing: the page is still a tab.
    expect(container.read(workspacePagesProvider), hasLength(1));
  });
}

/// Opens a tab at once over a fake shell, with no server behind it.
class _InstantSessionManager extends SessionManager {
  @override
  Future<TerminalSession> connect(
    SshHost host, {
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
    required KeyboardInteractivePrompter interactivePrompt,
    String? tmuxName,
    bool resuming = false,
    bool ownsTmuxSession = true,
    SshConnection? connection,
    bool activate = true,
    PaneSplitRequest? split,
  }) async {
    final session = TerminalSession(
      id: '${host.id}-0',
      title: host.label,
      hostId: host.id,
      connection: SshConnection(
        target: const SshTarget(
          hostname: 'example.invalid',
          username: 'me',
          port: 22,
        ),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: FakeLauncher(),
      probe: () async => true,
    );
    adopt(session);
    return session;
  }
}
