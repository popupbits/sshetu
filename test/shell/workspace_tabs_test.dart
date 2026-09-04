import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/backup/presentation/export_screen.dart';
import 'package:sshetu/features/backup/presentation/import_screen.dart';
import 'package:sshetu/features/hosts/host_editor_screen.dart';
import 'package:sshetu/features/import/import_screen.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';
import 'package:sshetu/features/settings/about_screen.dart';
import 'package:sshetu/features/settings/diagnostics_screen.dart';
import 'package:sshetu/features/settings/known_hosts_screen.dart';
import 'package:sshetu/features/transfer/presentation/receive_screen.dart';
import 'package:sshetu/features/transfer/presentation/send_screen.dart';
import 'package:sshetu/features/tunnels/tunnel_editor_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// Every page that can become a workspace tab, at every width one can be.
///
/// These are embedded in a pane whose width the user drags, so each of them
/// has to survive a range no full-screen route ever sees. An overflow here is
/// a yellow-and-black bar beside someone's terminal.
void main() {
  late AppDatabase database;

  setUp(() async {
    database = await openTestDatabase();
    // With content, not empty. An editor with no keys and no other hosts
    // renders none of its dropdowns, so an empty database is exactly the
    // shape that never overflows — and exactly the shape a real user is not.
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    for (final key in const [
      ('k1', 'work laptop ed25519', 'ssh-ed25519'),
      ('k2', 'an older RSA key kept for one legacy box', 'ssh-rsa'),
    ]) {
      await database.raw.insert('identities', {
        'id': key.$1,
        'label': key.$2,
        'key_type': key.$3,
        'has_passphrase': 0,
        'origin': 'generated',
        'created_at': now,
        'updated_at': now,
      });
    }
    for (final host in const ['bastion', 'production-database-eu-west-1']) {
      await database.raw.insert('hosts', {
        'id': host,
        'label': host,
        'hostname': '$host.internal.example.com',
        'port': 22,
        'username': 'root',
        'auth_method': 'publicKey',
        'allow_legacy_algorithms': 0,
        'keepalive_seconds': 30,
        'created_at': now,
        'updated_at': now,
      });
    }
  });
  tearDown(() async => database.raw.close());

  final pages = <String, WidgetBuilder>{
    'send': (_) => const TransferSendScreen(embedded: true),
    'receive': (_) => const TransferReceiveScreen(embedded: true),
    'backup': (_) => const BackupExportScreen(embedded: true),
    'restore': (_) => const BackupImportScreen(embedded: true),
    'host': (_) => const HostEditorScreen(embedded: true),
    'tunnel': (_) => const TunnelEditorScreen(embedded: true),
    'import': (_) => const ImportScreen(embedded: true),
    'knownHosts': (_) => const KnownHostsScreen(embedded: true),
    'diagnostics': (_) => const DiagnosticsScreen(embedded: true),
    'about': (_) => const AboutScreen(embedded: true),
  };

  Future<void> pumpTab(
    WidgetTester tester,
    String id,
    WidgetBuilder builder,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(InMemorySecretVault()),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(body: TerminalWorkspace()),
        ),
      ),
    );

    container.read(workspacePagesProvider.notifier).open(
      WorkspacePage(
        id: id,
        title: id,
        icon: PiconsRegular.qrCode,
        builder: builder,
      ),
    );

    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  /// Tears the tree down and lets what it owned go.
  ///
  /// Some of these pages hold real resources — the send screen opens a
  /// listening socket with a timeout on it — and disposing is asynchronous.
  /// Ending a test with one still pending fails on a timer rather than on
  /// anything to do with layout.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  for (final entry in pages.entries) {
    testWidgets('${entry.key} fits a tab at any pane width', (tester) async {
      // From a small phone to a maximised window, through every step where
      // something switches layout: 720 is where the tunnel picker goes side
      // by side, 380 where the receive screen stacks its button.
      for (final width in [
        1600.0,
        1100.0,
        800.0,
        720.0,
        700.0,
        640.0,
        420.0,
        380.0,
        360.0,
        320.0,
      ]) {
        await pumpTab(tester, entry.key, entry.value, Size(width, 900));

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} overflowed at ${width}pt',
        );
        await disposeTree(tester);
      }
    });
  }
}
