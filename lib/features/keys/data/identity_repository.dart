import 'package:sqflite/sqflite.dart';

import '../../../core/secrets/secret_ref.dart';
import '../../../core/secrets/secret_vault.dart';
import '../domain/ssh_identity.dart';

/// Reads and writes SSH identities, and owns the one place private key
/// material enters or leaves the app.
///
/// [save] takes the private key as an argument rather than as a field on
/// [SshIdentity] on purpose: the model is what gets listed, cached, logged and
/// synced, and a model carrying key material would eventually end up in all
/// four. The key goes straight to the vault and is never held on the object.
class IdentityRepository {
  IdentityRepository({required this.database, required this.vault});

  final Database database;
  final SecretVault vault;

  static const _table = 'identities';

  Future<List<SshIdentity>> all() async {
    final rows = await database.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'label COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<SshIdentity?> byId(String id) async {
    final rows = await database.query(
      _table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  /// Saves [identity], writing [privateKey] and [passphrase] to the vault.
  ///
  /// The vault is written **first**. A row that exists without its key is a
  /// key the user thinks they have and cannot use; a key in the vault without
  /// a row is invisible and harmless, and the next save overwrites it.
  Future<void> save(
    SshIdentity identity, {
    String? privateKey,
    String? passphrase,
  }) async {
    if (privateKey != null) {
      await vault.write(SecretRef.identityPrivateKey(identity.id), privateKey);
    }
    if (passphrase != null) {
      await vault.write(SecretRef.identityPassphrase(identity.id), passphrase);
    }
    await database.insert(
      _table,
      _toRow(identity),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Whether the private key for [id] is actually present.
  ///
  /// Uses `contains`, not `read`, so a list can show which keys are usable
  /// without a biometric prompt per row.
  Future<bool> hasPrivateKey(String id) =>
      vault.contains(SecretRef.identityPrivateKey(id));

  /// Tombstones the identity and destroys its key material for real.
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
    // Every slot, via forIdentity — deleting the key and forgetting the
    // passphrase would leave half a secret behind after the user believed the
    // whole thing was gone.
    await vault.deleteAll(SecretRef.forIdentity(id));
  }

  static Map<String, Object?> _toRow(SshIdentity identity) => {
    'id': identity.id,
    'label': identity.label,
    'key_type': identity.keyType,
    'public_key': identity.publicKey,
    'fingerprint': identity.fingerprint,
    'has_passphrase': identity.hasPassphrase ? 1 : 0,
    'origin': identity.origin.name,
    'created_at': identity.createdAt.millisecondsSinceEpoch,
    'updated_at': identity.updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'dirty': 1,
  };

  static SshIdentity _fromRow(Map<String, Object?> row) => SshIdentity(
    id: row['id']! as String,
    label: row['label']! as String,
    keyType: row['key_type']! as String,
    publicKey: row['public_key'] as String?,
    fingerprint: row['fingerprint'] as String?,
    hasPassphrase: (row['has_passphrase'] as int? ?? 0) == 1,
    origin: IdentityOrigin.values.firstWhere(
      (o) => o.name == row['origin'],
      orElse: () => IdentityOrigin.imported,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ),
  );
}
