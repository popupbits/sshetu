import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/host_editor_screen.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';
import 'package:sshetu/features/snippets/snippet_editor_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/settle.dart';
import '../support/test_database.dart';

/// A form opened as a desktop workspace tab closes its tab when it saves.
///
/// It used to call `Navigator.maybePop`, which inside a tab finds the shell's
/// navigator, has nothing to pop, and does nothing: the saved "New host" tab
/// stayed open, and pressing Save again wrote a second copy of the host.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = await openTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(InMemorySecretVault()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        settingsControllerProvider.overrideWith(
          () => SettingsController(initial: readSettings(preferences)),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async => database.raw.close());

  Future<void> openInWorkspaceTab(
    WidgetTester tester,
    String id,
    WidgetBuilder builder,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1200);
    addTearDown(tester.view.reset);

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
    container
        .read(workspacePagesProvider.notifier)
        .open(
          WorkspacePage(
            id: id,
            title: id,
            icon: PiconsRegular.hardDrives,
            builder: builder,
          ),
        );
    await tester.pump();
  }

  testWidgets('saving a new host closes its tab', (tester) async {
    await openInWorkspaceTab(
      tester,
      'host/new',
      (_) => const HostEditorScreen(embedded: true),
    );
    await settleUntilFound(tester, find.byType(HostEditorScreen));

    await tester.enterText(
      find.byType(TextFormField).first,
      'ssh -p 2234 root@192.168.1.10',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    // Waited for rather than counted out: the save writes to sqlite, and how
    // long that takes is the runner's business, not this test's.
    await settleUntil(
      tester,
      () => container.read(workspacePagesProvider).isEmpty,
      reason: 'the saved host tab',
    );

    expect(find.byType(HostEditorScreen), findsNothing);
    late List<Map<String, Object?>> rows;
    await tester.runAsync(() async => rows = await database.raw.query('hosts'));
    expect(rows, hasLength(1));
  });

  testWidgets('saving a new snippet closes its tab', (tester) async {
    await openInWorkspaceTab(
      tester,
      'snippet/new',
      (_) => const SnippetEditorScreen(embedded: true),
    );
    await settleUntilFound(tester, find.byType(SnippetEditorScreen));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'uptime');
    await tester.enterText(fields.at(1), 'uptime');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settleUntil(
      tester,
      () => container.read(workspacePagesProvider).isEmpty,
      reason: 'the saved snippet tab',
    );

    expect(find.byType(SnippetEditorScreen), findsNothing);
  });
}
