import 'package:sshetu/core/secrets/secret_remote.dart';

/// An in-memory [SecretRemote], standing in for Appwrite's `secrets` table.
class FakeSecretRemote implements SecretRemote {
  final Map<String, Map<String, String>> _rows = {};

  /// Every row id ever written, for tests that only care about the id shape
  /// (length, charset) rather than the value stored under it.
  Iterable<String> get debugRowIds => _rows.keys;

  @override
  Future<String?> read(String rowId) async => _rows[rowId]?['value'];

  @override
  Future<bool> exists(String rowId) async => _rows.containsKey(rowId);

  @override
  Future<void> write(
    String rowId, {
    required String value,
    required String ownerId,
    required String kind,
    required String userId,
  }) async {
    _rows[rowId] = {
      'value': value,
      'owner_id': ownerId,
      'kind': kind,
      'user_id': userId,
    };
  }

  @override
  Future<void> delete(String rowId) async {
    _rows.remove(rowId);
  }
}
