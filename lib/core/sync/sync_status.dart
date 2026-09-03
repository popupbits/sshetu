/// What Settings shows about sync.
///
/// [lastSyncedAt] and [pendingCount] always come from the local database,
/// never from a live network check — they stay meaningful, and cheap to
/// compute, even offline or before the user has ever signed in.
class SyncStatus {
  const SyncStatus({
    required this.lastSyncedAt,
    required this.pendingCount,
    required this.isSyncing,
    this.lastError,
  });

  /// When the newest table last finished applying a pulled page. Null before
  /// the first successful sync.
  final DateTime? lastSyncedAt;

  /// Rows across every synced table that have not reached the backend yet.
  final int pendingCount;

  final bool isSyncing;

  /// Set by the most recent failed [SyncController.syncNow]; cleared by the
  /// next attempt, successful or not. Deliberately **not persisted** —
  /// restarting the app clears it. It exists to answer "why hasn't my edit
  /// shown up on my other device yet" right now, not as a permanent record;
  /// `core/error/` is where a permanent record belongs, and secret sync
  /// failures already go there (see `LayeredSecretVault`).
  final String? lastError;

  SyncStatus copyWith({
    DateTime? lastSyncedAt,
    int? pendingCount,
    bool? isSyncing,
    String? lastError,
    bool clearLastError = false,
  }) => SyncStatus(
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    pendingCount: pendingCount ?? this.pendingCount,
    isSyncing: isSyncing ?? this.isSyncing,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
  );
}
