import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/db/database.dart';
import 'package:ssh_navigator/core/sync/sync_engine.dart';

import '../support/test_database.dart';
import 'fake_sync_remote.dart';

/// End-to-end over the sync engine: two real, separate local databases
/// sharing one [FakeSyncRemote] — standing in for two devices signed into
/// the same account — and the real schema, migrations included.
void main() {
  late AppDatabase deviceA;
  late AppDatabase deviceB;
  late FakeSyncRemote remote;

  const userId = 'user-1';

  setUp(() async {
    deviceA = await openTestDatabase();
    deviceB = await openTestDatabase();
    remote = FakeSyncRemote();
  });

  tearDown(() async {
    await deviceA.close();
    await deviceB.close();
  });

  SyncEngine engineFor(AppDatabase db) =>
      SyncEngine(database: db.raw, remote: remote, userId: userId);

  Future<void> insertHost(
    AppDatabase db, {
    required String id,
    required int updatedAt,
    String label = 'host',
    int dirty = 1,
    int? deletedAt,
  }) => db.raw.insert('hosts', {
    'id': id,
    'label': label,
    'hostname': '$id.example.com',
    'username': 'deploy',
    'created_at': updatedAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
    'dirty': dirty,
  });

  Future<Map<String, Object?>> hostRow(AppDatabase db, String id) async {
    final rows = await db.raw.query('hosts', where: 'id = ?', whereArgs: [id]);
    return rows.single;
  }

  group('push/pull round trip', () {
    test(
      'a row pushed from one device appears on another after a pull',
      () async {
        await insertHost(deviceA, id: 'h1', updatedAt: 1000, label: 'from-a');

        await engineFor(deviceA).push();
        await engineFor(deviceB).pull();

        final row = await hostRow(deviceB, 'h1');
        expect(row['label'], 'from-a');
        expect(row['dirty'], 0, reason: 'a freshly pulled row is not dirty');
      },
    );

    test(
      'push clears dirty and stamps synced_at on the source device',
      () async {
        await insertHost(deviceA, id: 'h1', updatedAt: 1000);
        await engineFor(deviceA).push();

        final row = await hostRow(deviceA, 'h1');
        expect(row['dirty'], 0);
        expect(row['synced_at'], isNotNull);
      },
    );

    test('a pull with nothing new is a harmless no-op', () async {
      await insertHost(deviceA, id: 'h1', updatedAt: 1000);
      await engineFor(deviceA).push();
      await engineFor(deviceB).pull();

      // Second pull: nothing changed remotely since the cursor advanced.
      await engineFor(deviceB).pull();

      expect(await deviceB.raw.query('hosts'), hasLength(1));
    });
  });

  group('last-writer-wins conflict resolution', () {
    Future<void> seedSyncedOnBoth({required int updatedAt}) async {
      await insertHost(
        deviceA,
        id: 'h1',
        updatedAt: updatedAt,
        label: 'shared',
        dirty: 1,
      );
      await engineFor(deviceA).push();
      await engineFor(deviceB).pull();
    }

    test(
      'a strictly newer remote edit overwrites an unpushed local edit',
      () async {
        // The cost this documents and pins: device B's edit is discarded with
        // no trace and no prompt. That is the accepted tradeoff — this test
        // exists so it stays a documented decision rather than an
        // accidentally-changed behaviour.
        await seedSyncedOnBoth(updatedAt: 1000);

        await deviceB.raw.update(
          'hosts',
          {'label': 'edited-on-b', 'updated_at': 2000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );

        await deviceA.raw.update(
          'hosts',
          {'label': 'edited-on-a', 'updated_at': 3000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );
        await engineFor(deviceA).push();

        await engineFor(deviceB).pull();

        final row = await hostRow(deviceB, 'h1');
        expect(row['label'], 'edited-on-a');
        expect(row['dirty'], 0);
      },
    );

    test(
      'an unpushed local edit newer than the incoming remote survives',
      () async {
        await seedSyncedOnBoth(updatedAt: 1000);

        await deviceA.raw.update(
          'hosts',
          {'label': 'edited-on-a', 'updated_at': 2000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );
        await engineFor(deviceA).push();

        await deviceB.raw.update(
          'hosts',
          {'label': 'edited-on-b', 'updated_at': 5000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );

        await engineFor(deviceB).pull();

        final row = await hostRow(deviceB, 'h1');
        expect(
          row['label'],
          'edited-on-b',
          reason: 'the newer, unpushed edit must not be discarded',
        );
        expect(row['dirty'], 1, reason: 'it still has not reached the backend');
      },
    );

    test(
      'a same-millisecond tie keeps the local edit rather than flipping a coin',
      () async {
        await seedSyncedOnBoth(updatedAt: 1000);

        await deviceA.raw.update(
          'hosts',
          {'label': 'edited-on-a', 'updated_at': 2000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );
        await engineFor(deviceA).push();

        // Same updated_at as what A just pushed, but different content — the
        // shape of "this device's own edit, not yet marked clean".
        await deviceB.raw.update(
          'hosts',
          {'label': 'edited-on-b', 'updated_at': 2000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );

        await engineFor(deviceB).pull();

        final row = await hostRow(deviceB, 'h1');
        expect(row['label'], 'edited-on-b');
        expect(row['dirty'], 1);
      },
    );

    test(
      'a clean local row (no conflict) simply takes the remote update',
      () async {
        await seedSyncedOnBoth(updatedAt: 1000);

        await deviceA.raw.update(
          'hosts',
          {'label': 'edited-on-a', 'updated_at': 2000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );
        await engineFor(deviceA).push();

        await engineFor(deviceB).pull();

        final row = await hostRow(deviceB, 'h1');
        expect(row['label'], 'edited-on-a');
      },
    );
  });

  group('tombstones', () {
    test('a delete on one device removes the row on another', () async {
      await insertHost(deviceA, id: 'h1', updatedAt: 1000);
      await engineFor(deviceA).push();
      await engineFor(deviceB).pull();

      await deviceA.raw.update(
        'hosts',
        {'deleted_at': 2000, 'updated_at': 2000, 'dirty': 1},
        where: 'id = ?',
        whereArgs: ['h1'],
      );
      await engineFor(deviceA).push();

      await engineFor(deviceB).pull();

      final row = await hostRow(deviceB, 'h1');
      expect(row['deleted_at'], isNotNull);
    });

    test(
      'a tombstoned row does not resurrect on a later, empty pull',
      () async {
        await insertHost(deviceA, id: 'h1', updatedAt: 1000);
        await engineFor(deviceA).push();
        await engineFor(deviceB).pull();

        await deviceA.raw.update(
          'hosts',
          {'deleted_at': 2000, 'updated_at': 2000, 'dirty': 1},
          where: 'id = ?',
          whereArgs: ['h1'],
        );
        await engineFor(deviceA).push();
        await engineFor(deviceB).pull();

        // Nothing else changes; a second, empty pull must not bring it back.
        await engineFor(deviceB).pull();

        final row = await hostRow(deviceB, 'h1');
        expect(row['deleted_at'], isNotNull);
      },
    );
  });

  group('interrupted push', () {
    test(
      'a failed row leaves it and everything after it dirty for the next run',
      () async {
        await insertHost(deviceA, id: 'h1', updatedAt: 1000);
        await insertHost(deviceA, id: 'h2', updatedAt: 2000);
        await insertHost(deviceA, id: 'h3', updatedAt: 3000);

        // Simulates a connection dropped partway through — h2 is the row in
        // flight when it happens.
        remote.failOnceForId['h2'] = StateError('connection dropped');

        await expectLater(
          engineFor(deviceA).push(),
          throwsA(isA<StateError>()),
        );

        expect(
          (await hostRow(deviceA, 'h1'))['dirty'],
          0,
          reason: 'already reached the backend before the drop',
        );
        expect(
          (await hostRow(deviceA, 'h2'))['dirty'],
          1,
          reason: 'the row in flight when it failed',
        );
        expect(
          (await hostRow(deviceA, 'h3'))['dirty'],
          1,
          reason: 'never even attempted',
        );

        // The retry: the failure was one-shot, so this run goes through.
        await engineFor(deviceA).push();

        expect((await hostRow(deviceA, 'h2'))['dirty'], 0);
        expect((await hostRow(deviceA, 'h3'))['dirty'], 0);
      },
    );
  });

  group('known_hosts', () {
    test('is never pushed or pulled', () async {
      await deviceA.raw.insert('known_hosts', {
        'hostname': 'box.example.com',
        'port': 22,
        'key_type': 'ssh-ed25519',
        'fingerprint': 'SHA256:abc',
        'trusted_at': 1000,
      });

      await insertHost(deviceA, id: 'h1', updatedAt: 1000);
      await engineFor(deviceA).push();
      await engineFor(deviceA).pull();

      expect(
        remote.tables.containsKey('known_hosts'),
        isFalse,
        reason:
            'a trust decision made on one device must not become fleet-wide '
            'trust — known_hosts has no dirty/synced_at columns at all, and '
            'is absent from SyncEngine.syncTables on top of that',
      );
    });
  });
}
