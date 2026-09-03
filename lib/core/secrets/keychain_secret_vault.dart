import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secret_ref.dart';
import 'secret_vault.dart';

/// The device-local [SecretVault], backed by the platform credential store:
/// Keychain on iOS and macOS, the Keystore-backed encrypted store on Android,
/// DPAPI on Windows, libsecret on Linux.
///
/// This is the vault in front of everything else. A secret is read from here
/// first and only fetched from the synced vault when it is missing, so the
/// common case — connecting to a host you use every day, on the device you
/// always use — never leaves the machine.
class KeychainSecretVault implements SecretVault {
  KeychainSecretVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
        mOptions: _macOsOptions,
      );

  final FlutterSecureStorage _storage;

  /// `resetOnError` is **off**, against the plugin's default.
  ///
  /// Upstream defaults it to true: if a stored value cannot be decrypted, wipe
  /// the store and carry on. For a login token that is the right trade — the
  /// user signs in again. Here the store holds SSH **private keys**, and
  /// silently destroying one because a keystore migration hiccuped loses
  /// something the user may not have a copy of. An error the user can see and
  /// act on is strictly better than data loss they find out about later.
  static const _androidOptions = AndroidOptions(resetOnError: false);

  /// `first_unlock_this_device`, chosen on two axes:
  ///
  ///  * **first_unlock**, not `unlocked`: a reconnect that happens while the
  ///    phone is in a pocket must be able to read the key. `unlocked` would
  ///    make every backgrounded session unrecoverable until the user looks at
  ///    the screen.
  ///  * **this_device**: these never enter the iCloud keychain or an iCloud
  ///    backup. Syncing is this app's own decision, made explicitly through
  ///    the synced vault; having Apple quietly replicate the same secrets by a
  ///    second route the user was never asked about is not acceptable.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// `usesDataProtectionKeychain` is **off**, against the plugin's default.
  ///
  /// macOS has two keychains. The data-protection one behaves like iOS and is
  /// what `MacOsOptions` selects by default — but it requires the app to be
  /// signed into a keychain access group, which requires `keychain-access-groups`,
  /// which requires a DEVELOPMENT_TEAM. Without one, every write fails with
  /// `PlatformException: Unexpected security result code`, sandboxed or not.
  /// That is not a dev-only annoyance: it is the failure a contributor hits on
  /// a fresh checkout, and it presents as "importing your keys is broken".
  ///
  /// The legacy file-based login keychain has no such requirement and works in
  /// both cases, so it is the one universal choice available here.
  ///
  /// If this app is ever submitted to the Mac App Store with a signing team,
  /// revisit: the data-protection keychain is the better home for secrets, but
  /// switching moves where items live, so existing users would need a
  /// migration rather than a flag flip.
  static const _macOsOptions = MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    usesDataProtectionKeychain: false,
  );

  @override
  Future<String?> read(SecretRef ref) async {
    try {
      return await _storage.read(key: ref.storageKey);
    } on Object catch (e) {
      throw SecretVaultException(
        'Could not read secret',
        ref: ref,
        cause: e,
        code: _codeOf(e),
      );
    }
  }

  @override
  Future<void> write(SecretRef ref, String value) async {
    try {
      await _storage.write(key: ref.storageKey, value: value);
    } on Object catch (e) {
      throw SecretVaultException(
        'Could not save secret',
        ref: ref,
        cause: e,
        code: _codeOf(e),
      );
    }
  }

  @override
  Future<void> delete(SecretRef ref) async {
    try {
      await _storage.delete(key: ref.storageKey);
    } on Object catch (e) {
      throw SecretVaultException(
        'Could not remove secret',
        ref: ref,
        cause: e,
        code: _codeOf(e),
      );
    }
  }

  @override
  Future<bool> contains(SecretRef ref) async {
    try {
      return await _storage.containsKey(key: ref.storageKey);
    } on Object catch (e) {
      throw SecretVaultException(
        'Could not read secret',
        ref: ref,
        cause: e,
        code: _codeOf(e),
      );
    }
  }

  /// The platform's error code, when there is one. Never its message.
  static String? _codeOf(Object error) =>
      error is PlatformException ? error.code : null;

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    // Deliberately not FlutterSecureStorage.deleteAll(), which empties the
    // entire store: this must remove one owner's secrets, not everyone's.
    for (final ref in refs) {
      await delete(ref);
    }
  }
}
