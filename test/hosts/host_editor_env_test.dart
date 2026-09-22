import 'dart:convert';

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

/// The host editor's Environment list, at a phone width and a desktop one.
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

  Future<void> pump(WidgetTester tester, Size size, {String? hostId}) async {
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
    await tester.runAsync(() async => rows = await database.raw.query('hosts'));
    return rows;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [
    ('phone', const Size(360, 800)),
    ('desktop', const Size(1280, 900)),
  ]) {
    group('at $name width', () {
      testWidgets('variables are saved exactly as typed', (tester) async {
        await pump(tester, size);
        await tester.enterText(
          find.byType(TextFormField).first,
          'root@10.0.0.1',
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Advanced'));

        await tapVisible(tester, find.byKey(const Key('hostEditor.env.add')));
        await type(tester, 'hostEditor.env.name.0', 'EDITOR');
        await type(tester, 'hostEditor.env.value.0', 'vim');
        await tapVisible(tester, find.byKey(const Key('hostEditor.env.add')));
        await type(tester, 'hostEditor.env.name.1', 'GREETING');
        await type(tester, 'hostEditor.env.value.1', 'it\'s "\$HOME" ok');
        // An empty row is dropped, not refused.
        await tapVisible(tester, find.byKey(const Key('hostEditor.env.add')));

        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final host = (await hosts(tester)).single;
        expect(jsonDecode(host['env_vars']! as String), {
          'EDITOR': 'vim',
          'GREETING': 'it\'s "\$HOME" ok',
        });
      });

      testWidgets('a name that is not a variable name stops Save', (
        tester,
      ) async {
        await pump(tester, size);
        await tester.enterText(
          find.byType(TextFormField).first,
          'root@10.0.0.1',
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Advanced'));
        await tapVisible(tester, find.byKey(const Key('hostEditor.env.add')));
        await type(tester, 'hostEditor.env.name.0', '1BAD-NAME');
        await type(tester, 'hostEditor.env.value.0', 'x');

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(await hosts(tester), isEmpty);
        expect(
          find.text('Letters, digits and _ only, not starting with a digit'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('an existing host shows its variables, and one can go', (
    tester,
  ) async {
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    await tester.runAsync(
      () => database.raw.insert('hosts', {
        'id': 'h1',
        'label': 'web',
        'hostname': 'web.example.com',
        'username': 'root',
        'env_vars': jsonEncode({'A': '1', 'B': 'two words'}),
        'created_at': now,
        'updated_at': now,
      }),
    );
    await pump(tester, const Size(360, 800), hostId: 'h1');

    final names = find.byKey(const Key('hostEditor.env.name.0'));
    await tester.ensureVisible(names);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('two words'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('hostEditor.env.remove.0')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final host = (await hosts(tester)).single;
    expect(jsonDecode(host['env_vars']! as String), {'B': 'two words'});
  });

  testWidgets('agent forwarding is off by default and saved when on', (
    tester,
  ) async {
    await pump(tester, const Size(1280, 900));
    await tester.enterText(find.byType(TextFormField).first, 'root@10.0.0.1');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Advanced'));

    final toggle = find.byKey(const Key('hostEditor.forwardAgent'));
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(
      find.textContaining('Only enable it for servers you trust'),
      findsOneWidget,
    );
    await tapVisible(tester, toggle);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await hosts(tester)).single['forward_agent'], 1);
  });
}
