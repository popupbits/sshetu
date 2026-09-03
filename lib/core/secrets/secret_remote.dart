import 'package:appwrite/appwrite.dart';

import '../appwrite/client.dart';
import '../appwrite/failures.dart';
import '../config/app_config.dart';

/// Seam between [AppwriteSecretVault] and Appwrite's `TablesDB`.
///
/// Exists for the same reason `core/sync/sync_remote.dart`'s `SyncRemote`
/// does: tests fake this interface (`test/sync/fake_secret_remote.dart`)
/// instead of hitting a live project.
abstract interface class SecretRemote {
  /// The stored value at [rowId], or null if nothing is stored there.
  Future<String?> read(String rowId);

  /// Whether a value is stored at [rowId] — without reading it, matching why
  /// [SecretVault.contains] exists at all: a list row that shows "password
  /// saved" should not have to pull an encrypted secret across the network
  /// just to render.
  Future<bool> exists(String rowId);

  /// Stores [value] at [rowId], creating the row if this is the first write.
  /// [ownerId] and [kind] are written alongside as plain attributes — see
  /// [AppwriteSecretVault] for why the id alone cannot carry that
  /// information legibly.
  Future<void> write(
    String rowId, {
    required String value,
    required String ownerId,
    required String kind,
    required String userId,
  });

  /// Removes the row. Succeeds whether or not one was there, matching
  /// [SecretVault.delete]'s idempotence.
  Future<void> delete(String rowId);
}

/// [SecretRemote] backed by Appwrite's `TablesDB`, storing secrets in the
/// `secrets` table's `encrypt` attribute. See [AppwriteSecretVault] for the
/// tradeoff that attribute carries — this class is purely the transport.
class AppwriteSecretRemote implements SecretRemote {
  AppwriteSecretRemote({
    required this.appwrite,
    this.databaseId = AppConfig.appwriteDatabaseId,
    this.tableId = 'secrets',
  });

  final AppwriteService appwrite;
  final String databaseId;
  final String tableId;

  @override
  Future<String?> read(String rowId) async {
    try {
      return await runAppwrite(() async {
        final row = await appwrite.tablesDB.getRow(
          databaseId: databaseId,
          tableId: tableId,
          rowId: rowId,
        );
        return row.data['value'] as String?;
      });
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  Future<bool> exists(String rowId) => runAppwrite(() async {
    final result = await appwrite.tablesDB.listRows(
      databaseId: databaseId,
      tableId: tableId,
      // Selecting only the id means Appwrite never has to decrypt `value` to
      // answer this — the whole reason `contains` is a separate call from
      // `read` up through the SecretVault interface.
      queries: [
        Query.equal(r'$id', rowId),
        Query.select([r'$id']),
        Query.limit(1),
      ],
      total: true,
    );
    return result.total > 0;
  });

  @override
  Future<void> write(
    String rowId, {
    required String value,
    required String ownerId,
    required String kind,
    required String userId,
  }) => runAppwrite(() async {
    final data = {'value': value, 'owner_id': ownerId, 'kind': kind};
    try {
      await appwrite.tablesDB.updateRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      await appwrite.tablesDB.createRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: data,
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
    }
  });

  @override
  Future<void> delete(String rowId) async {
    try {
      await runAppwrite(
        () => appwrite.tablesDB.deleteRow(
          databaseId: databaseId,
          tableId: tableId,
          rowId: rowId,
        ),
      );
    } on NotFoundFailure {
      // Already gone. Matches SecretVault.delete's idempotence.
    }
  }
}
