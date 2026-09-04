import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/keys/keys_controller.dart';

import '../support/test_database.dart';

/// A vault that refuses to erase anything.
///
/// Exactly what macOS does when the login keychain will not let this build
/// remove an item: the delete throws, and everything after it never runs.
class _RefusingVault extends InMemorySecretVault {
  @override
  Future<void> delete(SecretRef ref) async =>
      throw SecretVaultException('Could not remove secret', ref: ref);

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    for (final ref in refs) {
      await delete(ref);
    }
  }
}

/// Deleting something must remove it from the list, even when the credential
/// store will not co-operate.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    database = await openTestDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(_RefusingVault()),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async => database.raw.close());

  Future<void> addKey() => database.raw.insert('identities', {
    'id': 'k1',
    'label': 'laptop',
    'key_type': 'ssh-ed25519',
    'has_passphrase': 0,
    'origin': 'generated',
    'created_at': now,
    'updated_at': now,
  });

  test('a key leaves the list even if the keychain refuses', () async {
    await addKey();
    expect(await container.read(identitiesProvider.future), hasLength(1));

    // The reported bug: the row was tombstoned, the vault threw, and the
    // refresh that came after it never ran — so the key stayed on screen
    // until the app was restarted.
    await expectLater(
      container.read(identitiesControllerProvider).delete('k1'),
      throwsA(isA<SecretVaultException>()),
    );

    expect(
      await container.read(identitiesProvider.future),
      isEmpty,
      reason: 'the list must agree with the database',
    );
  });

  test('and so does a host', () async {
    await database.raw.insert('hosts', {
      'id': 'h1',
      'label': 'server',
      'hostname': '10.0.0.1',
      'port': 22,
      'username': 'root',
      'auth_method': 'password',
      'allow_legacy_algorithms': 0,
      'keepalive_seconds': 30,
      'created_at': now,
      'updated_at': now,
    });
    expect(await container.read(hostsProvider.future), hasLength(1));

    await expectLater(
      container.read(hostsControllerProvider).delete('h1'),
      throwsA(isA<SecretVaultException>()),
    );

    expect(await container.read(hostsProvider.future), isEmpty);
  });

  test('the failure is still reported, not swallowed', () async {
    // Being told "this is gone" while the private key is still in the
    // keychain would be the worse bug of the two.
    await addKey();

    await expectLater(
      container.read(identitiesControllerProvider).delete('k1'),
      throwsA(isA<SecretVaultException>()),
    );
  });
}
