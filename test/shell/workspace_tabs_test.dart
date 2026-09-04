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

  setUp(() async => database = await openTestDatabase());
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
      // The narrowest is the panel's own floor beside a terminal; the widest
      // is a maximised window with the panel dragged small.
      for (final width in [1500.0, 900.0, 640.0, 420.0, 320.0]) {
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
