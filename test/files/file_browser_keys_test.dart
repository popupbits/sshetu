import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/files/widgets/file_browser_keys.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// F2 renames, in a desktop workspace tab, after clicking a row.
///
/// It never fired: rows are not focusable, so clicking one left focus where
/// it was — outside the browser — and `autofocus` does nothing when
/// something else in the scope already has focus. These run the browser's
/// key handling as a real workspace tab, with focus starting elsewhere.
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

  WorkspacePages pages() => container.read(workspacePagesProvider.notifier);

  late int renames;
  late FocusNode elsewhere;

  /// The workspace beside a side panel whose control holds focus, the way a
  /// real window's does; then the files page opened as a tab.
  Future<void> pumpFilesTab(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    renames = 0;
    elsewhere = FocusNode(debugLabel: 'side panel');
    addTearDown(elsewhere.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Focus(focusNode: elsewhere, child: const Text('side')),
                ),
                const Expanded(child: TerminalWorkspace()),
              ],
            ),
          ),
        ),
      ),
    );
    elsewhere.requestFocus();
    await tester.pump();
    expect(elsewhere.hasPrimaryFocus, isTrue);

    pages().open(
      WorkspacePage(
        id: 'files/s1',
        title: 'Files',
        icon: PiconsRegular.folderOpen,
        builder: (_) => FileBrowserKeys(
          onRename: () => renames++,
          child: Column(
            children: [
              const TextField(key: Key('path')),
              for (final name in ['a.txt', 'b'])
                // Rows are plain gestures, not focusable — like the real ones.
                GestureDetector(
                  onTap: () {},
                  child: SizedBox(height: 30, child: Text(name)),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('clicking a row, then F2, renames', (tester) async {
    await pumpFilesTab(tester);
    // Whatever happened on open, focus goes back to the side panel: the
    // click on a row is what has to bring it into the browser.
    elsewhere.requestFocus();
    await tester.pump();

    await tester.tap(find.text('a.txt'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(renames, 1);
  });

  testWidgets('F2 works as soon as the tab is shown', (tester) async {
    await pumpFilesTab(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(renames, 1);
  });

  testWidgets('F2 works again after switching tabs away and back', (
    tester,
  ) async {
    await pumpFilesTab(tester);
    pages().open(
      WorkspacePage(
        id: 'other',
        title: 'Other',
        icon: PiconsRegular.info,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    // Hidden: a hidden page's shortcut must not catch a key.
    elsewhere.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(renames, 0);

    pages().select('files/s1');
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(renames, 1);
  });

  testWidgets('a text field keeps its focus and its keys', (tester) async {
    await pumpFilesTab(tester);
    await tester.tap(find.byKey(const Key('path')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('path')), '/var/log');
    await tester.pump();
    final field = tester
        .state<EditableTextState>(find.byType(EditableText))
        .widget
        .focusNode;
    expect(field.hasPrimaryFocus, isTrue);

    // A second click into the field it is already in does not take focus
    // out of it, even for a moment.
    var lostFocus = false;
    void listener() => lostFocus |= !field.hasFocus;
    field.addListener(listener);
    addTearDown(() => field.removeListener(listener));
    await tester.tap(find.byKey(const Key('path')));
    await tester.pump();
    expect(lostFocus, isFalse);
    expect(field.hasPrimaryFocus, isTrue);
    expect(find.text('/var/log'), findsOneWidget);

    // F2 reaches the browser from inside the field.
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(renames, 1);
  });

  testWidgets('clicking a row while typing in the path bar, then F2', (
    tester,
  ) async {
    await pumpFilesTab(tester);
    await tester.tap(find.byKey(const Key('path')));
    await tester.pump();
    // With a mouse, the field drops its focus on a click outside it — to the
    // route's scope, outside the browser, as it does on every desktop.
    await tester.tap(find.text('b'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(renames, 1);
  });
}
