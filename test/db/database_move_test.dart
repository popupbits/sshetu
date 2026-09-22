import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshetu/core/bootstrap.dart';
import 'package:sshetu/core/config/app_config.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/db/database_move.dart';

/// The one-time move of a desktop release's database out of the user's shared
/// Documents folder and into the app's own data folder.
///
/// Everything here runs against temp directories. The real user's files are
/// never named, let alone opened: every path the move sees is injected.
///
/// The legacy databases are real — built by the real migrations, holding real
/// rows — because the move's whole promise is that the rows arrive intact, and
/// a fake file cannot break that promise the way a real one can.
void main() {
  late Directory root;
  late Directory documents;
  late Directory support;
  late String legacyPath;
  late String targetPath;
  late SharedPreferences preferences;
  late List<Object> reported;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = Directory.systemTemp.createTempSync('sshetu-dbmove');
    documents = Directory(p.join(root.path, 'Documents'))..createSync();
    // Not created: the move must make the app's folder itself, as it would
    // on a machine that has never run the app.
    support = Directory(p.join(root.path, 'AppData', 'PopupBits', 'SSHetu'));
    legacyPath = p.join(documents.path, 'sshetu.db');
    targetPath = p.join(support.path, 'sshetu.db');
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    reported = [];
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a just-closed file for a moment; the OS reclaims it.
    }
  });

  DatabaseMove move({
    DatabaseFileCopier? copy,
    DatabaseFileRenamer? renameLegacy,
  }) => DatabaseMove(
    targetPath: targetPath,
    legacyPath: legacyPath,
    preferences: preferences,
    copy: copy,
    renameLegacy: renameLegacy,
    report: (error, stack) => reported.add(error),
  );

  const t = 1735689600000;

  /// A database at [path] built by the real migrations, with a row or more in
  /// every table the move counts.
  Future<void> seed(String path, {int hosts = 3}) async {
    final db = await AppDatabase.open(path: path);
    final raw = db.raw;
    await raw.insert('host_groups', {
      'id': 'g1',
      'name': 'Production',
      'created_at': t,
      'updated_at': t,
    });
    await raw.insert('identities', {
      'id': 'k1',
      'label': 'laptop',
      'key_type': 'ssh-ed25519',
      'created_at': t,
      'updated_at': t,
    });
    for (var i = 0; i < hosts; i++) {
      await raw.insert('hosts', {
        'id': 'h$i',
        'group_id': 'g1',
        'label': 'server $i',
        'hostname': 'h$i.example.com',
        'username': 'root',
        'identity_id': 'k1',
        'created_at': t,
        'updated_at': t,
      });
    }
    await raw.insert('tunnels', {
      'id': 't1',
      'host_id': 'h0',
      'label': 'db',
      'kind': 'local',
      'listen_port': 5432,
      'created_at': t,
      'updated_at': t,
    });
    await raw.insert('snippets', {
      'id': 's1',
      'label': 'disk',
      'body': 'df -h',
      'created_at': t,
      'updated_at': t,
    });
    await raw.insert('known_hosts', {
      'hostname': 'h0.example.com',
      'port': 22,
      'key_type': 'ssh-ed25519',
      'fingerprint': 'SHA256:abc',
      'trusted_at': t,
    });
    await db.close();
  }

  /// Every row of every table the move counts, read without writing.
  Future<Map<String, List<Map<String, Object?>>>> dump(String path) async {
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      return {
        for (final table in DatabaseMove.countedTables)
          table: await db.query(table, orderBy: 'rowid'),
      };
    } finally {
      await db.close();
    }
  }

  Set<String> namesIn(String directory) => Directory(directory).existsSync()
      ? Directory(directory).listSync().map((e) => p.basename(e.path)).toSet()
      : <String>{};

  group('fresh install', () {
    test('nothing anywhere: the database is made in the app folder', () async {
      final location = await move().run();

      expect(location.path, targetPath);
      expect(location.outcome, DatabaseMoveOutcome.fresh);
      expect(support.existsSync(), isTrue, reason: 'folder made for it');
      expect(namesIn(documents.path), isEmpty);
      expect(preferences.getString(DatabaseMove.migratedFromKey), isNull);
      expect(preferences.getString(DatabaseMove.migratedAtKey), isNull);
      expect(reported, isEmpty);

      // And it opens: a fresh database with the real schema.
      final db = await AppDatabase.open(path: location.path);
      expect(await db.raw.query('hosts'), isEmpty);
      await db.close();
    });
  });

  group('an existing install in Documents', () {
    test('is copied, verified, and the original kept as .moved', () async {
      await seed(legacyPath);
      final before = await dump(legacyPath);

      final location = await move().run();

      expect(location.outcome, DatabaseMoveOutcome.moved);
      expect(location.path, targetPath);
      expect(await dump(targetPath), before, reason: 'identical rows');

      // Never deleted — renamed beside where it was, as the way back.
      expect(File(legacyPath).existsSync(), isFalse);
      expect(File('$legacyPath.moved').existsSync(), isTrue);
      expect(await dump('$legacyPath.moved'), before);

      // Only the database in the app folder: no temp copy left behind.
      expect(namesIn(support.path), {'sshetu.db'});

      expect(preferences.getString(DatabaseMove.migratedFromKey), legacyPath);
      expect(
        DateTime.tryParse(preferences.getString(DatabaseMove.migratedAtKey)!),
        isNotNull,
      );
      expect(reported, isEmpty);

      // The app opens it and finds everything, schema version and all.
      final db = await AppDatabase.open(path: location.path);
      expect(await db.raw.query('hosts'), hasLength(3));
      await db.close();
    });

    test('with uncheckpointed writes in its -wal: nothing is lost', () async {
      // A crash in WAL mode leaves committed rows only in the -wal file.
      // Build exactly that: a checkpointed base, then rows that never
      // reached the main file, snapshotted while the connection is open.
      final source = p.join(root.path, 'live.db');
      await seed(source, hosts: 1);
      final live = await databaseFactoryFfi.openDatabase(
        source,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await live.rawQuery('PRAGMA journal_mode = WAL');
      await live.rawQuery('PRAGMA wal_autocheckpoint = 0');
      await live.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      for (var i = 10; i < 15; i++) {
        await live.insert('hosts', {
          'id': 'w$i',
          'label': 'wal $i',
          'hostname': 'w$i.example.com',
          'username': 'root',
          'created_at': t,
          'updated_at': t,
        });
      }
      File(source).copySync(legacyPath);
      File('$source-wal').copySync('$legacyPath-wal');
      await live.close();

      expect(File('$legacyPath-wal').lengthSync(), greaterThan(0));
      // Proof the -wal matters: the main file alone is missing the rows.
      final mainOnly = p.join(root.path, 'main-only.db');
      File(legacyPath).copySync(mainOnly);
      expect((await dump(mainOnly))['hosts'], hasLength(1));

      final location = await move().run();

      expect(location.outcome, DatabaseMoveOutcome.moved);
      final db = await AppDatabase.open(path: location.path);
      expect(await db.raw.query('hosts'), hasLength(6));
      await db.close();
      // The sidecar went with its database, and nothing stayed behind.
      expect(File(legacyPath).existsSync(), isFalse);
      expect(File('$legacyPath-wal').existsSync(), isFalse);
      expect(File('$legacyPath.moved').existsSync(), isTrue);
    });
  });

  group('never over newer data', () {
    test('both exist: the app folder wins, both left untouched', () async {
      support.createSync(recursive: true);
      await seed(targetPath, hosts: 5);
      await seed(legacyPath, hosts: 2);
      final target = await dump(targetPath);
      final legacy = await dump(legacyPath);

      final location = await move().run();

      expect(location.path, targetPath);
      expect(location.outcome, DatabaseMoveOutcome.alreadyMoved);
      expect(await dump(targetPath), target);
      expect(await dump(legacyPath), legacy);
      expect(File('$legacyPath.moved').existsSync(), isFalse);

      // Said once, so someone reading Diagnostics knows it is there…
      expect(reported, hasLength(1));
      expect(reported.single, isA<DatabaseMoveNotice>());
      // …and not every launch after.
      await move().run();
      expect(reported, hasLength(1));
    });

    test(
      'moved before, and the old file comes back: not re-imported',
      () async {
        await seed(legacyPath, hosts: 2);
        await move().run();

        // The user edits the moved database…
        final db = await AppDatabase.open(path: targetPath);
        await db.raw.delete('tunnels');
        await db.raw.delete('hosts');
        await db.close();
        final newer = await dump(targetPath);

        // …then restores an old copy into Documents, from OneDrive say.
        await seed(legacyPath, hosts: 4);

        final location = await move().run();

        expect(location.path, targetPath);
        expect(await dump(targetPath), newer);
        expect(File(legacyPath).existsSync(), isTrue, reason: 'left alone');
        expect(reported, isEmpty, reason: 'expected after a move, not news');
      },
    );

    test('moved before, and the moved database vanished: the Documents copy '
        'is brought over again rather than starting empty', () async {
      await seed(legacyPath, hosts: 2);
      await move().run();
      File(targetPath).deleteSync();
      await seed(legacyPath, hosts: 4);

      final location = await move().run();

      expect(location.outcome, DatabaseMoveOutcome.moved);
      expect((await dump(targetPath))['hosts'], hasLength(4));
      // The first .moved backup is still there; the second got its own name.
      expect(File('$legacyPath.moved').existsSync(), isTrue);
      expect(
        namesIn(documents.path).where((n) => n.startsWith('sshetu.db.moved')),
        hasLength(2),
      );
    });
  });

  group('a move that cannot be verified', () {
    Future<void> expectFellBack(DatabaseLocation location) async {
      expect(location.path, legacyPath, reason: 'the app still works');
      expect(location.outcome, DatabaseMoveOutcome.failedUsingLegacy);
      expect(File(legacyPath).existsSync(), isTrue);
      expect(File('$legacyPath.moved').existsSync(), isFalse);
      expect(File(targetPath).existsSync(), isFalse);
      expect(namesIn(support.path), isEmpty, reason: 'temp copy removed');
      expect(preferences.getString(DatabaseMove.migratedAtKey), isNull);
      expect(reported, hasLength(1));
    }

    test('a failing copy', () async {
      await seed(legacyPath);
      final before = await dump(legacyPath);

      await expectFellBack(
        await move(
          copy: (from, to) async => throw const FileSystemException('full'),
        ).run(),
      );
      expect(await dump(legacyPath), before);

      // Next launch, with a copy that works, it goes through.
      final retried = await move().run();
      expect(retried.outcome, DatabaseMoveOutcome.moved);
      expect(await dump(targetPath), before);
    });

    test('a truncated copy', () async {
      await seed(legacyPath);
      await expectFellBack(
        await move(
          copy: (from, to) async {
            final bytes = File(from).readAsBytesSync();
            File(to).writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
          },
        ).run(),
      );
    });

    test('a copy whose rows do not match', () async {
      await seed(legacyPath);
      await expectFellBack(
        await move(
          copy: (from, to) async {
            File(from).copySync(to);
            if (p.extension(to) == '.moving') {
              final db = await databaseFactoryFfi.openDatabase(
                to,
                options: OpenDatabaseOptions(singleInstance: false),
              );
              await db.delete('tunnels');
              await db.delete('hosts', where: "id = 'h2'");
              await db.close();
            }
          },
        ).run(),
      );
      expect(
        reported.single.toString(),
        contains('hosts: 2 rows in the copy, 3 in the original'),
        reason: 'the diagnostics say which table disagreed',
      );
    });

    test('a corrupt original: kept where it is, untouched', () async {
      File(legacyPath).writeAsStringSync('this is not a database' * 200);
      final bytes = File(legacyPath).readAsBytesSync();

      await expectFellBack(await move().run());
      expect(File(legacyPath).readAsBytesSync(), bytes);
    });
  });

  test('the original cannot be renamed (locked): the moved copy is used, and '
      'never copied over again', () async {
    await seed(legacyPath);
    final before = await dump(legacyPath);

    final location = await move(
      renameLegacy: (file, to) async =>
          throw FileSystemException('locked', file.path),
    ).run();

    expect(location.path, targetPath);
    expect(location.outcome, DatabaseMoveOutcome.movedLegacyKept);
    expect(await dump(targetPath), before);
    expect(File(legacyPath).existsSync(), isTrue);
    expect(preferences.getString(DatabaseMove.migratedAtKey), isNotNull);
    expect(reported, hasLength(1));

    // Newer data in the app folder, then another launch.
    final db = await AppDatabase.open(path: targetPath);
    await db.raw.delete('snippets');
    await db.close();
    final newer = await dump(targetPath);

    final again = await move().run();
    expect(again.path, targetPath);
    expect(await dump(targetPath), newer, reason: 'not copied over again');
  });

  group('locateDatabase — which builds move at all', () {
    Future<String> locate(AppIdentity identity, TargetPlatform platform) =>
        locateDatabase(
          identity: identity,
          platform: platform,
          preferences: preferences,
          documentsDirectory: () async => documents.path,
          supportDirectory: () async => support.path,
          report: (error, stack) => reported.add(error),
        );

    for (final platform in const [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      test(
        'release on ${platform.name}: stays in Documents, untouched',
        () async {
          await seed(legacyPath);
          final before = await dump(legacyPath);

          expect(await locate(AppIdentity.release, platform), legacyPath);
          expect(await dump(legacyPath), before);
          expect(support.existsSync(), isFalse);
          expect(preferences.getKeys(), isEmpty);
        },
      );
    }

    for (final platform in const [
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      test('release on ${platform.name}: moves to the app folder', () async {
        await seed(legacyPath);
        expect(await locate(AppIdentity.release, platform), targetPath);
        expect(File('$legacyPath.moved').existsSync(), isTrue);
      });
    }

    test("debug never moves — least of all the real app's database", () async {
      await seed(legacyPath);
      final before = await dump(legacyPath);

      for (final platform in TargetPlatform.values) {
        expect(
          await locate(AppIdentity.debug, platform),
          p.join(support.path, 'sshetu-debug.db'),
        );
      }
      expect(await dump(legacyPath), before);
      expect(File('$legacyPath.moved').existsSync(), isFalse);
      expect(preferences.getKeys(), isEmpty);
    });
  });

  test('bootstrap: the move finishes before the database is opened', () async {
    final events = <String>[];
    var moving = true;

    final opened = await openAppDatabase(
      locate: () async {
        events.add('move started');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        moving = false;
        events.add('move finished');
        return targetPath;
      },
      open: (path) async {
        expect(moving, isFalse, reason: 'opened mid-move');
        events.add('open $path');
        return AppDatabase.open(path: path);
      },
    );
    await opened.close();

    expect(events, ['move started', 'move finished', 'open $targetPath']);
  });
}
