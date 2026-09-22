import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'secrets/app_lock.dart';
import 'secrets/device_authenticator.dart';
import 'secrets/keychain_secret_vault.dart';
import 'secrets/locked_secret_vault.dart';
import 'secrets/secret_vault.dart';
import 'settings/settings_controller.dart';
import 'ssh/key_material_cache.dart';
import 'ssh/known_hosts_store.dart';
import '../features/hosts/data/host_group_repository.dart';
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
///
/// **The credential lock.** With `requireUnlock` on in Settings, the keychain
/// is wrapped in a [LockedSecretVault]: reading a secret — which is to say,
/// connecting with a saved password or key — first asks for a fingerprint,
/// face or the device PIN. Listing hosts and saving secrets do not ask; see
/// that class for why. Toggling the setting rebuilds this provider, so the
/// repositories and every caller reading it next get the new vault.
///
/// The lock closes when the app is hidden (backgrounded, minimised), and the
/// shared cache of decoded private keys is emptied with it. Without that, a
/// key read once would keep connecting for the rest of the run without asking
/// again, and the lock would guard only the first connection.
final secretVaultProvider = Provider<SecretVault>((ref) {
  final keychain = ref.watch(keychainSecretVaultProvider);
  final locked = ref.watch(
    settingsControllerProvider.select((s) => s.requireUnlock),
  );
  if (!locked) return keychain;

  final authenticator = ref.watch(deviceAuthenticatorProvider);
  final reason = appLocalizationsFor(
    ref.watch(settingsControllerProvider.select((s) => s.localeCode)),
  ).appLockUnlockReason;
  final keyCache = ref.read(keyMaterialCacheProvider);

  // Keys decoded before the lock was turned on must not walk around it.
  keyCache.clear();

  final vault = LockedSecretVault(
    inner: keychain,
    // The vault's own reason is English and fixed; the prompt shows ours.
    presenceCheck: (_) async =>
        await authenticator.authenticate(reason) == DeviceAuthResult.success,
  );

  final lifecycle = AppLifecycleListener(
    onHide: () {
      vault.lock();
      keyCache.clear();
    },
  );
  ref.onDispose(lifecycle.dispose);

  return vault;
});

/// The platform credential store itself, unwrapped.
///
/// Read [secretVaultProvider] instead. This exists so the lock can wrap it and
/// tests can swap it; anything else reading it would bypass the lock.
final keychainSecretVaultProvider = Provider<SecretVault>(
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

final hostGroupRepositoryProvider = Provider<HostGroupRepository>(
  (ref) => HostGroupRepository(database: ref.watch(databaseProvider).raw),
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
