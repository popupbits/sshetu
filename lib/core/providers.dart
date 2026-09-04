import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'secrets/keychain_secret_vault.dart';
import 'secrets/secret_vault.dart';
import 'ssh/known_hosts_store.dart';
import '../features/hosts/data/host_repository.dart';
import '../features/keys/data/identity_repository.dart';
import '../features/tunnels/data/tunnel_repository.dart';

/// The one vault, and the only place a credential is ever stored.
///
/// There is no remote half and no signed-in variant: a password or a private
/// key lives in this device's keychain and is never uploaded anywhere. That
/// is a product decision, not an unfinished one — an app holding the keys to
/// someone's production infrastructure has no business asking to keep a copy
/// of them on a server it operates. Moving credentials to another device is
/// an explicit, one-shot transfer the user initiates; see `features/transfer`.
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

final tunnelRepositoryProvider = Provider<TunnelRepository>(
  (ref) => TunnelRepository(database: ref.watch(databaseProvider).raw),
);
