import 'package:sqflite/sqflite.dart';

import '../../../core/sync/sync_signal.dart';
import '../domain/tunnel.dart';

/// Reads and writes saved port forwards.
///
/// Deletes are tombstones, never `DELETE` — the same reasoning as
/// `HostRepository`: configuration syncs across a user's devices, and a row
/// that vanishes without trace reappears from whichever device had not heard
/// about the delete yet. Unlike a host, a tunnel holds no secret, so there is
/// nothing else to destroy on delete.
///
/// A host's tunnels are hard-deleted by the database itself — `tunnels.host_id
/// REFERENCES hosts (id) ON DELETE CASCADE` — because a forward pointing at a
/// host that no longer exists cannot sync to anything meaningful; there is no
/// tombstone worth keeping for it.
class TunnelRepository {
  TunnelRepository({required this.database, this.signal});

  final Database database;

  /// Told after every committed write, so sync knows there is something to
  /// push. Optional: a repository built without one — in a test, or by the
  /// importer's dry run — simply reports nothing.
  final SyncSignal? signal;

  static const _table = 'tunnels';

  /// Every saved forward, across every host.
  Future<List<Tunnel>> all() async {
    final rows = await database.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'label COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<Tunnel>> forHost(String hostId) async {
    final rows = await database.query(
      _table,
      where: 'host_id = ? AND deleted_at IS NULL',
      whereArgs: [hostId],
      orderBy: 'label COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Tunnel?> byId(String id) async {
    final rows = await database.query(
      _table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<void> save(Tunnel tunnel) async {
    await database.insert(
      _table,
      _toRow(tunnel),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    signal?.localChange();
  }

  Future<void> delete(String id, {required DateTime now}) async {
    await database.update(
      _table,
      {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    signal?.localChange();
  }

  static Map<String, Object?> _toRow(Tunnel tunnel) => {
    'id': tunnel.id,
    'host_id': tunnel.hostId,
    'label': tunnel.label,
    'kind': tunnel.kind.storageValue,
    'listen_host': tunnel.listenHost,
    'listen_port': tunnel.listenPort,
    'target_host': tunnel.targetHost,
    'target_port': tunnel.targetPort,
    'auto_start': tunnel.autoStart ? 1 : 0,
    'created_at': tunnel.createdAt.millisecondsSinceEpoch,
    'updated_at': tunnel.updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'dirty': 1,
  };

  static Tunnel _fromRow(Map<String, Object?> row) => Tunnel(
    id: row['id']! as String,
    hostId: row['host_id']! as String,
    label: row['label']! as String,
    kind: TunnelKind.fromStorage(row['kind']! as String),
    listenHost: row['listen_host'] as String? ?? Tunnel.defaultListenHost,
    listenPort: row['listen_port']! as int,
    targetHost: row['target_host'] as String?,
    targetPort: row['target_port'] as int?,
    autoStart: (row['auto_start'] as int? ?? 0) == 1,
    createdAt: _time(row['created_at'])!,
    updatedAt: _time(row['updated_at'])!,
  );

  static DateTime? _time(Object? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
}
