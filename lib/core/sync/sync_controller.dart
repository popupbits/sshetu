import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/auth/auth_controller.dart';
import '../appwrite/client.dart';
import '../db/database.dart';
import 'appwrite_sync_remote.dart';
import 'sync_engine.dart';
import 'sync_status.dart';
import 'sync_table_spec.dart';

/// Drives one push/pull cycle and reports [SyncStatus] to Settings.
///
/// [build] never touches the network. An unauthenticated user — the app's
/// primary, must-keep-working mode — must not pay for a request they did not
/// ask for, so everything the initial state needs ([pendingCount],
/// [lastSyncedAt]) is read from the local database, which also keeps it
/// correct while offline.
final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncStatus>(SyncController.new);

class SyncController extends AsyncNotifier<SyncStatus> {
  @override
  Future<SyncStatus> build() async {
    final database = ref.watch(databaseProvider).raw;
    return SyncStatus(
      lastSyncedAt: await _lastSyncedAt(database),
      pendingCount: await _pendingCount(database),
      isSyncing: false,
    );
  }

  /// Runs one push-then-pull cycle. A no-op, not an error, when nobody is
  /// signed in — the "Sync now" row this backs is never shown in that case
  /// (see `SyncStatusTile`), but a stray call must still do nothing rather
  /// than throw or reach for `AppwriteSyncRemote` with no user to scope rows
  /// to.
  Future<void> syncNow() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final database = ref.read(databaseProvider).raw;
    final current =
        state.value ??
        SyncStatus(
          lastSyncedAt: await _lastSyncedAt(database),
          pendingCount: await _pendingCount(database),
          isSyncing: false,
        );
    state = AsyncData(current.copyWith(isSyncing: true, clearLastError: true));

    final engine = SyncEngine(
      database: database,
      remote: AppwriteSyncRemote(
        appwrite: ref.read(appwriteProvider),
        userId: user.$id,
      ),
      userId: user.$id,
    );

    try {
      await engine.push();
      await engine.pull();
      state = AsyncData(
        SyncStatus(
          lastSyncedAt: await _lastSyncedAt(database),
          pendingCount: await _pendingCount(database),
          isSyncing: false,
        ),
      );
    } on Object catch (e) {
      // Whatever pushed or pulled before the failure already committed (see
      // SyncEngine's class comment on interruption), so the counts below
      // reflect real progress, not "nothing happened".
      state = AsyncData(
        SyncStatus(
          lastSyncedAt: await _lastSyncedAt(database),
          pendingCount: await _pendingCount(database),
          isSyncing: false,
          lastError: e.toString(),
        ),
      );
    }
  }

  static Future<DateTime?> _lastSyncedAt(Database database) async {
    final rows = await database.rawQuery(
      'SELECT MAX(last_pulled_at) AS at FROM sync_cursors',
    );
    final at = rows.first['at'] as int?;
    return at == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
  }

  static Future<int> _pendingCount(Database database) async {
    var total = 0;
    for (final spec in syncTables) {
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS n FROM ${spec.localTable} WHERE dirty = 1',
      );
      total += rows.first['n']! as int;
    }
    return total;
  }
}
