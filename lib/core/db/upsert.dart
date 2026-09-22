import 'package:sqflite/sqflite.dart';

/// Writes [row] to [table]: an UPDATE of the row whose `id` is [id], or an
/// INSERT when there is none.
///
/// **Never `INSERT OR REPLACE` for a table something points at.** REPLACE
/// deletes the old row before inserting the new one, and that delete fires
/// the foreign keys like any other: saving a host cascaded away its tunnels,
/// saving a bastion tripped every `jump_host_id … ON DELETE RESTRICT` that
/// named it, and saving a key set `identity_id` to null on every host using
/// it. An UPDATE keeps the row, so nothing that refers to it is touched.
Future<void> upsertRow(
  DatabaseExecutor db,
  String table,
  Map<String, Object?> row, {
  required String id,
}) async {
  final updated = await db.update(table, row, where: 'id = ?', whereArgs: [id]);
  if (updated == 0) await db.insert(table, row);
}
