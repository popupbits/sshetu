import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/host_editor_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// The host editor's "Keep sessions running on this server (tmux)" choice,
/// at a phone width and a desktop one.
void main() {
  late AppDatabase database;

  setUp(() async => database = await openTestDatabase());
  tearDown(() async => database.raw.close());

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    String? hostId,
    bool globalOn = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings.keepSessionsOnServer': globalOn,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
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
          home: HostEditorScreen(hostId: hostId),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, Object?>>> hosts(WidgetTester tester) async {
    late List<Map<String, Object?>> rows;
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.runAsync(() async => rows = await database.raw.query('hosts'));
    return rows;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  final choice = find.byKey(const Key('hostEditor.tmuxMode'));

  for (final (name, size) in [
    ('phone', const Size(360, 800)),
    ('desktop', const Size(1280, 900)),
  ]) {
    group('at $name width', () {
      testWidgets('defaults to the setting, named with its current state', (
        tester,
      ) async {
        await pump(tester, size);
        await tester.enterText(
          find.byType(TextFormField).first,
          'root@10.0.0.1',
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Advanced'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();

        expect(
          find.text('Keep sessions running on this server (tmux)'),
          findsOneWidget,
        );
        expect(find.text('Default (currently on)'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect((await hosts(tester)).single['tmux_mode'], isNull);
      });

      testWidgets('Never is saved as never', (tester) async {
        await pump(tester, size);
        await tester.enterText(
          find.byType(TextFormField).first,
          'root@10.0.0.1',
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Advanced'));
        await tapVisible(tester, choice);
        await tester.tap(find.text('Never').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect((await hosts(tester)).single['tmux_mode'], 'never');
      });
    });
  }

  testWidgets('with the setting off, the default says so', (tester) async {
    await pump(tester, const Size(360, 800), globalOn: false);
    await tester.enterText(find.byType(TextFormField).first, 'root@10.0.0.1');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Advanced'));
    await tester.ensureVisible(choice);
    expect(find.text('Default (currently off)'), findsOneWidget);
  });

  testWidgets('an existing host shows its choice, and Always is saved', (
    tester,
  ) async {
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    await tester.runAsync(
      () => database.raw.insert('hosts', {
        'id': 'h1',
        'label': 'web',
        'hostname': 'web.example.com',
        'username': 'root',
        'tmux_mode': 'never',
        'created_at': now,
        'updated_at': now,
      }),
    );
    await pump(tester, const Size(1280, 900), hostId: 'h1');
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: choice, matching: find.text('Never')),
      findsOneWidget,
    );

    await tapVisible(tester, choice);
    await tester.tap(find.text('Always').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await hosts(tester)).single['tmux_mode'], 'always');
  });
}
