import 'package:sqflite/sqflite.dart';

import '../../hosts/domain/host_tags.dart';
import '../domain/snippet.dart';

/// Reads and writes saved snippets.
///
/// Deletes are tombstones, never `DELETE`, the same as hosts and tunnels —
/// one idea of "gone" across every configuration table, and the transfer and
/// backup paths already know to leave tombstoned rows behind.
class SnippetRepository {
  SnippetRepository({required this.database});

  final Database database;

  static const _table = 'snippets';

  /// Every live snippet, in the user's order and then by name.
  Future<List<Snippet>> all() async {
    final rows = await database.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'sort_order ASC, label COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Snippet?> byId(String id) async {
    final rows = await database.query(
      _table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  /// Inserts or replaces by id. Saving a tombstoned id brings it back.
  Future<void> save(Snippet snippet) async {
    await database.insert(
      _table,
      _toRow(snippet),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id, {required DateTime now}) async {
    await database.update(
      _table,
      {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// The row [snippet] is stored as, for a writer inside its own transaction.
  static Map<String, Object?> rowOf(Snippet snippet) => _toRow(snippet);

  static Map<String, Object?> _toRow(Snippet snippet) => {
    'id': snippet.id,
    'label': snippet.label,
    'body': snippet.body,
    'description': _blankToNull(snippet.description),
    'tags': HostTags.join(snippet.tags),
    'sort_order': snippet.sortOrder,
    'created_at': snippet.createdAt.millisecondsSinceEpoch,
    'updated_at': snippet.updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
  };

  static Snippet _fromRow(Map<String, Object?> row) => Snippet(
    id: row['id']! as String,
    label: row['label']! as String,
    body: row['body']! as String,
    description: row['description'] as String?,
    tags: HostTags.parse(row['tags'] as String?),
    sortOrder: row['sort_order'] as int? ?? 0,
    createdAt: _time(row['created_at'])!,
    updatedAt: _time(row['updated_at'])!,
  );

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  static DateTime? _time(Object? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
}
