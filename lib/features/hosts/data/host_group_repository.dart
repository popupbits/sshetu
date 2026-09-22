import 'package:sqflite/sqflite.dart';

import '../domain/host_group.dart';

/// Reads and writes host groups.
///
/// Deletes are tombstones, like every other configuration row. That matters
/// for the foreign keys: a tombstone is an UPDATE, so neither
/// `hosts.group_id ON DELETE SET NULL` nor `parent_id ON DELETE RESTRICT`
/// ever fires. Moving the hosts out is therefore this class's job, done in
/// the same transaction as the tombstone — otherwise a deleted folder would
/// keep its servers, pointing at a row nothing shows, and they would vanish
/// from the list.
class HostGroupRepository {
  HostGroupRepository({required this.database});

  final Database database;

  static const _table = 'host_groups';

  /// Every group not deleted, in display order.
  Future<List<HostGroup>> all() async {
    final rows = await database.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<HostGroup?> byId(String id) async {
    final rows = await database.query(
      _table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  /// Inserts or updates [group].
  ///
  /// An UPDATE when the row exists rather than `INSERT OR REPLACE`: REPLACE
  /// deletes the old row first, and that delete *does* fire the foreign keys —
  /// renaming a folder would quietly empty it.
  Future<void> save(HostGroup group) async {
    final row = _toRow(group);
    final updated = await database.update(
      _table,
      row,
      where: 'id = ?',
      whereArgs: [group.id],
    );
    if (updated == 0) await database.insert(_table, row);
  }

  /// One past the highest sort order in use, so a new group lands last.
  Future<int> nextSortOrder() async {
    final rows = await database.rawQuery(
      'SELECT MAX(sort_order) AS top FROM $_table WHERE deleted_at IS NULL',
    );
    final top = rows.single['top'] as int?;
    return top == null ? 0 : top + 1;
  }

  /// Tombstones [id], moving its hosts — and any child groups — to the top
  /// level first.
  ///
  /// Never takes a server with it. The schema says the same thing with
  /// RESTRICT and SET NULL; this is what makes it true for a soft delete.
  Future<void> delete(String id, {required DateTime now}) async {
    final at = now.millisecondsSinceEpoch;
    await database.transaction((txn) async {
      await txn.update(
        'hosts',
        {'group_id': null, 'updated_at': at, 'dirty': 1},
        where: 'group_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        _table,
        {'parent_id': null, 'updated_at': at, 'dirty': 1},
        where: 'parent_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        _table,
        {'deleted_at': at, 'updated_at': at, 'dirty': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  static Map<String, Object?> _toRow(HostGroup group) => {
    'id': group.id,
    'name': group.name,
    'sort_order': group.sortOrder,
    'created_at': group.createdAt.millisecondsSinceEpoch,
    'updated_at': group.updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'dirty': 1,
  };

  static HostGroup _fromRow(Map<String, Object?> row) => HostGroup(
    id: row['id']! as String,
    name: row['name']! as String,
    sortOrder: row['sort_order'] as int? ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ),
  );
}
