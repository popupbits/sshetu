import 'package:appwrite/appwrite.dart';

import '../appwrite/client.dart';
import '../appwrite/failures.dart';
import '../config/app_config.dart';
import 'sync_remote.dart';

/// [SyncRemote] backed by Appwrite's `TablesDB`.
///
/// Every row this writes is scoped to [userId] through Appwrite's row
/// permissions (set once, on the create that [upsertRow] falls back to), not
/// through a query filter — `listRows` never returns a row the current
/// session cannot read, so [listUpdatedSince] does not need to ask for
/// "mine", only for "new". A plain `user_id` attribute is written alongside
/// anyway: relying solely on permissions makes a misconfigured row much
/// harder to spot from the Appwrite console than one you can also just look
/// at.
class AppwriteSyncRemote implements SyncRemote {
  AppwriteSyncRemote({
    required this.appwrite,
    required this.userId,
    this.databaseId = AppConfig.appwriteDatabaseId,
  });

  final AppwriteService appwrite;
  final String userId;
  final String databaseId;

  /// Appwrite caps a single `listRows` response well below what a heavy
  /// user's config could reach, so this pages rather than assuming one
  /// request is the whole story.
  static const _pageSize = 100;

  @override
  Future<List<Map<String, Object?>>> listUpdatedSince(
    String table, {
    int? since,
  }) {
    return runAppwrite(() async {
      final rows = <Map<String, Object?>>[];
      String? cursor;
      while (true) {
        final page = await appwrite.tablesDB.listRows(
          databaseId: databaseId,
          tableId: table,
          queries: [
            if (since != null) Query.greaterThan('updated_at', since),
            Query.orderAsc('updated_at'),
            Query.limit(_pageSize),
            if (cursor != null) Query.cursorAfter(cursor),
          ],
        );
        rows.addAll(page.rows.map((row) => {...row.data, 'id': row.$id}));
        if (page.rows.length < _pageSize) break;
        cursor = page.rows.last.$id;
      }
      return rows;
    });
  }

  @override
  Future<void> upsertRow(String table, String id, Map<String, Object?> data) {
    return runAppwrite(() async {
      try {
        await appwrite.tablesDB.updateRow(
          databaseId: databaseId,
          tableId: table,
          rowId: id,
          data: data,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        // First time this row has ever reached the backend. Permissions are
        // set only here, on create — updateRow leaves a row's permissions as
        // they are, and re-asserting the same three on every push would just
        // be a wasted round trip.
        await appwrite.tablesDB.createRow(
          databaseId: databaseId,
          tableId: table,
          rowId: id,
          data: data,
          permissions: [
            Permission.read(Role.user(userId)),
            Permission.update(Role.user(userId)),
            Permission.delete(Role.user(userId)),
          ],
        );
      }
    });
  }
}
