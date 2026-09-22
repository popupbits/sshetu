import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshetu/core/db/migrations/migrations.dart';

/// The v1 schema makes claims in its comments — this deleting cascades, that
/// one is restricted, this column defaults to the safe value. Those are
/// behaviours, not documentation, and SQLite only enforces the referential
/// ones when `PRAGMA foreign_keys` is on. Every one of them is checked here
/// against real SQLite, because the alternative is finding out on a device
/// that deleting a folder silently orphaned someone's servers.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> open() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final migration in migrations) {
      await migration.run(db, (path) async => File(path).readAsString());
    }
    return db;
  }

  late Database db;
  setUp(() async => db = await open());
  tearDown(() async => db.close());

  const t = 1735689600000; // an arbitrary fixed epoch

  Future<void> insertGroup(String id, {String? parent}) =>
      db.insert('host_groups', {
        'id': id,
        'name': id,
        'parent_id': parent,
        'created_at': t,
        'updated_at': t,
      });

  Future<void> insertHost(String id, {String? group, String? jump}) =>
      db.insert('hosts', {
        'id': id,
        'group_id': group,
        'label': id,
        'hostname': '$id.example.com',
        'username': 'root',
        'jump_host_id': jump,
        'created_at': t,
        'updated_at': t,
      });

  group('v2 — repairing hosts the import mislabelled', () {
    Future<void> insertPasswordHost(String id, {String? identity}) =>
        db.insert('hosts', {
          'id': id,
          'label': id,
          'hostname': '$id.example.com',
          'username': 'root',
          'auth_method': 'password',
          'identity_id': identity,
          'created_at': t,
          'updated_at': t,
        });

    test('a password host with no key is moved to key auth', () async {
      // Exactly the shape the import bug produced. `ssh` would have offered
      // the user's keys here; the row said to prompt for a password instead.
      await insertPasswordHost('imported');

      // Re-run v2 over the existing row, as an upgrade does. Just v2, not
      // "everything after v1": `db` is already fully migrated by setUp's
      // open(), so replaying a later, non-repeatable schema migration (v3's
      // CREATE TABLE) here would fail on "already exists" rather than test
      // anything about v2.
      await migrations[1].run(db, (path) async => File(path).readAsString());

      final row = (await db.query('hosts', where: "id = 'imported'")).single;
      expect(row['auth_method'], 'publicKey');
      expect(row['dirty'], 1, reason: 'the change has to reach the backend');
    });

    test('a password host that names a key is left alone', () async {
      // Not the bug's shape: someone chose this deliberately.
      await db.insert('identities', {
        'id': 'k1',
        'label': 'laptop',
        'key_type': 'ssh-ed25519',
        'created_at': t,
        'updated_at': t,
      });
      await insertPasswordHost('deliberate', identity: 'k1');

      // Just v2 — see the comment on the first test in this group.
      await migrations[1].run(db, (path) async => File(path).readAsString());

      final row = (await db.query('hosts', where: "id = 'deliberate'")).single;
      expect(row['auth_method'], 'password');
    });

    test('a key host is untouched', () async {
      await insertHost('keyed');

      // Just v2 — see the comment on the first test in this group.
      await migrations[1].run(db, (path) async => File(path).readAsString());

      final row = (await db.query('hosts', where: "id = 'keyed'")).single;
      expect(row['auth_method'], 'publicKey');
    });
  });

  group('tables', () {
    test('every table the app needs exists', () async {
      final rows = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
      );
      final names = rows.map((r) => r['name']! as String).toSet();

      expect(
        names,
        containsAll(<String>{
          'host_groups',
          'identities',
          'hosts',
          'known_hosts',
          'tunnels',
          'snippets',
        }),
      );
    });

    test('the sync bookkeeping is gone', () async {
      // v3 created `sync_cursors` for the Appwrite pull cursor; v4 drops it,
      // because there is no backend to pull from any more. A migration that
      // silently no-ops leaves the table behind on every device that already
      // ran v3 — which is every developer machine.
      final rows = await db.query(
        'sqlite_master',
        where: "type = 'table' AND name = 'sync_cursors'",
      );
      expect(rows, isEmpty);
    });

    test('the placeholder table beej generated is gone', () async {
      final rows = await db.query(
        'sqlite_master',
        where: "type = 'table' AND name = 'items'",
      );
      expect(rows, isEmpty);
    });
  });

  group('defaults are the safe ones', () {
    test(
      'a host defaults to port 22, modern algorithms and a keepalive',
      () async {
        await insertHost('h1');
        final row = (await db.query('hosts', where: "id = 'h1'")).single;

        expect(row['port'], 22);
        expect(
          row['allow_legacy_algorithms'],
          0,
          reason: 'weakened algorithms must never be the stored default',
        );
        expect(row['keepalive_seconds'], 30);
        expect(row['auth_method'], 'publicKey');
        expect(row['deleted_at'], isNull);
        expect(
          row['dirty'],
          1,
          reason: 'a new row has not reached the backend',
        );
      },
    );

    test('a tunnel binds loopback unless told otherwise', () async {
      await insertHost('h1');
      await db.insert('tunnels', {
        'id': 'tn1',
        'host_id': 'h1',
        'label': 'db',
        'kind': 'local',
        'listen_port': 5432,
        'created_at': t,
        'updated_at': t,
      });

      final row = (await db.query('tunnels', where: "id = 'tn1'")).single;
      expect(
        row['listen_host'],
        '127.0.0.1',
        reason:
            'binding 0.0.0.0 exposes the forward to the whole network and '
            'must be an explicit choice',
      );
      expect(row['auto_start'], 0);
    });
  });

  group('referential behaviour', () {
    test('deleting a group leaves its hosts, unfiled', () async {
      await insertGroup('g1');
      await insertHost('h1', group: 'g1');

      await db.delete('host_groups', where: "id = 'g1'");

      final row = (await db.query('hosts', where: "id = 'h1'")).single;
      expect(
        row['group_id'],
        isNull,
        reason: 'deleting a folder must never delete the servers in it',
      );
    });

    test('deleting a group that still has subgroups is refused', () async {
      await insertGroup('parent');
      await insertGroup('child', parent: 'parent');

      await expectLater(
        db.delete('host_groups', where: "id = 'parent'"),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('deleting a host removes its tunnels', () async {
      await insertHost('h1');
      await db.insert('tunnels', {
        'id': 'tn1',
        'host_id': 'h1',
        'label': 'db',
        'kind': 'local',
        'listen_port': 5432,
        'created_at': t,
        'updated_at': t,
      });

      await db.delete('hosts', where: "id = 'h1'");

      expect(
        await db.query('tunnels'),
        isEmpty,
        reason: 'a forward to a host that no longer exists is unusable',
      );
    });

    test('deleting a host still used as a jump host is refused', () async {
      await insertHost('bastion');
      await insertHost('db', jump: 'bastion');

      await expectLater(
        db.delete('hosts', where: "id = 'bastion'"),
        throwsA(isA<DatabaseException>()),
        // Silently allowing it breaks every host behind the bastion, and only
        // at connect time — long after the delete that caused it.
      );
    });

    test(
      'an identity can be deleted; hosts using it fall back to no key',
      () async {
        await db.insert('identities', {
          'id': 'k1',
          'label': 'laptop',
          'key_type': 'ssh-ed25519',
          'created_at': t,
          'updated_at': t,
        });
        await db.insert('hosts', {
          'id': 'h1',
          'label': 'h1',
          'hostname': 'h1.example.com',
          'username': 'root',
          'identity_id': 'k1',
          'created_at': t,
          'updated_at': t,
        });

        await db.delete('identities', where: "id = 'k1'");

        final row = (await db.query('hosts', where: "id = 'h1'")).single;
        expect(row['identity_id'], isNull);
      },
    );
  });

  group('known_hosts', () {
    test(
      'is keyed by address, so re-trusting replaces rather than duplicates',
      () async {
        Future<void> trust(String fingerprint) => db.insert('known_hosts', {
          'hostname': 'example.com',
          'port': 22,
          'key_type': 'ssh-ed25519',
          'fingerprint': fingerprint,
          'trusted_at': t,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await trust('SHA256:one');
        await trust('SHA256:two');

        final rows = await db.query('known_hosts');
        expect(rows, hasLength(1));
        expect(rows.single['fingerprint'], 'SHA256:two');
      },
    );

    test('the same hostname on another port is a separate identity', () async {
      for (final port in [22, 2222]) {
        await db.insert('known_hosts', {
          'hostname': 'example.com',
          'port': port,
          'key_type': 'ssh-ed25519',
          'fingerprint': 'SHA256:port$port',
          'trusted_at': t,
        });
      }
      expect(await db.query('known_hosts'), hasLength(2));
    });

    test('carries no column that could hold key material', () async {
      final columns = await db.rawQuery('PRAGMA table_info(known_hosts)');
      final names = columns.map((c) => c['name']! as String).toSet();

      // The fingerprint is enough to detect a substituted key. Storing the key
      // itself would put a secret-adjacent blob in an unencrypted, backed-up
      // file for no gain.
      expect(names, {
        'hostname',
        'port',
        'key_type',
        'fingerprint',
        'trusted_at',
      });
    });
  });

  group('v5 — snippets', () {
    test('a snippet needs only an id, a label, a body and times', () async {
      await db.insert('snippets', {
        'id': 's1',
        'label': 'uptime',
        'body': 'uptime',
        'created_at': t,
        'updated_at': t,
      });
      final row = (await db.query('snippets')).single;
      expect(row['sort_order'], 0);
      expect(row['description'], isNull);
      expect(row['tags'], isNull);
      expect(row['deleted_at'], isNull);
    });

    test('label and body are required', () async {
      expect(
        () => db.insert('snippets', {
          'id': 's1',
          'body': 'uptime',
          'created_at': t,
          'updated_at': t,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('snippets', {
          'id': 's2',
          'label': 'uptime',
          'created_at': t,
          'updated_at': t,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('carries the tombstone column the other tables do', () async {
      final columns = (await db.rawQuery('PRAGMA table_info(snippets)'))
          .map((c) => c['name'])
          .toSet();
      expect(
        columns,
        containsAll({'id', 'label', 'body', 'deleted_at', 'sort_order'}),
      );
    });

    test('upgrading a v4 database adds it and keeps what was there', () async {
      // The path every existing install takes: v1–v4 already applied, then
      // only v5 on the next launch.
      // A separate instance: sqflite hands every open of the same path the
      // same database, and `db` is already fully migrated.
      final old = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(old.close);
      await old.execute('PRAGMA foreign_keys = ON');
      Future<String> load(String path) async => File(path).readAsString();
      for (final migration in migrations.take(4)) {
        await migration.run(old, load);
      }
      await old.insert('hosts', {
        'id': 'h1',
        'label': 'h1',
        'hostname': 'h1.example.com',
        'username': 'root',
        'created_at': t,
        'updated_at': t,
      });

      await migrations[4].run(old, load);

      expect(await old.query('hosts'), hasLength(1));
      expect(await old.query('snippets'), isEmpty);
    });
  });

  group('v6 — host environment variables', () {
    test('a host without variables has NULL, not a default', () async {
      await insertHost('h1');
      final row = (await db.query('hosts')).single;
      expect(row.containsKey('env_vars'), isTrue);
      expect(row['forward_agent'], 0, reason: 'agent forwarding is off');
    });

    test('forward_agent is required, so it can never be NULL', () async {
      expect(
        () => db.insert('hosts', {
          'id': 'h1',
          'label': 'h1',
          'hostname': 'h1.example.com',
          'username': 'root',
          'forward_agent': null,
          'created_at': t,
          'updated_at': t,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('upgrading a v5 database keeps every host', () async {
      final old = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(old.close);
      await old.execute('PRAGMA foreign_keys = ON');
      Future<String> load(String path) async => File(path).readAsString();
      for (final migration in migrations.take(5)) {
        await migration.run(old, load);
      }
      await old.insert('hosts', {
        'id': 'h1',
        'label': 'h1',
        'hostname': 'h1.example.com',
        'username': 'root',
        'startup_command': 'tmux a',
        'created_at': t,
        'updated_at': t,
      });

      await migrations[5].run(old, load);

      final row = (await old.query('hosts')).single;
      expect(row['startup_command'], 'tmux a');
      expect(row['env_vars'], isNull);
      expect(row['forward_agent'], 0);
      await old.update('hosts', {'env_vars': '{"A":"1"}'});
      expect((await old.query('hosts')).single['env_vars'], '{"A":"1"}');
    });
  });

  group('v7 — per-host tmux choice', () {
    test('a host without a choice has NULL: follow the setting', () async {
      await insertHost('h1');
      final row = (await db.query('hosts')).single;
      expect(row.containsKey('tmux_mode'), isTrue);
      expect(row['tmux_mode'], isNull);
    });

    test('always and never are stored as written', () async {
      await insertHost('h1');
      await insertHost('h2');
      await db.update('hosts', {'tmux_mode': 'always'}, where: "id = 'h1'");
      await db.update('hosts', {'tmux_mode': 'never'}, where: "id = 'h2'");
      final rows = await db.query('hosts', orderBy: 'id');
      expect(rows.map((r) => r['tmux_mode']), ['always', 'never']);
    });

    test('upgrading a v6 database keeps every host and its columns', () async {
      final old = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(old.close);
      await old.execute('PRAGMA foreign_keys = ON');
      Future<String> load(String path) async => File(path).readAsString();
      for (final migration in migrations.take(6)) {
        await migration.run(old, load);
      }
      await old.insert('hosts', {
        'id': 'h1',
        'label': 'h1',
        'hostname': 'h1.example.com',
        'username': 'root',
        'env_vars': '{"A":"1"}',
        'forward_agent': 1,
        'created_at': t,
        'updated_at': t,
      });

      await migrations[6].run(old, load);

      final row = (await old.query('hosts')).single;
      expect(row['env_vars'], '{"A":"1"}');
      expect(row['forward_agent'], 1);
      expect(row['tmux_mode'], isNull);
      await old.update('hosts', {'tmux_mode': 'never'});
      expect((await old.query('hosts')).single['tmux_mode'], 'never');
    });

    test('is the latest schema', () {
      expect(kSchemaVersion, 7);
      expect(migrations, hasLength(7));
    });
  });

  group('no table stores a secret', () {
    test('no column is named like a credential', () async {
      final tables = (await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
      )).map((r) => r['name']! as String);

      // A guard against the easy mistake: adding `password` to `hosts`
      // "just for now". Secrets belong in the SecretVault, never here — this
      // file is unencrypted and goes into device backups.
      const forbidden = {
        'password',
        'passphrase',
        'private_key',
        'secret',
        'token',
      };

      for (final table in tables) {
        final columns = await db.rawQuery('PRAGMA table_info($table)');
        for (final column in columns) {
          expect(
            forbidden,
            isNot(contains(column['name'])),
            reason:
                '$table.${column['name']} looks like a credential; '
                'secrets belong in the SecretVault',
          );
        }
      }
    });
  });
}
