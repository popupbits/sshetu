import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/transfer/domain/transfer_payload.dart';

import '../support/test_database.dart';

/// A vault that records what it was asked for.
///
/// Reading a secret on macOS can raise a system authorisation prompt, so the
/// number of reads is not an implementation detail — it is how many times
/// someone is interrupted for one tap.
class _CountingVault implements SecretVault {
  final asked = <String>[];
  final _values = <String, String>{};

  @override
  Future<String?> read(SecretRef ref) async {
    asked.add(ref.storageKey);
    return _values[ref.storageKey];
  }

  @override
  Future<void> write(SecretRef ref, String value) async =>
      _values[ref.storageKey] = value;

  @override
  Future<void> delete(SecretRef ref) async => _values.remove(ref.storageKey);

  @override
  Future<bool> contains(SecretRef ref) async =>
      _values.containsKey(ref.storageKey);

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    for (final ref in refs) {
      await delete(ref);
    }
  }
}

void main() {
  late AppDatabase database;
  late _CountingVault vault;

  setUp(() async {
    database = await openTestDatabase();
    vault = _CountingVault();
  });

  tearDown(() async => database.raw.close());

  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> addIdentity(String id, {required bool hasPassphrase}) =>
      database.raw.insert('identities', {
        'id': id,
        'label': id,
        'key_type': 'ssh-ed25519',
        'has_passphrase': hasPassphrase ? 1 : 0,
        'origin': 'generated',
        'created_at': now,
        'updated_at': now,
      });

  Future<void> addHost(String id, {required String authMethod}) =>
      database.raw.insert('hosts', {
        'id': id,
        'label': id,
        'hostname': '10.0.0.1',
        'port': 22,
        'username': 'root',
        'auth_method': authMethod,
        'allow_legacy_algorithms': 0,
        'keepalive_seconds': 30,
        'created_at': now,
        'updated_at': now,
      });

  Future<TransferPayload> read() async => (await TransferPayload.read(
    database.raw,
    includeSecrets: true,
  )).withSecrets(vault);

  test('a key with no passphrase is asked for once, not twice', () async {
    // The reported bug: one key produced two keychain prompts, the second for
    // a passphrase the row already said did not exist.
    await addIdentity('k1', hasPassphrase: false);

    await read();

    expect(vault.asked, ['identity/k1/private']);
  });

  test('a key with a passphrase is asked for both', () async {
    await addIdentity('k1', hasPassphrase: true);

    await read();

    expect(vault.asked, ['identity/k1/private', 'identity/k1/passphrase']);
  });

  test('every host is asked about, whatever its auth method says', () async {
    // Not filtered by auth_method, though it looks like the same trick as
    // has_passphrase. Password auth is a fallback for every host: a
    // key-authenticated host whose server refused the key can have a saved
    // password, and skipping it would drop a real secret from the transfer.
    await addHost('h1', authMethod: 'publicKey');
    await addHost('h2', authMethod: 'password');

    await read();

    expect(vault.asked, ['host/h1/password', 'host/h2/password']);
  });

  test('showing a code reads nothing at all', () async {
    // The reported problem: flipping "include keys and passwords" prompted for
    // the keychain, twice, before anything had been sent. Preparing a payload
    // must not touch the vault — only handing one over may.
    await addIdentity('k1', hasPassphrase: true);
    await addHost('h1', authMethod: 'publicKey');

    final payload = await TransferPayload.read(
      database.raw,
      includeSecrets: true,
    );

    expect(vault.asked, isEmpty);
    // And it still knows what it will be carrying, which is what the offer
    // shown on the other device is built from.
    expect(payload.includesSecrets, isTrue);
    expect(payload.hostCount, 1);
  });

  test('and nothing is read at all when secrets are left out', () async {
    await addIdentity('k1', hasPassphrase: true);
    await addHost('h1', authMethod: 'password');

    await (await TransferPayload.read(
      database.raw,
      includeSecrets: false,
    )).withSecrets(vault);

    expect(vault.asked, isEmpty);
  });

  test('the secrets that do exist still travel', () async {
    await addIdentity('k1', hasPassphrase: true);
    await addHost('h1', authMethod: 'password');
    await vault.write(SecretRef.identityPrivateKey('k1'), 'KEY');
    await vault.write(SecretRef.identityPassphrase('k1'), 'PHRASE');
    await vault.write(SecretRef.hostPassword('h1'), 'PASSWORD');

    final payload = await read();

    expect(payload.secrets, {
      'identity/k1/private': 'KEY',
      'identity/k1/passphrase': 'PHRASE',
      'host/h1/password': 'PASSWORD',
    });
  });
}
