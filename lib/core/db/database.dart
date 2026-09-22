import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
// Re-exports everything sqflite does, plus the FFI factory desktop needs, so
// importing both would be redundant.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/app_config.dart';
import 'migrations/migrations.dart';

/// The open database. Installed by bootstrap; reading it without that override
/// is a programming error.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError(
    'databaseProvider was read before bootstrap installed it',
  ),
);

/// The local SQLite database.
///
/// Migrations are numbered SQL files under `migrations/`, applied in order and
/// each at most once. See [kSchemaVersion].
class AppDatabase {
  AppDatabase._(this.raw);

  final Database raw;

  /// Open the database, creating and migrating it as needed.
  static Future<AppDatabase> open({String? path}) async {
    // Desktop has no bundled SQLite; the FFI implementation supplies one.
    // Harmless on mobile, but only registered where it is needed.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Release: <documents>/sshetu.db, where it has always been. Debug: its
    // own file in its own folder. See AppIdentity.databasePath.
    final resolved =
        path ??
        await AppIdentity.current.databasePath(
          documentsDirectory: () async =>
              (await getApplicationDocumentsDirectory()).path,
          supportDirectory: () async =>
              (await getApplicationSupportDirectory()).path,
        );

    final database = await openDatabase(
      resolved,
      version: kSchemaVersion,
      onConfigure: (db) async {
        // Off by default in SQLite, and every schema here relies on it.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: _migrate,
    );

    return AppDatabase._(database);
  }

  /// Apply every migration between [from] and [to].
  ///
  /// Index N takes the schema from version N to N+1, so a fresh install runs
  /// all of them and an upgrade runs only the tail. Creating from the same
  /// list an upgrade uses means the two paths cannot drift apart — the usual
  /// way a schema ends up subtly different on new devices than on old ones.
  static Future<void> _migrate(Database db, int from, int to) async {
    for (var version = from; version < to; version++) {
      await migrations[version].run(db, _loadSql);
    }
  }

  static Future<String> _loadSql(String assetPath) =>
      rootBundle.loadString(assetPath);

  Future<void> close() => raw.close();
}
