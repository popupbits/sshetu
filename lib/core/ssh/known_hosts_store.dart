import 'package:sqflite/sqflite.dart';

import 'host_key.dart';
import 'known_hosts_file.dart';

/// Where trusted host keys are kept.
///
/// An interface so the verifier can be tested without a database, and so an
/// OpenSSH `known_hosts` file can be read on desktop later without the
/// verifier changing.
abstract interface class KnownHostsStore {
  /// The trusted key for [hostname]:[port], or null if the host is unknown.
  ///
  /// The pin recorded under that exact address when there is one, else the
  /// first hashed entry that matches — see [findAll].
  KnownHostKey? find(String hostname, int port);

  /// Every trusted key that speaks for [hostname]:[port]: the pin recorded
  /// under that address, then any hashed entries imported from a
  /// `known_hosts` file whose hash is of that address.
  ///
  /// More than one because a hashed file cannot be grouped by host — each
  /// of a server's keys sits on its own line under its own salt — so an
  /// imported server with an Ed25519 and an RSA key is two entries that only
  /// reveal they are the same host when asked about it by name.
  List<KnownHostKey> findAll(String hostname, int port);

  /// Records [key] as trusted, replacing any earlier entry for its address.
  Future<void> trust(KnownHostKey key);

  /// Forgets the entry for [hostname]:[port].
  ///
  /// The only way past a `changed` verdict: the user removes the pin
  /// deliberately, having satisfied themselves the host really was rebuilt.
  Future<void> forget(String hostname, int port);

  /// Every trusted key, for the settings screen that lists and revokes them.
  List<KnownHostKey> all();
}

/// [KnownHostsStore] over the local `known_hosts` table.
///
/// Reads are synchronous against an in-memory cache, because they happen
/// inside `dartssh2`'s `onVerifyHostKey` callback and a verifier that has to
/// await a database round trip mid-handshake is a verifier that will
/// eventually time out on a slow device. Writes go to both.
///
/// This table is deliberately **not** synced to the backend. A trust decision
/// is made about a network path, from one device; replicating it to every
/// other device would turn one accepted key into fleet-wide trust, which is
/// the opposite of what verification is for.
class SqfliteKnownHostsStore implements KnownHostsStore {
  SqfliteKnownHostsStore(this._db);

  final Database _db;

  static const _table = 'known_hosts';

  final Map<String, KnownHostKey> _cache = {};

  static String _key(String hostname, int port) => '$hostname:$port';

  /// Fills the cache. Call once, during bootstrap, before any connection.
  Future<void> load() async {
    final rows = await _db.query(_table);
    _cache
      ..clear()
      ..addEntries(
        rows.map(_fromRow).map((k) => MapEntry(_key(k.hostname, k.port), k)),
      );
  }

  @override
  KnownHostKey? find(String hostname, int port) =>
      findAll(hostname, port).firstOrNull;

  @override
  List<KnownHostKey> findAll(String hostname, int port) =>
      matchingKnownHosts(_cache.values, hostname, port);

  @override
  List<KnownHostKey> all() =>
      _cache.values.toList()..sort((a, b) => a.hostname.compareTo(b.hostname));

  @override
  Future<void> trust(KnownHostKey key) async {
    await _db.insert(
      _table,
      _toRow(key),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cache[_key(key.hostname, key.port)] = key;
  }

  @override
  Future<void> forget(String hostname, int port) async {
    await _db.delete(
      _table,
      where: 'hostname = ? AND port = ?',
      whereArgs: [hostname, port],
    );
    _cache.remove(_key(hostname, port));
  }

  static Map<String, Object?> _toRow(KnownHostKey key) => {
    'hostname': key.hostname,
    'port': key.port,
    'key_type': key.keyType,
    'fingerprint': key.fingerprint,
    'trusted_at': key.trustedAt.millisecondsSinceEpoch,
  };

  static KnownHostKey _fromRow(Map<String, Object?> row) => KnownHostKey(
    hostname: row['hostname']! as String,
    port: row['port']! as int,
    keyType: row['key_type']! as String,
    fingerprint: row['fingerprint']! as String,
    trustedAt: DateTime.fromMillisecondsSinceEpoch(
      row['trusted_at']! as int,
      isUtc: true,
    ),
  );
}

/// A [KnownHostsStore] held in memory. For tests, and for a "forget everything
/// on exit" mode.
class InMemoryKnownHostsStore implements KnownHostsStore {
  final Map<String, KnownHostKey> _values = {};

  static String _key(String hostname, int port) => '$hostname:$port';

  @override
  KnownHostKey? find(String hostname, int port) =>
      findAll(hostname, port).firstOrNull;

  @override
  List<KnownHostKey> findAll(String hostname, int port) =>
      matchingKnownHosts(_values.values, hostname, port);

  @override
  List<KnownHostKey> all() => _values.values.toList();

  @override
  Future<void> trust(KnownHostKey key) async {
    _values[_key(key.hostname, key.port)] = key;
  }

  @override
  Future<void> forget(String hostname, int port) async {
    _values.remove(_key(hostname, port));
  }
}

/// The keys in [all] that speak for [hostname]:[port]: an exact pin first,
/// then hashed entries (see [KnownHostKey.isHashed]) whose HMAC matches the
/// address. Hashing is only tried when there are hashed entries at all, so a
/// store that never imported a hashed file pays nothing for the feature.
List<KnownHostKey> matchingKnownHosts(
  Iterable<KnownHostKey> all,
  String hostname,
  int port,
) {
  final exact = <KnownHostKey>[];
  final hashed = <KnownHostKey>[];
  String? name;
  for (final key in all) {
    if (key.isHashed) {
      name ??= knownHostsName(hostname.toLowerCase(), port);
      if (hashedNameMatches(key.hostname, name)) hashed.add(key);
    } else if (key.port == port &&
        key.hostname.toLowerCase() == hostname.toLowerCase()) {
      exact.add(key);
    }
  }
  return [...exact, ...hashed];
}
