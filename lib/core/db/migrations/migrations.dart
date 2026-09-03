import 'package:sqflite/sqflite.dart';

/// Current schema version. Bump this when you add a migration.
const int kSchemaVersion = 1;

/// One migration step.
///
/// SQL-only steps live in `lib/core/db/migrations/vN_*.sql` and are declared
/// with [SqlMigration]. A step that needs real logic — backfilling a column
/// from parsed data, say — uses [CodeMigration] instead, so Dart and SQL can
/// interleave in version order rather than one being forced through the other.
sealed class Migration {
  const Migration();

  Future<void> run(Database db, Future<String> Function(String) loadAsset);
}

class SqlMigration extends Migration {
  const SqlMigration(this.assetPath);

  final String assetPath;

  @override
  Future<void> run(
    Database db,
    Future<String> Function(String) loadAsset,
  ) async {
    final script = await loadAsset(assetPath);
    for (final statement in splitSqlStatements(script)) {
      await db.execute(statement);
    }
  }
}

class CodeMigration extends Migration {
  const CodeMigration(this.apply);

  final Future<void> Function(Database db) apply;

  @override
  Future<void> run(Database db, Future<String> Function(String) _) => apply(db);
}

/// Split a `.sql` file into statements `db.execute` will accept.
///
/// sqflite executes one statement per call, so a multi-statement file has to
/// be split. Splitting on `;` alone is wrong, and wrong in a way that only
/// shows up at runtime on a device: a semicolon inside a `-- comment` or a
/// string literal cuts the script mid-token and the next "statement" starts
/// with prose. Comments are stripped, quoted text is passed through
/// untouched, and empty fragments are dropped.
List<String> splitSqlStatements(String script) {
  final statements = <String>[];
  final current = StringBuffer();

  void flush() {
    final statement = current.toString().trim();
    if (statement.isNotEmpty) statements.add(statement);
    current.clear();
  }

  var i = 0;
  while (i < script.length) {
    final char = script[i];
    final next = i + 1 < script.length ? script[i + 1] : '';

    // -- line comment: drop through to the end of the line, but keep the
    // newline so tokens either side do not run together.
    if (char == '-' && next == '-') {
      while (i < script.length && script[i] != '\n') {
        i++;
      }
      current.write('\n');
      continue;
    }

    // /* block comment */
    if (char == '/' && next == '*') {
      i += 2;
      while (i < script.length &&
          !(script[i] == '*' &&
              i + 1 < script.length &&
              script[i + 1] == '/')) {
        i++;
      }
      i += 2;
      current.write(' ');
      continue;
    }

    // 'string literal', where '' is an escaped quote rather than the end.
    if (char == "'") {
      current.write(char);
      i++;
      while (i < script.length) {
        current.write(script[i]);
        if (script[i] == "'") {
          if (i + 1 < script.length && script[i + 1] == "'") {
            current.write(script[i + 1]);
            i += 2;
            continue;
          }
          i++;
          break;
        }
        i++;
      }
      continue;
    }

    if (char == ';') {
      flush();
      i++;
      continue;
    }

    current.write(char);
    i++;
  }

  flush();
  return statements;
}

/// Migrations in order. Index N takes the schema from version N to N+1.
const List<Migration> migrations = <Migration>[
  SqlMigration('lib/core/db/migrations/v1_initial.sql'),
];
