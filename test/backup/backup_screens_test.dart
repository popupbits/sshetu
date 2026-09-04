import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/backup/backup_service.dart';
import 'package:sshetu/features/backup/crypto/passphrase_key.dart';
import 'package:sshetu/features/backup/presentation/export_screen.dart';
import 'package:sshetu/features/backup/presentation/import_screen.dart';
import 'package:sshetu/features/backup/presentation/passphrase_strength.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// A backup service that keeps the file in memory instead of on disk, so the
/// screens can be driven without a native save panel.
class _FakeBackupService extends BackupService {
  // Derives on this isolate: `Isolate.run` completes from a real port
  // message, which a future made inside the test binding's fake-time zone
  // never hears — the test hangs instead of failing.
  const _FakeBackupService(this.store)
    : super(derive: PassphraseKey.deriveHere);

  final _Store store;

  @override
  Future<BackupResult> save(Uint8List bytes, {DateTime? when}) async {
    store.saved = bytes;
    return (destination: BackupDestination.saved, path: '/tmp/backup');
  }

  @override
  Future<({Uint8List bytes, String name})?> pick() async {
    final bytes = store.saved;
    if (bytes == null) return null;
    return (bytes: bytes, name: 'sshetu-backup.sshetu-backup');
  }
}

class _Store {
  Uint8List? saved;
}

/// One host, one identity, one private key — enough to prove a backup carried
/// each kind of thing.
Future<void> _seed(AppDatabase database, InMemorySecretVault vault) async {
  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  await database.raw.insert('identities', {
    'id': 'k1',
    'label': 'laptop',
    'key_type': 'ssh-ed25519',
    'has_passphrase': 0,
    'origin': 'generated',
    'created_at': now,
    'updated_at': now,
  });
  await database.raw.insert('hosts', {
    'id': 'h1',
    'label': 'server',
    'hostname': '10.0.0.1',
    'port': 22,
    'username': 'root',
    'auth_method': 'publicKey',
    'identity_id': 'k1',
    'allow_legacy_algorithms': 0,
    'keepalive_seconds': 30,
    'created_at': now,
    'updated_at': now,
  });
  await vault.write(SecretRef.identityPrivateKey('k1'), 'PRIVATE-KEY');
}

void main() {
  group('the passphrase meter', () {
    test('calls a short one weak', () {
      expect(strengthOf('hunter2'), PassphraseStrength.weak);
      expect(strengthOf('shortpass12'), PassphraseStrength.weak);
    });

    test('is not fooled by length alone', () {
      // Long and worthless: the meter has to look at more than the count.
      expect(strengthOf('aaaaaaaaaaaaaaaaaaaaaaa'), PassphraseStrength.weak);
    });

    test('rewards a real passphrase', () {
      expect(
        strengthOf('correct horse battery staple'),
        PassphraseStrength.strong,
      );
      expect(strengthOf('Tr0ub4dor&3xyz9kQ2mZ'), PassphraseStrength.strong);
    });

    test('and something in between', () {
      expect(strengthOf('bluecat1947'), PassphraseStrength.weak);
      expect(strengthOf('bluecat19472'), PassphraseStrength.fair);
    });
  });

  group('the screens', () {
    late AppDatabase database;
    late InMemorySecretVault vault;
    late _Store store;

    setUp(() async {
      database = await openTestDatabase();
      vault = InMemorySecretVault();
      store = _Store();
      // Seeded here, never inside a test body. sqflite writes are real file
      // I/O, and a widget test body runs in fake time where a real future
      // never completes — the test hangs rather than fails, which cost an
      // hour to work out once already.
      await _seed(database, vault);
    });

    tearDown(() async => database.raw.close());

    /// Real I/O, so it has to happen outside fake time.
    Future<T> io<T>(WidgetTester tester, Future<T> Function() body) async {
      late T result;
      await tester.runAsync(() async => result = await body());
      return result;
    }


    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            secretVaultProvider.overrideWithValue(vault),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(body: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Argon2id is deliberately slow, so the screens need real time to pass.
    ///
    /// Real time, not fake: the derivation is genuine work on a real clock,
    /// and pumping fake frames at it would never advance it.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    testWidgets('a mismatched passphrase never reaches the file', (
      tester,
    ) async {
      await pump(
        tester,
        BackupExportScreen(embedded: true, service: _FakeBackupService(store)),
      );

      await tester.enterText(
        find.byType(TextField).first,
        'correct horse battery staple',
      );
      await tester.enterText(find.byType(TextField).last, 'something else');
      await tester.tap(find.text('Save a backup…'));
      await settle(tester);

      expect(find.text('The two passphrases are different.'), findsOneWidget);
      expect(store.saved, isNull, reason: 'nothing should have been written');
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('a short passphrase is refused, with the reason', (
      tester,
    ) async {
      await pump(
        tester,
        BackupExportScreen(embedded: true, service: _FakeBackupService(store)),
      );

      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.enterText(find.byType(TextField).last, 'abc');
      await tester.tap(find.text('Save a backup…'));
      await settle(tester);

      expect(find.textContaining('at least 8'), findsOneWidget);
      expect(store.saved, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('a saved backup restores through the two screens', (
      tester,
    ) async {
      await pump(
        tester,
        BackupExportScreen(embedded: true, service: _FakeBackupService(store)),
      );

      await tester.enterText(
        find.byType(TextField).first,
        'correct horse battery staple',
      );
      await tester.enterText(
        find.byType(TextField).last,
        'correct horse battery staple',
      );
      await tester.tap(find.text('Save a backup…'));
      await settle(tester);

      expect(store.saved, isNotNull, reason: 'the export should have written');
      // The passphrase does not stay on screen once it has been used.
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((field) => field.controller?.text),
        everyElement(isEmpty),
      );

      // Now restore it into a device that has nothing.
      await io(tester, () => database.raw.delete('hosts'));
      await io(tester, () => database.raw.delete('identities'));

      await pump(
        tester,
        BackupImportScreen(embedded: true, service: _FakeBackupService(store)),
      );
      await tester.tap(find.text('Choose file…'));
      await settle(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'correct horse battery staple',
      );
      await tester.tap(find.text('Open backup'));
      await settle(tester);

      // What is in the file, shown before anything is written.
      expect(find.textContaining('1 servers'), findsOneWidget);
      expect(
        find.text('Includes private keys and saved passwords.'),
        findsOneWidget,
      );
      expect(await io(tester, () => database.raw.query('hosts')), isEmpty);

      await tester.tap(find.text('Restore'));
      await settle(tester);

      expect(await io(tester, () => database.raw.query('hosts')), hasLength(1));
      expect(await io(tester, () => database.raw.query('identities')), hasLength(1));
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('a wrong passphrase says so and writes nothing', (
      tester,
    ) async {
      await pump(
        tester,
        BackupExportScreen(embedded: true, service: _FakeBackupService(store)),
      );
      await tester.enterText(
        find.byType(TextField).first,
        'correct horse battery staple',
      );
      await tester.enterText(
        find.byType(TextField).last,
        'correct horse battery staple',
      );
      await tester.tap(find.text('Save a backup…'));
      await settle(tester);

      await io(tester, () => database.raw.delete('hosts'));

      await pump(
        tester,
        BackupImportScreen(embedded: true, service: _FakeBackupService(store)),
      );
      await tester.tap(find.text('Choose file…'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'not it');
      await tester.tap(find.text('Open backup'));
      await settle(tester);

      expect(find.textContaining('does not open'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(await io(tester, () => database.raw.query('hosts')), isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
