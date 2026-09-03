import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appwrite/client.dart';
import 'db/database.dart';
import 'secrets/appwrite_secret_vault.dart';
import 'secrets/keychain_secret_vault.dart';
import 'secrets/layered_secret_vault.dart';
import 'secrets/secret_remote.dart';
import 'secrets/secret_vault.dart';
import 'ssh/known_hosts_store.dart';
import '../features/auth/auth_controller.dart';
import '../features/hosts/data/host_repository.dart';
import '../features/keys/data/identity_repository.dart';
import '../features/tunnels/data/tunnel_repository.dart';

/// The device-local vault, always available regardless of sign-in state.
///
/// One instance for the app: `flutter_secure_storage` is cheap to construct
/// but a single vault is what a future biometric gate needs, so that one
/// unlock covers the app rather than one per screen that happened to build its
/// own.
final _localSecretVaultProvider = Provider<SecretVault>(
  (ref) => KeychainSecretVault(),
);

/// The vault every repository actually uses.
///
/// Signed out — the default, and the only state an app with no account ever
/// sees — this is exactly [_localSecretVaultProvider] and nothing else is
/// even constructed: no `AppwriteSecretVault`, no network-capable object
/// exists to accidentally be reached from. Signed in, it layers a synced
/// vault behind the local one via [LayeredSecretVault], local-first. See
/// `docs/prior-art.md` § "Credential storage — decided, with the tradeoff
/// stated".
final secretVaultProvider = Provider<SecretVault>((ref) {
  final local = ref.watch(_localSecretVaultProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return local;

  return LayeredSecretVault(
    local: local,
    remote: AppwriteSecretVault(
      remote: AppwriteSecretRemote(appwrite: ref.watch(appwriteProvider)),
      userId: user.$id,
    ),
  );
});

/// Trusted host keys, loaded into memory once.
///
/// Async because the first read fills the cache from SQLite, and the verifier
/// that consults it runs inside `dartssh2`'s handshake callback where awaiting
/// a database round trip would risk the handshake timing out.
final knownHostsProvider = FutureProvider<KnownHostsStore>((ref) async {
  final store = SqfliteKnownHostsStore(ref.watch(databaseProvider).raw);
  await store.load();
  return store;
});

final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepository(
    database: ref.watch(databaseProvider).raw,
    vault: ref.watch(secretVaultProvider),
  ),
);

final identityRepositoryProvider = Provider<IdentityRepository>(
  (ref) => IdentityRepository(
    database: ref.watch(databaseProvider).raw,
    vault: ref.watch(secretVaultProvider),
  ),
);

final tunnelRepositoryProvider = Provider<TunnelRepository>(
  (ref) => TunnelRepository(database: ref.watch(databaseProvider).raw),
);
