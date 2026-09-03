import 'package:sshetu/core/sync/sync_remote.dart';

/// An in-memory [SyncRemote], standing in for Appwrite in every sync test.
///
/// Two devices sharing one `FakeSyncRemote` instance is how a round trip is
/// tested end to end without a live project: device A's engine pushes into
/// it, device B's engine pulls out of it.
class FakeSyncRemote implements SyncRemote {
  /// table -> row id -> row data, exactly what a real Appwrite table holds.
  final Map<String, Map<String, Map<String, Object?>>> tables = {};

  /// Ids that should fail their next [upsertRow] with [failure], then start
  /// succeeding — simulating a connection dropped mid-push. Consumed one
  /// failure per id.
  final Map<String, Object> failOnceForId = {};

  int upsertCalls = 0;

  @override
  Future<void> upsertRow(
    String table,
    String id,
    Map<String, Object?> data,
  ) async {
    upsertCalls++;
    final failure = failOnceForId.remove(id);
    if (failure != null) throw failure;
    (tables[table] ??= {})[id] = Map.of(data);
  }

  @override
  Future<List<Map<String, Object?>>> listUpdatedSince(
    String table, {
    int? since,
  }) async {
    final rows =
        (tables[table] ?? const {}).entries
            .map((e) => {'id': e.key, ...e.value})
            .where(
              (row) => since == null || (row['updated_at']! as int) > since,
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['updated_at']! as int).compareTo(b['updated_at']! as int),
          );
    return rows;
  }
}
