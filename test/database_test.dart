import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/db/migrations/migrations.dart';

/// Proves the migrations actually apply.
///
/// This runs against a real in-memory SQLite through the FFI factory, so it
/// exercises the same statement splitting and the same DDL the device does.
/// Analysis cannot see any of this: a malformed migration is a perfectly
/// valid Dart string right up until SQLite rejects it at first launch.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openMigrated() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    for (final migration in migrations) {
      await migration.run(db, (path) async => File(path).readAsString());
    }
    return db;
  }

  test('every migration applies to a fresh database', () async {
    final db = await openMigrated();
    addTearDown(db.close);

    // If the schema version says N, there had better be N migrations to run.
    expect(migrations.length, kSchemaVersion);
  });

  test('the schema is queryable once migrated', () async {
    final db = await openMigrated();
    addTearDown(db.close);

    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    expect(tables, isNotEmpty, reason: 'migrations created no tables');
  });

  group('splitSqlStatements', () {
    test('splits on statement boundaries', () {
      expect(splitSqlStatements('SELECT 1; SELECT 2;'), [
        'SELECT 1',
        'SELECT 2',
      ]);
    });

    test('ignores a semicolon inside a line comment', () {
      // The bug this test exists for: a `;` in prose used to cut the script
      // mid-comment, and the next "statement" began with the rest of the
      // sentence. It failed only on a device, at first launch.
      const script = '''
-- keep this; and this
CREATE TABLE a (id TEXT);
''';
      expect(splitSqlStatements(script), ['CREATE TABLE a (id TEXT)']);
    });

    test('ignores a semicolon inside a block comment', () {
      expect(splitSqlStatements('/* one; two */ SELECT 1;'), ['SELECT 1']);
    });

    test('ignores a semicolon inside a string literal', () {
      expect(splitSqlStatements("INSERT INTO a VALUES ('x;y');"), [
        "INSERT INTO a VALUES ('x;y')",
      ]);
    });

    test('handles an escaped quote inside a string literal', () {
      expect(splitSqlStatements("INSERT INTO a VALUES ('it''s; fine');"), [
        "INSERT INTO a VALUES ('it''s; fine')",
      ]);
    });

    test('drops comment-only and empty fragments', () {
      // A comment-only fragment reaching db.execute is SQLITE_MISUSE.
      expect(splitSqlStatements('-- nothing here\n\n;;'), isEmpty);
    });

    test('keeps a trailing statement with no semicolon', () {
      expect(splitSqlStatements('SELECT 1'), ['SELECT 1']);
    });
  });

  group('the rename from ssh_navigator to SSHetu', () {
    // The database file is named after the app, so renaming the app renames
    // the file. To a user that reads as "every host I imported is gone" —
    // while the rows sit on disk under a name nothing opens any more.
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('sshetu-rename'));
    tearDown(() => dir.deleteSync(recursive: true));

    String pathTo(String name) => '${dir.path}/$name';

    test('adopts the old file, and its journal', () async {
      final legacy = File(pathTo(AppDatabase.legacyFileName))
        ..writeAsStringSync('old-database');
      File('${legacy.path}-journal').writeAsStringSync('old-journal');

      await AppDatabase.adoptLegacyFile(pathTo(AppDatabase.fileName));

      expect(legacy.existsSync(), isFalse, reason: 'moved, not copied');
      expect(
        File(pathTo(AppDatabase.fileName)).readAsStringSync(),
        'old-database',
      );
      expect(
        File(pathTo('${AppDatabase.fileName}-journal')).readAsStringSync(),
        'old-journal',
        reason: 'a journal left beside the old name is worse than none',
      );
    });

    test('leaves an existing database alone', () async {
      // Both files present means the app has already run under the new name.
      // Adopting the old one here would silently roll the user back.
      File(pathTo(AppDatabase.fileName)).writeAsStringSync('current');
      File(pathTo(AppDatabase.legacyFileName)).writeAsStringSync('stale');

      await AppDatabase.adoptLegacyFile(pathTo(AppDatabase.fileName));

      expect(File(pathTo(AppDatabase.fileName)).readAsStringSync(), 'current');
      expect(
        File(pathTo(AppDatabase.legacyFileName)).existsSync(),
        isTrue,
        reason: 'left where it was, not merged and not deleted',
      );
    });

    test('a fresh install with neither file is not an error', () async {
      await AppDatabase.adoptLegacyFile(pathTo(AppDatabase.fileName));
      expect(File(pathTo(AppDatabase.fileName)).existsSync(), isFalse);
    });
  });
}
