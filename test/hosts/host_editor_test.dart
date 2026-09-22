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
    await database.raw.insert('host_groups', {
      'id': 'g1',
      'name': 'Production',
      'sort_order': 0,
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

  Future<void> pump(
    WidgetTester tester, {
    String? hostId,
    Size size = const Size(900, 1200),
  }) async {
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

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [
    ('compact', const Size(390, 900)),
    ('expanded', const Size(1400, 1000)),
  ]) {
    testWidgets('group, tags and notes are saved at $name width', (
      tester,
    ) async {
      await pump(tester, size: size);

      await tester.enterText(
        find.byType(TextFormField).first,
        'root@192.168.1.10',
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Organise'));

      await tapVisible(tester, find.text('No group'));
      await tester.tap(find.text('Production').last);
      await tester.pumpAndSettle();

      final tags = find.widgetWithText(TextField, 'Tags');
      await tester.ensureVisible(tags);
      // A comma commits; the last one is still being typed.
      await tester.enterText(tags, 'prod, eu west,');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'prod'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'eu west'), findsOneWidget);
      // Typed and never committed with Enter — Save still keeps it.
      await tester.enterText(tags, 'Prod');
      await tester.pumpAndSettle();
      await tester.enterText(tags, 'db');
      await tester.pumpAndSettle();

      final notes = find.widgetWithText(TextFormField, 'Notes');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'behind the VPN\nport 2222 for ssh');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final host = (await hosts(tester)).single;
      expect(host['group_id'], 'g1');
      expect(host['tags'], 'prod,eu west,db');
      expect(host['notes'], 'behind the VPN\nport 2222 for ssh');
      // Untouched advanced fields keep their defaults.
      expect(host['keepalive_seconds'], 30);
      expect(host['font_size'], isNull);
    });
  }

  testWidgets('keepalive and a font size override are saved', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'root@192.168.1.10',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Advanced'));

    final keepalive = find.widgetWithText(TextFormField, 'Keepalive interval');
    await tester.ensureVisible(keepalive);
    await tester.enterText(keepalive, '0');
    await tester.pumpAndSettle();

    // Off by default: following the app setting.
    await tapVisible(tester, find.text('Terminal font size'));
    await tapVisible(tester, find.byTooltip('Larger'));
    await tapVisible(tester, find.byTooltip('Larger'));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final host = (await hosts(tester)).single;
    expect(host['keepalive_seconds'], 0);
    expect(host['font_size'], 15.0);
  });

  testWidgets('a keepalive out of range is refused', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'root@192.168.1.10',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Advanced'));

    final keepalive = find.widgetWithText(TextFormField, 'Keepalive interval');
    await tester.ensureVisible(keepalive);
    await tester.enterText(keepalive, '99999');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await hosts(tester), isEmpty);
    expect(find.text('0–3600'), findsOneWidget);
  });

  testWidgets('an existing host opens with its organisation filled in', (
    tester,
  ) async {
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    await tester.runAsync(
      () => database.raw.insert('hosts', {
        'id': 'h1',
        'group_id': 'g1',
        'label': 'web',
        'hostname': 'web.example.com',
        'port': 22,
        'username': 'root',
        'auth_method': 'publicKey',
        'keepalive_seconds': 45,
        'font_size': 18.0,
        'tags': 'prod,eu',
        'notes': 'the one behind the bastion',
        'created_at': now,
        'updated_at': now,
      }),
    );

    await pump(tester, hostId: 'h1');

    // Organise opens on its own because there is something in it.
    expect(find.text('Production'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'prod'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'eu'), findsOneWidget);
    expect(find.text('the one behind the bastion'), findsOneWidget);
    await tester.ensureVisible(find.text('45'));
    expect(find.text('45'), findsOneWidget);
    await tester.ensureVisible(find.text('18 pt'));
    expect(find.text('18 pt'), findsOneWidget);

    // Removing a chip and saving clears it from the column.
    await tapVisible(
      tester,
      find.descendant(
        of: find.widgetWithText(InputChip, 'eu'),
        matching: find.byType(Icon),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final host = (await hosts(tester)).single;
    expect(host['tags'], 'prod');
    expect(host['group_id'], 'g1');
    expect(host['font_size'], 18.0);
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
