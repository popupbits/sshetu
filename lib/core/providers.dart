import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'secrets/keychain_secret_vault.dart';
import 'secrets/secret_vault.dart';
import 'ssh/known_hosts_store.dart';
import '../features/hosts/data/host_repository.dart';
import '../features/keys/data/identity_repository.dart';

/// The device-local vault.
///
/// One instance for the app: `flutter_secure_storage` is cheap to construct
/// but a single vault is what a future biometric gate needs, so that one
/// unlock covers the app rather than one per screen that happened to build its
/// own.
final secretVaultProvider = Provider<SecretVault>(
  (ref) => KeychainSecretVault(),
);

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
