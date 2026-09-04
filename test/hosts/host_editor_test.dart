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

/// Adding a server from the one string people actually have.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = await openTestDatabase();
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    await database.raw.insert('identities', {
      'id': 'k1',
      'label': 'work laptop',
      'key_type': 'ssh-ed25519',
      'has_passphrase': 0,
      'origin': 'generated',
      'created_at': now,
      'updated_at': now,
    });

    SharedPreferences.setMockInitialValues({'settings.defaultIdentity': 'k1'});
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: HostEditorScreen(),
        ),
      ),
    );
    // Real turns, not just fake frames: the providers behind this screen read
    // sqlite, and a real future never completes under the test binding's fake
    // clock.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Real sqlite I/O, so it must happen outside the test binding's fake
  /// time — a real future never completes in there, and the test hangs rather
  /// than fails.
  Future<List<Map<String, Object?>>> hosts(WidgetTester tester) async {
    late List<Map<String, Object?>> rows;
    await tester.runAsync(() async => rows = await database.raw.query('hosts'));
    return rows;
  }

  testWidgets('one pasted line is enough to save a server', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'ssh root@192.168.1.10 -p 2222',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final host = (await hosts(tester)).single;
    expect(host['hostname'], '192.168.1.10');
    expect(host['username'], 'root');
    expect(host['port'], 2222);
    // The label follows the address until someone types their own.
    expect(host['label'], '192.168.1.10');
    // And it starts with the key nominated in Settings.
    expect(host['identity_id'], 'k1');
  });

  testWidgets('what was understood is shown before saving', (tester) async {
    // A form that silently decides where you are connecting is a form you
    // cannot check.
    await pump(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'root@example.com:2222',
    );
    await tester.pumpAndSettle();

    expect(find.text('root@example.com:2222'), findsWidgets);
  });

  testWidgets('a line with no user asks for one', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Nothing saved, and the reason is on screen rather than hidden behind a
    // disclosure the user never opened.
    expect(await hosts(tester), isEmpty);
    expect(find.text('Username'), findsOneWidget);
  });

  testWidgets('advanced options can still change everything', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'root@192.168.1.10',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    // The label field is in there, pre-filled from the address, and typing in
    // it stops the address overwriting it.
    final label = find.widgetWithText(TextFormField, '192.168.1.10');
    expect(label, findsWidgets);

    await tester.enterText(label.first, 'production box');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'root@192.168.1.11',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final host = (await hosts(tester)).single;
    expect(host['hostname'], '192.168.1.11');
    expect(host['label'], 'production box', reason: 'a typed label is theirs');
  });

  testWidgets('nonsense is refused rather than saved', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await hosts(tester), isEmpty);
  });
}
