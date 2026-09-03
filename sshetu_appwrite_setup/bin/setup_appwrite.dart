// Creates the Appwrite schema SSHetu expects, from docs/appwrite-schema.md.
//
//   cp .env.example .env      # then fill in APPWRITE_API_KEY
//   dart pub get
//   dart run bin/setup_appwrite.dart            # create or repair
//   dart run bin/setup_appwrite.dart --check     # report drift, write nothing
//
// Flags beat .env when both are set. Nothing here is destructive: every
// operation either creates something missing or reports a 409 and moves on,
// so running it against a project that is already correct does nothing and
// running it against a half-built one finishes the job.
//
// Deliberately a separate package. The app must never depend on the server
// SDK, and a server API key must never be reachable from anything that ships
// to a device — which is also why the app itself provisions nothing.

import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/enums.dart' show TablesDBIndexType;
import 'package:dotenv/dotenv.dart';

/// One column, in the shape the schema doc describes it.
class Column {
  const Column.string(
    this.key, {
    required this.size,
    this.required = false,
    this.encrypt = false,
  }) : type = 'string';

  const Column.integer(this.key, {this.required = false})
    : type = 'integer',
      size = null,
      encrypt = false;

  const Column.float(this.key, {this.required = false})
    : type = 'float',
      size = null,
      encrypt = false;

  final String key;
  final String type;
  final int? size;
  final bool required;

  /// Only ever true for `secrets.value`. See the schema doc's note on what
  /// `encrypt` does and does not protect against.
  final bool encrypt;
}

class Table {
  const Table(this.id, this.columns, {this.indexUpdatedAt = true});

  final String id;
  final List<Column> columns;

  /// A `key` index on `updated_at`, which is the pull cursor's ordering. The
  /// secrets table has no `updated_at` and no cursor, so it has no index.
  final bool indexUpdatedAt;
}

/// Present on every synced table, and identical everywhere — the sync engine
/// reads them generically (see `lib/core/sync/sync_table_spec.dart`).
///
/// `updated_at` is the last-writer-wins field and the pull cursor;
/// `deleted_at` is the tombstone. `user_id` is never queried at runtime —
/// row permissions already scope reads — and exists so ownership can be read
/// off the console without cross-referencing permissions.
const _syncColumns = [
  Column.integer('created_at', required: true),
  Column.integer('updated_at', required: true),
  Column.integer('deleted_at'),
  Column.string('user_id', size: 36, required: true),
];

/// Required columns carry no server-side default on purpose.
///
/// Appwrite rejects a column that is both required and defaulted, and the app
/// always writes these values explicitly — the defaults in `v1_initial.sql`
/// (`port` 22, `keepalive_seconds` 30, `listen_host` 127.0.0.1) are there for
/// hand-written local SQL, not for anything that ever reaches the backend.
const _tables = [
  Table('host_groups', [
    Column.string('name', size: 200, required: true),
    Column.string('parent_id', size: 36),
    Column.integer('sort_order', required: true),
    ..._syncColumns,
  ]),
  Table('identities', [
    Column.string('label', size: 200, required: true),
    Column.string('key_type', size: 40, required: true),
    // Public halves and fingerprints, which are not secret. The private key
    // never appears in this table — it lives in `secrets`, encrypted.
    Column.string('public_key', size: 4000),
    Column.string('fingerprint', size: 100),
    Column.integer('has_passphrase', required: true),
    Column.string('origin', size: 20, required: true),
    ..._syncColumns,
  ]),
  Table('hosts', [
    Column.string('group_id', size: 36),
    Column.string('label', size: 200, required: true),
    Column.string('hostname', size: 255, required: true),
    Column.integer('port', required: true),
    Column.string('username', size: 100, required: true),
    Column.string('auth_method', size: 20, required: true),
    Column.string('identity_id', size: 36),
    // Points at another row in this same table, which is why the engine
    // writes hosts in two passes — see SyncTableSpec.deferredForeignKeys.
    Column.string('jump_host_id', size: 36),
    Column.integer('allow_legacy_algorithms', required: true),
    Column.string('startup_command', size: 500),
    Column.integer('keepalive_seconds', required: true),
    Column.string('terminal_theme', size: 100),
    Column.float('font_size'),
    Column.string('notes', size: 2000),
    Column.string('tags', size: 500),
    ..._syncColumns,
  ]),
  Table('tunnels', [
    Column.string('host_id', size: 36, required: true),
    Column.string('label', size: 200, required: true),
    Column.string('kind', size: 20, required: true),
    Column.string('listen_host', size: 100, required: true),
    Column.integer('listen_port', required: true),
    Column.string('target_host', size: 255),
    Column.integer('target_port'),
    Column.integer('auto_start', required: true),
    ..._syncColumns,
  ]),
  // Not a synced table: a different write pattern entirely (get/set by id, no
  // cursor, no last-writer-wins), and the one place this schema holds
  // something genuinely secret.
  Table('secrets', [
    Column.string('value', size: 65535, required: true, encrypt: true),
    Column.string('owner_id', size: 36, required: true),
    Column.string('kind', size: 20, required: true),
    Column.string('user_id', size: 36, required: true),
  ], indexUpdatedAt: false),
];

/// Returning an int from `main` does **not** set the process exit code in
/// Dart — it is silently ignored, and this script exited 0 while printing
/// "missing API key". Anything chaining it with `&&`, or a CI step, would have
/// read that as success. The code has to be assigned.
Future<void> main(List<String> argv) async {
  exitCode = await _run(argv);
}

Future<int> _run(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('env', defaultsTo: '.env', help: 'Path to a .env file')
    ..addOption('endpoint', help: 'Appwrite endpoint (or APPWRITE_ENDPOINT)')
    ..addOption('project', help: 'Project id (or APPWRITE_PROJECT)')
    ..addOption('database', help: 'Database id (or APPWRITE_DATABASE)')
    ..addOption('api-key', help: 'Server API key (or APPWRITE_API_KEY)')
    ..addFlag(
      'check',
      negatable: false,
      help: 'Report what is missing and write nothing.',
    );

  final args = parser.parse(argv);
  final env = DotEnv(includePlatformEnvironment: true);
  final envPath = args['env'] as String;
  if (File(envPath).existsSync()) env.load([envPath]);

  String? pick(String flag, String key, [String? fallback]) {
    final value = args[flag] as String?;
    if (value != null && value.isNotEmpty) return value;
    final fromEnv = env[key];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return fallback;
  }

  final endpoint = pick(
    'endpoint',
    'APPWRITE_ENDPOINT',
    'https://cloud.appwrite.io/v1',
  )!;
  final project = pick('project', 'APPWRITE_PROJECT', 'sshetu')!;
  final databaseId = pick('database', 'APPWRITE_DATABASE', 'sshetu')!;
  final apiKey = pick('api-key', 'APPWRITE_API_KEY');
  final check = args['check'] as bool;

  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Missing API key: set APPWRITE_API_KEY or pass --api-key.');
    stderr.writeln(
      'It needs databases.read and databases.write, nothing more.',
    );
    stderr.writeln();
    stderr.writeln(parser.usage);
    return 64;
  }

  final client = Client()
      .setEndpoint(endpoint)
      .setProject(project)
      .setKey(apiKey);
  final tables = TablesDB(client);

  stdout.writeln('${check ? 'Checking' : 'Provisioning'} $project/$databaseId');
  stdout.writeln('  at $endpoint');
  stdout.writeln();

  try {
    if (check) {
      return await _check(tables, databaseId);
    }
    await _provision(tables, databaseId);
    stdout.writeln();
    stdout.writeln('Done. Point the app at it with:');
    stdout.writeln(
      '  flutter run --dart-define=APPWRITE_PROJECT=$project '
      '--dart-define=APPWRITE_DATABASE=$databaseId',
    );
    return 0;
  } on AppwriteException catch (e) {
    stderr.writeln('Appwrite refused: ${e.code} ${e.message}');
    // 401 is the one people hit: a key with the wrong scopes reads exactly
    // like a wrong key.
    if (e.code == 401) {
      stderr.writeln('Check the key has databases.read and databases.write.');
    }
    return 1;
  }
}

Future<void> _provision(TablesDB tables, String databaseId) async {
  await _ignoreConflict(
    () => tables.create(databaseId: databaseId, name: databaseId),
    onExists: () => stdout.writeln('database $databaseId — already there'),
    onCreated: () => stdout.writeln('database $databaseId — created'),
  );

  for (final table in _tables) {
    await _ignoreConflict(
      () => tables.createTable(
        databaseId: databaseId,
        tableId: table.id,
        name: table.id,
        // Row-level permissions are the whole security model here: a row is
        // readable only by its owner. `create` for signed-in users is the
        // only table-level grant, so nobody can list anyone else's rows.
        rowSecurity: true,
        permissions: [Permission.create(Role.users())],
      ),
      onExists: () => stdout.writeln('table ${table.id} — already there'),
      onCreated: () => stdout.writeln('table ${table.id} — created'),
    );

    for (final column in table.columns) {
      await _ignoreConflict(
        () => _createColumn(tables, databaseId, table.id, column),
        onExists: () {},
        onCreated: () => stdout.writeln(
          '  + ${column.key}'
          '${column.encrypt ? '  (encrypted at rest)' : ''}',
        ),
      );
    }

    // Columns are created asynchronously server-side; an index on one that is
    // still `processing` fails.
    await _waitForColumns(tables, databaseId, table.id);

    if (table.indexUpdatedAt) {
      await _ignoreConflict(
        () => tables.createIndex(
          databaseId: databaseId,
          tableId: table.id,
          key: 'updated_at',
          type: TablesDBIndexType.key,
          columns: ['updated_at'],
        ),
        onExists: () {},
        onCreated: () => stdout.writeln('  + index on updated_at'),
      );
    }
  }
}

/// Reports what is missing without writing anything.
///
/// Exists because the failure this script prevents is a *partially* created
/// schema — a table whose one missing column makes every push fail with a
/// message about that column and nothing about the cause.
Future<int> _check(TablesDB tables, String databaseId) async {
  var missing = 0;

  for (final table in _tables) {
    final List<dynamic> existing;
    try {
      final list = await tables.listColumns(
        databaseId: databaseId,
        tableId: table.id,
      );
      existing = list.columns;
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      stdout.writeln('table ${table.id} — MISSING');
      missing += table.columns.length + 1;
      continue;
    }

    final present = existing
        .map(
          (c) => c is Map
              ? (Map<String, dynamic>.from(c)['key'] as String?)
              : null,
        )
        .whereType<String>()
        .toSet();

    final absent = table.columns
        .map((c) => c.key)
        .where((k) => !present.contains(k))
        .toList();

    if (absent.isEmpty) {
      stdout.writeln('table ${table.id} — complete');
    } else {
      stdout.writeln('table ${table.id} — missing ${absent.join(', ')}');
      missing += absent.length;
    }
  }

  stdout.writeln();
  if (missing == 0) {
    stdout.writeln('Schema matches docs/appwrite-schema.md.');
    return 0;
  }
  stdout.writeln('$missing thing(s) missing. Re-run without --check to fix.');
  return 1;
}

Future<void> _createColumn(
  TablesDB tables,
  String databaseId,
  String tableId,
  Column column,
) => switch (column.type) {
  // `createStringColumn` is deprecated in favour of `createTextColumn`,
  // which takes no `size`. The sizes here are part of the documented schema
  // (docs/appwrite-schema.md) and they matter: a column's width is what
  // decides whether an index over it is allowed. Keeping the sized call is a
  // choice, not an oversight.
  // ignore: deprecated_member_use
  'string' => tables.createStringColumn(
    databaseId: databaseId,
    tableId: tableId,
    key: column.key,
    size: column.size!,
    xrequired: column.required,
    encrypt: column.encrypt ? true : null,
  ),
  'integer' => tables.createIntegerColumn(
    databaseId: databaseId,
    tableId: tableId,
    key: column.key,
    xrequired: column.required,
  ),
  'float' => tables.createFloatColumn(
    databaseId: databaseId,
    tableId: tableId,
    key: column.key,
    xrequired: column.required,
  ),
  _ => throw StateError('unknown column type ${column.type}'),
};

/// Runs an idempotent create, treating "it already exists" as success.
Future<void> _ignoreConflict(
  Future<void> Function() operation, {
  required void Function() onExists,
  required void Function() onCreated,
}) async {
  try {
    await operation();
    onCreated();
  } on AppwriteException catch (e) {
    if (e.code != 409) rethrow;
    onExists();
  }
}

Future<void> _waitForColumns(
  TablesDB tables,
  String databaseId,
  String tableId,
) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    final list = await tables.listColumns(
      databaseId: databaseId,
      tableId: tableId,
    );
    final ready = list.columns.every((c) {
      final map = c is Map ? Map<String, dynamic>.from(c) : const {};
      return (map['status'] as String?) != 'processing';
    });
    if (ready) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  stdout.writeln('  ! columns on $tableId still processing; index may lag');
}
