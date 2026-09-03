import 'secret_ref.dart';

/// Raised when a secret cannot be read or written.
///
/// Deliberately carries no secret material and no underlying platform message:
/// keystore errors have been known to quote the value they choked on, and that
/// value is a private key. Callers get the [ref] and the [cause]'s *type*.
class SecretVaultException implements Exception {
  SecretVaultException(this.message, {this.ref, Object? cause, this.code})
    : causeType = cause?.runtimeType;

  final String message;
  final SecretRef? ref;

  /// The runtime type of what went wrong, never the error itself.
  final Type? causeType;

  /// A platform error *code*, when the store gave one — `-34018`, `Unexpected
  /// security result code`, and so on.
  ///
  /// Codes are carried but messages are not, and the distinction is
  /// deliberate: a keystore's message can quote the value it choked on, and
  /// that value is a private key. A code cannot, and without it a failure like
  /// a missing Keychain entitlement is indistinguishable from a corrupt store
  /// — which is a long afternoon.
  final String? code;

  @override
  String toString() =>
      'SecretVaultException: $message'
      '${ref == null ? '' : ' (${ref!.storageKey})'}'
      '${code == null ? '' : ' [$code]'}'
      '${code == null && causeType != null ? ' [$causeType]' : ''}';
}

/// The single way any secret is read, written or destroyed.
///
/// **Nothing else in the app touches a credential store.** Not the host
/// repository, not the connection layer, not the UI. That is the whole point
/// of this interface: the app has decided, for now, to sync secrets through
/// Appwrite's `encrypt` attribute — which the server can decrypt — and that
/// decision needs to be reversible without a rewrite. A client-sealed vault
/// (XChaCha20-Poly1305 under a passphrase-derived key, which the server cannot
/// open) is another implementation of exactly this interface. See
/// `docs/prior-art.md` § Credential storage.
///
/// Implementations must:
///
///  * return `null` for a missing secret rather than throwing — "no password
///    saved" is an ordinary state, not an error;
///  * treat [delete] of a missing secret as success, so purging is idempotent;
///  * never log, print or include secret values in an exception.
abstract interface class SecretVault {
  /// The secret at [ref], or null if none is stored.
  Future<String?> read(SecretRef ref);

  /// Stores [value] at [ref], replacing anything already there.
  Future<void> write(SecretRef ref, String value);

  /// Removes the secret at [ref]. Succeeds whether or not one was there.
  Future<void> delete(SecretRef ref);

  /// Whether a secret is stored at [ref].
  ///
  /// Separate from [read] so the UI can show "password saved" without pulling
  /// the password into memory — and, once a vault is biometric-gated, without
  /// prompting for a fingerprint just to render a list row.
  Future<bool> contains(SecretRef ref);

  /// Removes every secret in [refs].
  ///
  /// Used when a host or identity is deleted. Implemented here rather than
  /// left to callers because the failure mode of doing it by hand — forgetting
  /// the passphrase slot and leaving key material behind after the user
  /// believed it was gone — is silent.
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    for (final ref in refs) {
      await delete(ref);
    }
  }
}

/// A vault that keeps everything in memory and nothing on disk.
///
/// For tests, and for the deliberate "never save my credentials" mode: a user
/// who wants to be asked every time gets this, and the secret dies with the
/// process.
class InMemorySecretVault implements SecretVault {
  final Map<String, String> _values = {};

  /// How many secrets are held. For tests asserting a purge actually purged.
  int get length => _values.length;

  @override
  Future<String?> read(SecretRef ref) async => _values[ref.storageKey];

  @override
  Future<void> write(SecretRef ref, String value) async {
    _values[ref.storageKey] = value;
  }

  @override
  Future<void> delete(SecretRef ref) async {
    _values.remove(ref.storageKey);
  }

  @override
  Future<bool> contains(SecretRef ref) async =>
      _values.containsKey(ref.storageKey);

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    for (final ref in refs) {
      _values.remove(ref.storageKey);
    }
  }
}
