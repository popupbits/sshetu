import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/config/app_config.dart';
import 'package:sshetu/core/secrets/keychain_secret_vault.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';

/// The keychain keys a build files secrets under.
///
/// Release must use exactly the keys every existing install's secrets are
/// already stored under — a change here would leave every saved password and
/// private key unreadable after an update. Debug must use different ones, so
/// even a store shared by both builds (the macOS login keychain) never hands
/// a debug build the real app's keys.
void main() {
  late Map<String, String> store;

  setUp(() {
    store = {};
    FlutterSecureStorage.setMockInitialValues(store);
  });

  const ref = SecretRef.identityPrivateKey('k1');

  test('release stores under the bare SecretRef key, unchanged', () async {
    final vault = KeychainSecretVault(identity: AppIdentity.release);
    await vault.write(ref, 'pem');

    expect(store.keys, ['identity/k1/private']);
    expect(
      KeychainSecretVault.storageKeyFor(ref, AppIdentity.release),
      ref.storageKey,
    );
  });

  test('debug stores under its own prefix', () async {
    final vault = KeychainSecretVault(identity: AppIdentity.debug);
    await vault.write(ref, 'pem');

    expect(store.keys, ['sshetu-debug.identity/k1/private']);
  });

  test('debug cannot see, overwrite or delete a release secret', () async {
    final release = KeychainSecretVault(identity: AppIdentity.release);
    final debug = KeychainSecretVault(identity: AppIdentity.debug);
    await release.write(ref, 'real key');

    expect(await debug.read(ref), isNull);
    expect(await debug.contains(ref), isFalse);

    await debug.write(ref, 'test key');
    await debug.deleteAll([ref]);

    expect(await release.read(ref), 'real key');
  });
}
