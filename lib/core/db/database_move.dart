import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/app_config.dart';
import '../error/error_logger.dart';

/// Copies one file to another. Replaced in tests to fail or to mangle.
typedef DatabaseFileCopier = Future<void> Function(String from, String to);

/// Renames one of the original database's files. Replaced in tests with one
/// that fails, as a file held open by OneDrive or an editor does.
typedef DatabaseFileRenamer = Future<void> Function(File file, String to);

/// Where the move reports what went wrong. [ErrorLogger] in the app.
typedef DatabaseMoveReporter = void Function(Object error, StackTrace? stack);

/// What [DatabaseMove.run] found and did.
enum DatabaseMoveOutcome {
  /// Nothing anywhere: a new install, made in the app folder.
  fresh,

  /// The app folder already holds the database. Nothing was touched.
  alreadyMoved,

  /// Copied, verified, and the original renamed to `sshetu.db.moved`.
  moved,

  /// Copied and verified, but the original could not be renamed — held open
  /// by another program, most likely. The moved copy is the database now.
  movedLegacyKept,

  /// The move failed before it took effect. The database is used where it
  /// is for this run, and the move is tried again next launch.
  failedUsingLegacy,
}

/// The database file to open, and how it came to be there.
class DatabaseLocation {
  const DatabaseLocation(this.path, this.outcome);

  final String path;
  final DatabaseMoveOutcome outcome;

  @override
  String toString() => 'DatabaseLocation($path, ${outcome.name})';
}

/// The move failed, or took effect only in part. Recorded in Diagnostics.
class DatabaseMoveException implements Exception {
  const DatabaseMoveException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseMoveException: $message';
}

/// Something about the move worth knowing that is not a failure — a second
/// copy left where it was. Recorded in Diagnostics, once.
class DatabaseMoveNotice implements Exception {
  const DatabaseMoveNotice(this.message);

  final String message;

  @override
  String toString() => 'DatabaseMoveNotice: $message';
}

/// The path of the database this build should open, after moving it out of
/// Documents if this is the launch that does that.
///
/// Only a release build on Windows or Linux has anything to move (see
/// [AppIdentity.legacyDatabasePath]); everything else returns its path at
/// once and touches no file. Must finish before anything opens the database.
Future<String> locateDatabase({
  required AppIdentity identity,
  required TargetPlatform platform,
  required SharedPreferences preferences,
  required Future<String> Function() documentsDirectory,
  required Future<String> Function() supportDirectory,
  DatabaseMoveReporter? report,
}) async {
  final target = await identity.databasePath(
    platform: platform,
    documentsDirectory: documentsDirectory,
    supportDirectory: supportDirectory,
  );
  final legacy = await identity.legacyDatabasePath(
    platform: platform,
    documentsDirectory: documentsDirectory,
  );
  if (legacy == null) return target;

  final location = await DatabaseMove(
    targetPath: target,
    legacyPath: legacy,
    preferences: preferences,
    report: report,
  ).run();
  return location.path;
}

/// The one-time move of a desktop release's database from
/// `<documents>/sshetu.db` to the app's own data folder.
///
/// Documents on a desktop is the user's folder, not the app's: other programs
/// sync it, index it and tidy it, and a database there has been lost from it.
/// The rules, in order of how much they matter:
///
///  1. **Never lose data.** The original is copied, never moved in one step.
///     The copy is checked — `PRAGMA integrity_check`, the schema version,
///     and the row count of every table that holds the user's things — before
///     it takes the database's name, by an atomic rename in its own folder.
///     The original is then renamed to `sshetu.db.moved`, never deleted.
///  2. **Never over newer data.** If the app folder already has a database,
///     it is the database, whatever sits in Documents. Once a move has
///     happened it is recorded in preferences, so a stale copy restored to
///     Documents later is not quietly brought back over the moved one.
///  3. **Never an empty app.** If anything fails before the rename, the
///     partial copy is removed and the database is opened where it has always
///     been, for this run. The next launch tries again.
class DatabaseMove {
  DatabaseMove({
    required this.targetPath,
    required this.legacyPath,
    required this.preferences,
    DatabaseFileCopier? copy,
    DatabaseFileRenamer? renameLegacy,
    DatabaseMoveReporter? report,
    DateTime Function()? clock,
  }) : _copy = copy ?? copyDurably,
       _renameLegacy = renameLegacy ?? _rename,
       _report =
           report ??
           ((error, stack) =>
               ErrorLogger.instance.record(error, stack, source: 'database')),
       _clock = clock ?? DateTime.now;

  /// Where the database lives now: `<application support>/sshetu.db`.
  final String targetPath;

  /// Where earlier releases kept it: `<documents>/sshetu.db`.
  final String legacyPath;

  final SharedPreferences preferences;

  final DatabaseFileCopier _copy;
  final DatabaseFileRenamer _renameLegacy;
  final DatabaseMoveReporter _report;
  final DateTime Function() _clock;

  /// The preferences a move is recorded under. [migratedAtKey] is the one that
  /// says a move happened; [migratedFromKey] says from where, for anyone
  /// reading.
  static const String migratedFromKey = 'db.migratedFrom';
  static const String migratedAtKey = 'db.migratedAt';

  /// The legacy path a "left alone" notice was last recorded for, so it is
  /// said once rather than on every launch.
  static const String legacyNotedKey = 'db.legacyNoted';

  /// The tables holding what the user made. Their row counts must agree
  /// between the original and the copy. A table an older schema does not
  /// have yet is skipped, as long as neither file has it.
  static const List<String> countedTables = [
    'hosts',
    'identities',
    'tunnels',
    'snippets',
    'host_groups',
    'known_hosts',
  ];

  /// Files SQLite keeps beside a database that can hold committed data: the
  /// write-ahead log, and a rollback journal. They travel with it.
  ///
  /// `-shm` does not: it is an index of the `-wal` that SQLite rebuilds when
  /// the first connection opens, and a copied one is at best redundant.
  static const List<String> _dataSidecars = ['-wal', '-journal'];
  static const List<String> _allSidecars = ['-wal', '-journal', '-shm'];

  String get _tempPath => '$targetPath.moving';

  Future<DatabaseLocation> run() async {
    final target = File(targetPath);
    final legacy = File(legacyPath);
    final movedBefore = preferences.getString(migratedAtKey) != null;

    if (await target.exists()) {
      // After a move the original may well still be there — it could not be
      // renamed, or the user put a copy back. Expected; not worth a word.
      if (!movedBefore &&
          await legacy.exists() &&
          preferences.getString(legacyNotedKey) != legacyPath) {
        _report(
          DatabaseMoveNotice(
            'Using the database at $targetPath. Another one at $legacyPath, '
            'from an earlier version, was left as it is.',
          ),
          null,
        );
        await preferences.setString(legacyNotedKey, legacyPath);
      }
      return DatabaseLocation(targetPath, DatabaseMoveOutcome.alreadyMoved);
    }

    if (!await legacy.exists()) {
      if (movedBefore) {
        // The moved database is gone and there is nothing to bring over. The
        // backup is deliberately not restored on its own: it is older than
        // what vanished, and the user should decide.
        _report(
          DatabaseMoveException(
            'The database at $targetPath is missing, so a new one was '
            'started. The copy from before it moved is kept in '
            '${p.dirname(legacyPath)}, named '
            '"${p.basename(legacyPath)}.moved".',
          ),
          null,
        );
      }
      await Directory(p.dirname(targetPath)).create(recursive: true);
      return DatabaseLocation(targetPath, DatabaseMoveOutcome.fresh);
    }

    // The original is here and the app folder has nothing. Even after an
    // earlier move that is safe to bring over: there is nothing newer for it
    // to replace, and the alternative is an empty app.
    return _move();
  }

  Future<DatabaseLocation> _move() async {
    final temp = _tempPath;
    final committedSidecars = <String>[];
    try {
      await Directory(p.dirname(targetPath)).create(recursive: true);
      await _removeTemp();
      await _setAsideOrphanedSidecars();

      final copiedSidecars = <String>[];
      await _copyChecked(legacyPath, temp);
      for (final suffix in _dataSidecars) {
        if (await File('$legacyPath$suffix').exists()) {
          await _copyChecked('$legacyPath$suffix', '$temp$suffix');
          copiedSidecars.add(suffix);
        }
      }

      await _verify(temp);
      // Reading a WAL database can leave an index behind; it belongs to no
      // connection now, and SQLite rebuilds it on the next open.
      await _deleteIfExists('$temp-shm');

      if (await File(targetPath).exists()) {
        throw const DatabaseMoveException(
          'a database appeared in the app folder during the move',
        );
      }
      // Sidecars first, the database last: its rename is the moment the move
      // takes effect, and until then nothing answers to the real name.
      for (final suffix in copiedSidecars) {
        await File('$temp$suffix').rename('$targetPath$suffix');
        committedSidecars.add(suffix);
      }
      await File(temp).rename(targetPath);
    } catch (error, stack) {
      // Only the copies are removed. The original is exactly as it was.
      await _removeTemp();
      for (final suffix in committedSidecars) {
        await _deleteIfExists('$targetPath$suffix');
      }
      _report(
        DatabaseMoveException(
          'Could not move the database from $legacyPath to $targetPath, so '
          'it is being used where it is. The move is tried again next '
          'launch. $error',
        ),
        stack,
      );
      return DatabaseLocation(
        legacyPath,
        DatabaseMoveOutcome.failedUsingLegacy,
      );
    }

    // The move has taken effect: the app folder's database is the database
    // from here on, whatever happens below.
    try {
      await preferences.setString(migratedFromKey, legacyPath);
      await preferences.setString(
        migratedAtKey,
        _clock().toUtc().toIso8601String(),
      );
    } catch (error, stack) {
      _report(error, stack);
    }

    return _retireLegacy();
  }

  /// Renames the original and its sidecars to `sshetu.db.moved*`.
  ///
  /// Sidecars first, so a failure never leaves the database without the log
  /// that completes it; if the database itself will not move, the sidecars
  /// are put back.
  Future<DatabaseLocation> _retireLegacy() async {
    final backup = await _freeBackupPath();
    final renamed = <String>[];
    try {
      for (final suffix in _allSidecars) {
        final file = File('$legacyPath$suffix');
        if (await file.exists()) {
          await _renameLegacy(file, '$backup$suffix');
          renamed.add(suffix);
        }
      }
      await _renameLegacy(File(legacyPath), backup);
      return DatabaseLocation(targetPath, DatabaseMoveOutcome.moved);
    } catch (error, stack) {
      for (final suffix in renamed) {
        try {
          await _renameLegacy(File('$backup$suffix'), '$legacyPath$suffix');
        } catch (_) {
          // Left under the backup name; still beside the original.
        }
      }
      _report(
        DatabaseMoveException(
          'The database moved to $targetPath and is used from there. The '
          'original at $legacyPath could not be renamed and was left as it '
          'is; it is no longer used. $error',
        ),
        stack,
      );
      return DatabaseLocation(targetPath, DatabaseMoveOutcome.movedLegacyKept);
    }
  }

  /// `sshetu.db.moved`, or `.moved.2`, `.moved.3`… if an earlier backup is
  /// already there. A backup is never overwritten.
  Future<String> _freeBackupPath() async {
    var candidate = '$legacyPath.moved';
    for (var n = 2; await File(candidate).exists(); n++) {
      candidate = '$legacyPath.moved.$n';
    }
    return candidate;
  }

  Future<void> _copyChecked(String from, String to) async {
    await _copy(from, to);
    final expected = await File(from).length();
    final actual = await File(to).length();
    if (actual != expected) {
      throw DatabaseMoveException(
        'the copy of ${p.basename(from)} is $actual bytes, not $expected',
      );
    }
  }

  Future<void> _verify(String copy) async {
    final original = await _inspect(legacyPath, checkIntegrity: false);
    final copied = await _inspect(copy, checkIntegrity: true);

    final problems = <String>[
      if (copied.integrity != 'ok') 'integrity check: ${copied.integrity}',
      if (copied.userVersion != original.userVersion)
        'schema version ${copied.userVersion}, not ${original.userVersion}',
      for (final table in countedTables)
        if (copied.counts[table] != original.counts[table])
          '$table: ${copied.counts[table] ?? 'missing'} rows in the copy, '
              '${original.counts[table] ?? 'missing'} in the original',
    ];
    if (problems.isNotEmpty) {
      throw DatabaseMoveException(
        'the copy does not match the original — ${problems.join('; ')}',
      );
    }
  }

  /// Reads a database without writing to it.
  static Future<_Inspection> _inspect(
    String path, {
    required bool checkIntegrity,
  }) async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      path,
      // Not the shared instance: nothing else may have this file open
      // through sqflite, and this connection must not outlive the check.
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final integrity = checkIntegrity
          ? (await db.rawQuery('PRAGMA integrity_check'))
                .map((row) => '${row.values.first}')
                .join(', ')
          : null;
      final userVersion = (await db.rawQuery('PRAGMA user_version'))
          .first
          .values
          .first;
      final tables = {
        for (final row in await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          '${row['name']}',
      };
      final counts = <String, int>{};
      for (final table in countedTables) {
        if (!tables.contains(table)) continue;
        final result = await db.rawQuery('SELECT COUNT(*) AS n FROM "$table"');
        counts[table] = result.first['n']! as int;
      }
      return _Inspection(
        integrity: integrity,
        userVersion: userVersion,
        counts: counts,
      );
    } finally {
      await db.close();
    }
  }

  Future<void> _removeTemp() async {
    for (final suffix in ['', ..._allSidecars]) {
      try {
        await _deleteIfExists('$_tempPath$suffix');
      } catch (_) {
        // A copy that cannot be removed now is removed before the next try.
      }
    }
  }

  /// A `-wal` or `-journal` in the app folder with no database beside it.
  ///
  /// It cannot belong to anything — its database is not there — but SQLite
  /// would apply it to the moved database the moment that takes the name.
  /// Set aside rather than deleted: this move deletes nothing it did not make.
  Future<void> _setAsideOrphanedSidecars() async {
    final stamp = _clock().millisecondsSinceEpoch;
    for (final suffix in _allSidecars) {
      final orphan = File('$targetPath$suffix');
      if (await orphan.exists()) {
        await orphan.rename('$targetPath$suffix.orphaned-$stamp');
      }
    }
  }

  static Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<void> _rename(File file, String to) async {
    await file.rename(to);
  }
}

class _Inspection {
  const _Inspection({
    required this.integrity,
    required this.userVersion,
    required this.counts,
  });

  final String? integrity;
  final Object? userVersion;
  final Map<String, int> counts;
}

/// Copies [from] to [to] and flushes the copy to disk before returning.
///
/// `File.copy` returns once the bytes are handed to the OS, which may still be
/// holding them when the original is renamed away. This does not return
/// until the copy is on disk.
Future<void> copyDurably(String from, String to) async {
  final source = await File(from).open();
  try {
    final sink = await File(to).open(mode: FileMode.writeOnly);
    try {
      final buffer = Uint8List(1 << 16);
      while (true) {
        final read = await source.readInto(buffer);
        if (read == 0) break;
        await sink.writeFrom(buffer, 0, read);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  } finally {
    await source.close();
  }
}
