import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ssh_navigator/core/db/migrations/migrations.dart';

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
}
