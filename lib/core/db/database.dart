import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// Re-exports everything sqflite does, plus the FFI factory desktop needs, so
// importing both would be redundant.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  static const String fileName = 'sshetu.db';

  /// What the file was called before the app was named.
  ///
  /// Kept only so that renaming the product does not throw away the hosts
  /// someone already imported. Nothing else refers to it, and it can go once
  /// no installed copy predates the rename — which, for an unreleased app,
  /// means whenever the last developer device has been through this once.
  static const String legacyFileName = 'ssh_navigator.db';

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

    final resolved =
        path ??
        p.join((await getApplicationDocumentsDirectory()).path, fileName);

    await adoptLegacyFile(resolved);

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

  /// Moves a pre-rename database into place, if one is there and nothing is.
  ///
  /// The app changed name, and the file is named after the app. Without this
  /// the rename reads to the user as "every host I imported is gone" — the
  /// data is still on disk, under a name nothing opens any more.
  ///
  /// Worth being clear about the limit: this only helps where the *directory*
  /// survived the rename. On Android, iOS and a sandboxed macOS build the
  /// data directory is derived from the application id, which changed too, so
  /// the old file is in a container this process cannot see and a fresh start
  /// is the only outcome available. On Linux and Windows, where the path is
  /// the user's own documents folder, this is the difference between keeping
  /// their hosts and losing them.
  ///
  /// Best effort by design: a failure here means starting empty, which is
  /// recoverable, whereas refusing to open the database at all is not. The
  /// journal and WAL siblings move too, because leaving a journal beside a
  /// database it no longer belongs to is worse than having neither.
  @visibleForTesting
  static Future<void> adoptLegacyFile(String resolved) async {
    try {
      if (await File(resolved).exists()) return;

      final legacy = p.join(p.dirname(resolved), legacyFileName);
      if (!await File(legacy).exists()) return;

      await File(legacy).rename(resolved);
      for (final suffix in const ['-journal', '-wal', '-shm']) {
        final sibling = File('$legacy$suffix');
        if (await sibling.exists()) {
          await sibling.rename('$resolved$suffix');
        }
      }
    } on Object {
      // Nothing to do but start fresh.
    }
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
