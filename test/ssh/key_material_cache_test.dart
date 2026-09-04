import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/key_material_cache.dart';
import 'package:sshetu/core/ssh/ssh_credentials.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';

/// A vault that counts reads.
///
/// On macOS each read of a keychain item can raise its own authorisation
/// prompt, so the number of reads is not an implementation detail — it is how
/// many times someone is interrupted to open one connection.
class _CountingVault extends InMemorySecretVault {
  final reads = <String>[];

  @override
  Future<String?> read(SecretRef ref) {
    reads.add(ref.storageKey);
    return super.read(ref);
  }
}

void main() {
  late _CountingVault vault;
  late KeyMaterialCache cache;

  const target = SshTarget(hostname: '10.0.0.1', username: 'root');

  Future<List<AvailableIdentity>> catalog() async => const [
    AvailableIdentity(
      id: 'k1',
      label: 'ed25519',
      keyType: 'ssh-ed25519',
      hasPassphrase: false,
    ),
    AvailableIdentity(
      id: 'k2',
      label: 'rsa',
      keyType: 'ssh-rsa',
      hasPassphrase: false,
    ),
  ];

  setUp(() async {
    vault = _CountingVault();
    cache = KeyMaterialCache();
    await vault.write(SecretRef.identityPrivateKey('k1'), 'KEY-ONE');
    await vault.write(SecretRef.identityPrivateKey('k2'), 'KEY-TWO');
  });

  VaultCredentialSource source() => VaultCredentialSource(
    vault: vault,
    catalog: catalog,
    keyCache: cache,
  );

  test('a host naming no key is offered every key, read once each', () async {
    final keys = await source().privateKeys(target);

    expect(keys, hasLength(2));
    expect(vault.reads, [
      'identity/k1/private',
      'identity/k2/private',
    ], reason: 'no passphrase slots: the rows say there are none');
  });

  test('a second connection reads nothing at all', () async {
    // The reported problem: connecting twice asked for the keychain twice as
    // many times, because the cache died with the first connection.
    await source().privateKeys(target);
    vault.reads.clear();

    final keys = await source().privateKeys(target);

    expect(keys, hasLength(2));
    expect(vault.reads, isEmpty);
  });

  test('a host that names its key costs one read, not two', () async {
    await source().privateKeys(
      target.copyWith(identityId: 'k1'),
    );

    expect(vault.reads, ['identity/k1/private']);
  });

  test('a replaced key is not served from the old copy', () async {
    await source().privateKeys(target);
    await vault.write(SecretRef.identityPrivateKey('k1'), 'REPLACED');
    cache.forget('k1');
    vault.reads.clear();

    final keys = await source().privateKeys(target);

    expect(vault.reads, ['identity/k1/private']);
    expect(
      keys.firstWhere((k) => k.identityId == 'k1').pem,
      'REPLACED',
    );
  });

  test('passwords are never cached', () async {
    // A key is a file the user stored; a password is something they typed,
    // and it must not outlive the attempt it was typed for.
    await vault.write(SecretRef.hostPassword('h1'), 'hunter2');
    const saved = SshTarget(
      hostname: '10.0.0.1',
      username: 'root',
      credentialId: 'h1',
    );

    await source().password(saved);
    vault.reads.clear();
    await source().password(saved);

    expect(vault.reads, ['host/h1/password']);
  });
}
