/// Seam between [SyncEngine] and wherever rows actually live.
///
/// The engine only ever calls this — never `TablesDB` directly — so a
/// push/pull round trip can be tested against an in-memory fake
/// (`test/sync/fake_sync_remote.dart`) instead of a live Appwrite project.
/// [AppwriteSyncRemote] is the real implementation.
abstract interface class SyncRemote {
  /// Rows in [table] whose `updated_at` is greater than [since] (every row,
  /// if null), oldest first.
  ///
  /// Strictly greater-than, not greater-or-equal: the caller advances its
  /// cursor to the maximum `updated_at` seen in the returned page, and
  /// re-including that value next time would fetch the same rows forever.
  /// The cost is a row sharing that exact value with a sibling written a
  /// moment later can be missed until something else touches it — vanishing
  /// rare at millisecond resolution for hand-edited configuration, and never
  /// a correctness problem for a row this device pushed itself, since
  /// last-writer-wins resolves those on delivery regardless of ordering.
  Future<List<Map<String, Object?>>> listUpdatedSince(
    String table, {
    int? since,
  });

  /// Row [id] in [table] has exactly [data] afterwards, whether or not it
  /// already existed remotely.
  ///
  /// One call rather than separate create/update because the caller
  /// ([SyncEngine.push]) does not know, and must not need to know, whether
  /// this device has pushed this row before — that state lives only in
  /// `dirty`, which says nothing about the *remote* row's history. Addressing
  /// every push by the row's own stable id, rather than ever calling a
  /// "create" that could mint a second document for the same row, is what
  /// makes a retried push idempotent instead of a duplicate.
  Future<void> upsertRow(String table, String id, Map<String, Object?> data);
}
