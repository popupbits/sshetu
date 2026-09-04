import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/db/migrations/migrations.dart';
import '../../../core/secrets/secret_ref.dart';
import '../../../core/secrets/secret_vault.dart';

/// A payload that cannot be applied, and why.
class TransferPayloadException implements Exception {
  const TransferPayloadException(this.message);

  final String message;

  @override
  String toString() => 'TransferPayloadException: $message';
}

/// Everything one device is sending another.
///
/// Rows, not domain objects. The database *is* the format: sending
/// `SELECT * FROM hosts` and inserting it on the other side means there is no
/// second mapping to drift from the schema, and a column added in a migration
/// travels without anybody remembering to add it here.
///
/// The price is that both devices must be on the same schema, so the version
/// travels with the payload and a mismatch is refused with something a person
/// can act on. That is the right trade for a transfer between two copies of
/// the same app, which are nearly always the same build.
class TransferPayload {
  const TransferPayload({
    required this.schemaVersion,
    required this.tables,
    required this.secrets,
  });

  /// The tables that travel, in dependency order — a host may name a group and
  /// an identity, and a tunnel names a host, so they have to land in this
  /// order or a foreign key fails.
  ///
  /// `known_hosts` travels too, and that is a considered choice rather than an
  /// oversight: a pin is a decision the sending device already made carefully,
  /// and carrying it means the phone does not have to repeat trust-on-first-use
  /// on whatever network it happens to be on. Re-verifying a host key from a
  /// café is strictly worse than importing one verified at home.
  static const List<String> orderedTables = [
    'host_groups',
    'identities',
    'hosts',
    'tunnels',
    'known_hosts',
  ];

  final int schemaVersion;

  /// Table name to its rows, as read from SQLite.
  final Map<String, List<Map<String, Object?>>> tables;

  /// `SecretRef.storageKey` to its value. Empty unless the sender opted in.
  final Map<String, String> secrets;

  int get hostCount => tables['hosts']?.length ?? 0;
  int get identityCount => tables['identities']?.length ?? 0;
  int get tunnelCount => tables['tunnels']?.length ?? 0;
  int get knownHostCount => tables['known_hosts']?.length ?? 0;

  /// Reads everything this device would send.
  ///
  /// Tombstoned rows are left behind: a deleted host is not something the
  /// other device needs, and sending tombstones would mean the receiver has to
  /// reason about deletions it never saw.
  static Future<TransferPayload> read(
    Database database, {
    required SecretVault vault,
    required bool includeSecrets,
  }) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in orderedTables) {
      final rows = await database.query(
        table,
        where: _hasTombstone(table) ? 'deleted_at IS NULL' : null,
      );
      tables[table] = [for (final row in rows) Map<String, Object?>.from(row)];
    }

    final secrets = <String, String>{};
    if (includeSecrets) {
      for (final row in tables['hosts']!) {
        await _collect(vault, secrets, SecretRef.forHost(row['id']! as String));
      }
      for (final row in tables['identities']!) {
        await _collect(
          vault,
          secrets,
          SecretRef.forIdentity(row['id']! as String),
        );
      }
    }

    return TransferPayload(
      schemaVersion: kSchemaVersion,
      tables: tables,
      secrets: secrets,
    );
  }

  /// Writes this payload into [database] and [vault].
  ///
  /// **Replaces by id**, in one transaction. A row that exists on both devices
  /// is the same row — the ids are the same because they came from the same
  /// place — so the sender's copy wins. That is the promise the sheet makes
  /// ("send these to that device"), and anything cleverer would be the
  /// merge logic this design exists to avoid.
  Future<void> apply(Database database, {required SecretVault vault}) async {
    if (schemaVersion != kSchemaVersion) {
      throw TransferPayloadException(
        'The other device is on database version $schemaVersion and this one '
        'is on $kSchemaVersion. Update SSHetu on both, then try again.',
      );
    }

    await database.transaction((txn) async {
      for (final table in orderedTables) {
        for (final row in tables[table] ?? const []) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    // After the rows, and never in the same transaction: the vault is not
    // SQLite and cannot roll back with it. Rows without their secrets prompt
    // for a password; secrets without their rows are invisible and harmless.
    for (final entry in secrets.entries) {
      final ref = _refFor(entry.key);
      if (ref != null) await vault.write(ref, entry.value);
    }
  }

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'tables': tables,
    'secrets': secrets,
  };

  static TransferPayload fromJson(Map<String, Object?> json) {
    final schema = json['schema'];
    if (schema is! int) {
      throw const TransferPayloadException('payload names no schema version');
    }
    final rawTables = json['tables'];
    if (rawTables is! Map) {
      throw const TransferPayloadException('payload carries no tables');
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in orderedTables) {
      final rows = rawTables[table];
      tables[table] = [
        if (rows is List)
          for (final row in rows)
            if (row is Map) Map<String, Object?>.from(row),
      ];
    }

    final rawSecrets = json['secrets'];
    return TransferPayload(
      schemaVersion: schema,
      tables: tables,
      secrets: {
        if (rawSecrets is Map)
          for (final entry in rawSecrets.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      },
    );
  }

  /// `known_hosts` has no tombstone column — a forgotten pin is deleted
  /// outright, since there is no remote copy to tell about it.
  static bool _hasTombstone(String table) => table != 'known_hosts';

  static Future<void> _collect(
    SecretVault vault,
    Map<String, String> into,
    List<SecretRef> refs,
  ) async {
    for (final ref in refs) {
      final value = await vault.read(ref);
      if (value != null) into[ref.storageKey] = value;
    }
  }

  /// Rebuilds a [SecretRef] from its storage key.
  ///
  /// By asking the real refs what their keys are, rather than re-deriving the
  /// format here. A second copy of `'identity/<id>/private'` in this file
  /// would be one rename away from silently writing every imported key into a
  /// slot nothing reads.
  ///
  /// Returns null for anything unrecognised rather than guessing: a key this
  /// build does not know is a key from a newer one.
  static SecretRef? _refFor(String storageKey) {
    final parts = storageKey.split('/');
    if (parts.length != 3) return null;
    final ownerId = parts[1];
    for (final ref in [
      ...SecretRef.forHost(ownerId),
      ...SecretRef.forIdentity(ownerId),
    ]) {
      if (ref.storageKey == storageKey) return ref;
    }
    return null;
  }
}
