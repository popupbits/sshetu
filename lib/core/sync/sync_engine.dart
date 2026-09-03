import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'sync_remote.dart';
import 'sync_table_spec.dart';

/// One push-then-pull cycle over every table in [syncTables].
///
/// The local database stays the source of truth for reads throughout: this
/// only ever adds to it or corrects it from the backend, and nothing in the
/// app waits on a network round trip to show a host, a key or a tunnel.
///
/// **Conflict resolution is last-writer-wins on `updated_at`.** When a row
/// changed locally (still `dirty`) and a *newer* remote version of the same
/// row arrives, the remote version replaces it outright — there is no field
/// merge. A host edited on two devices before either synced keeps only the
/// later edit; the earlier one is gone, with no trace and no prompt. That is
/// a real, accepted cost: a merge UI for a form this small, used by at most a
/// handful of devices per user, would cost more in complexity and confusion
/// ("which of these did I want?") than an occasional lost edit costs in
/// annoyance. See `docs/prior-art.md` § Credential storage for the sibling
/// decision this mirrors. A same-millisecond tie is treated as "keep local":
/// it is almost always this device pulling back the very row it just pushed,
/// and treating it as remote-wins would be a no-op at best and, at worst,
/// could clobber a *second* local edit made in the instant between that push
/// and this pull.
///
/// **Interruption is safe by construction, not by a saved "resume point".**
/// [push] clears a row's `dirty` flag immediately after that row's own write
/// reaches the backend, so a connection dropped after row 5 of 20 leaves rows
/// 1-4 synced and 5-20 still `dirty` — the next [push] finds exactly those
/// and nothing has to remember where it left off. Every push addresses a row
/// by its own stable id ([SyncRemote.upsertRow]), so a retried row can never
/// become a duplicate remote document, only the same row written again.
/// [pull] applies one fetched page and advances that table's cursor
/// (`sync_cursors`) inside a single transaction, so a crash mid-page rolls
/// the whole page back rather than leaving the cursor ahead of what was
/// actually applied.
class SyncEngine {
  SyncEngine({
    required this.database,
    required this.remote,
    required this.userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Database database;
  final SyncRemote remote;
  final String userId;
  final DateTime Function() _now;

  Future<void> push() async {
    for (final spec in syncTables) {
      await _pushTable(spec);
    }
  }

  Future<void> _pushTable(SyncTableSpec spec) async {
    final rows = await database.query(
      spec.localTable,
      where: 'dirty = 1',
      // Oldest edits first, so a resumed push makes steady forward progress
      // through a stable order rather than whatever order the query planner
      // happens to hand rows back in.
      orderBy: 'updated_at ASC, id ASC',
    );

    for (final row in rows) {
      final id = row['id']! as String;
      final data = <String, Object?>{
        for (final column in spec.columns) column: row[column],
        'user_id': userId,
      };
      await remote.upsertRow(spec.remoteTable, id, data);
      await database.update(
        spec.localTable,
        {'dirty': 0, 'synced_at': _now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> pull() async {
    for (final spec in syncTables) {
      await _pullTable(spec);
    }
  }

  Future<void> _pullTable(SyncTableSpec spec) async {
    final since = await _cursor(database, spec.localTable);
    final remoteRows = await remote.listUpdatedSince(
      spec.remoteTable,
      since: since,
    );
    if (remoteRows.isEmpty) return;

    await database.transaction((txn) async {
      final applied = <Map<String, Object?>>[];
      for (final remoteRow in remoteRows) {
        if (await _merge(txn, spec, remoteRow)) applied.add(remoteRow);
      }

      // Second pass for self-referencing columns (see SyncTableSpec) — every
      // row in the page now exists, so the deferred value can be applied
      // without ever having pointed at a row that was not there yet.
      for (final column in spec.deferredForeignKeys) {
        for (final remoteRow in applied) {
          final value = remoteRow[column];
          if (value == null) continue;
          try {
            await txn.update(
              spec.localTable,
              {column: value},
              where: 'id = ?',
              whereArgs: [remoteRow['id']],
            );
          } on DatabaseException {
            // The referenced row is not local yet — e.g. it belongs to a
            // later page, or the device that owns it has not pushed. Leaving
            // this column null rather than failing the whole page is safe:
            // the row is not dirty (it was just written from the pull
            // above), so nothing here gets re-pushed with a wrong value, and
            // a later pull that brings the missing row in will not revisit
            // this one — this is a known, narrow gap rather than a handled
            // case, and it self-heals once both rows have synced once more.
          }
        }
      }

      // Cursor advances past every row this pull saw, not only the ones it
      // applied — a row skipped by last-writer-wins must not be re-fetched
      // forever just because this device chose to keep its own edit.
      final maxUpdatedAt = remoteRows
          .map((r) => r['updated_at']! as int)
          .reduce(max);
      await _saveCursor(txn, spec.localTable, maxUpdatedAt);
    });
  }

  /// Applies [remoteRow] to [spec.localTable], honouring last-writer-wins.
  /// Returns whether it actually wrote anything.
  Future<bool> _merge(
    DatabaseExecutor executor,
    SyncTableSpec spec,
    Map<String, Object?> remoteRow,
  ) async {
    final id = remoteRow['id']! as String;
    final remoteUpdatedAt = remoteRow['updated_at']! as int;

    final existing = await executor.query(
      spec.localTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final local = existing.isEmpty ? null : existing.single;

    if (local != null && (local['dirty']! as int) == 1) {
      final localUpdatedAt = local['updated_at']! as int;
      if (remoteUpdatedAt <= localUpdatedAt) {
        // Local is newer, or exactly tied — see the class comment for why a
        // tie also keeps local. Either way the local edit survives and will
        // overwrite this remote version on the next push.
        return false;
      }
      // Remote is strictly newer: falls through and overwrites the local
      // edit below. This is the accepted cost of last-writer-wins.
    }

    final values = <String, Object?>{
      'id': id,
      for (final column in spec.columns) column: remoteRow[column],
      'dirty': 0,
      'synced_at': _now().millisecondsSinceEpoch,
    };
    for (final column in spec.deferredForeignKeys) {
      values[column] = null;
    }

    if (local == null) {
      await executor.insert(
        spec.localTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // A plain UPDATE naming only [spec.columns], not insert-or-replace:
      // replace would reset every column this table has that sync does not
      // know about — e.g. `hosts.last_connected_at` — to its default,
      // silently destroying purely local state on every pull.
      await executor.update(
        spec.localTable,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return true;
  }

  Future<int?> _cursor(DatabaseExecutor executor, String table) async {
    final rows = await executor.query(
      'sync_cursors',
      where: 'table_name = ?',
      whereArgs: [table],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['last_pulled_at'] as int;
  }

  Future<void> _saveCursor(
    DatabaseExecutor executor,
    String table,
    int updatedAt,
  ) => executor.insert('sync_cursors', {
    'table_name': table,
    'last_pulled_at': updatedAt,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
