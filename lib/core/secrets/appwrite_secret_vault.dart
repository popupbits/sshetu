import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'secret_ref.dart';
import 'secret_remote.dart';
import 'secret_vault.dart';

/// [SecretVault] backed by Appwrite's `encrypt` string attribute.
///
/// **Read this before touching it.** `encrypt` is encrypted at rest with the
/// *server's* key, not the user's — Appwrite itself can decrypt it, so anyone
/// with the instance's `_APP_OPENSSL_KEY_V1` and database access (an
/// operator, a backup, a breach) can read every SSH password and private key
/// stored here. That tradeoff was raised and accepted deliberately; see
/// `docs/prior-art.md` § "Credential storage — decided, with the tradeoff
/// stated". The alternative was a client-sealed vault (XChaCha20-Poly1305
/// under an Argon2id-derived key) the server cannot open, declined for the
/// recovery and first-device-login complexity it adds. If that decision is
/// ever revisited, this is the one class that changes — everything else
/// reaches secrets only through [SecretVault].
///
/// Two consequences of `encrypt` worth knowing before you extend this:
///
///  * Appwrite caps a string attribute's stored size at 65535 bytes —
///    comfortably above an OpenSSH private key or passphrase, but nothing
///    enforces that headroom before this class does, so [write] checks it
///    explicitly rather than letting an oversized key fail deep inside the
///    SDK with a message that does not say why.
///  * An `encrypt` attribute **cannot be queried or indexed**. Every call
///    here is a get/set by id, never a list or filter — which happens to be
///    exactly the shape [SecretVault] already has, so this is not a
///    limitation this class has to work around.
///
/// There is also no conflict resolution here, unlike the row sync in
/// `core/sync/`: [SecretRef] carries no `updated_at`, so there is nothing to
/// compare, and the last device to write a given secret simply wins. That
/// matches every other [SecretVault] implementation, none of which version
/// their values either.
///
/// Not constructed by feature code directly — [LayeredSecretVault] is what
/// callers actually get (wired in `core/providers.dart`), so nothing outside
/// `core/secrets/` needs to know this exists.
class AppwriteSecretVault implements SecretVault {
  AppwriteSecretVault({required this.remote, required this.userId});

  final SecretRemote remote;
  final String userId;

  /// Appwrite's documented ceiling for a string attribute's value.
  static const maxValueBytes = 65535;

  @override
  Future<String?> read(SecretRef ref) async {
    try {
      return await remote.read(_rowId(ref));
    } on Object catch (e) {
      throw SecretVaultException('Could not read secret', ref: ref, cause: e);
    }
  }

  @override
  Future<void> write(SecretRef ref, String value) async {
    // .length counts UTF-16 code units, not bytes — an acceptable stand-in
    // here because every value this vault ever stores (PEM/OpenSSH key
    // material, a passphrase, a host password) is ASCII.
    if (value.length > maxValueBytes) {
      throw SecretVaultException(
        'Secret is too large to sync (${value.length} bytes, '
        'max $maxValueBytes)',
        ref: ref,
      );
    }
    try {
      await remote.write(
        _rowId(ref),
        value: value,
        ownerId: ref.ownerId,
        kind: ref.kind.slot,
        userId: userId,
      );
    } on Object catch (e) {
      throw SecretVaultException('Could not save secret', ref: ref, cause: e);
    }
  }

  @override
  Future<void> delete(SecretRef ref) async {
    try {
      await remote.delete(_rowId(ref));
    } on Object catch (e) {
      throw SecretVaultException('Could not remove secret', ref: ref, cause: e);
    }
  }

  @override
  Future<bool> contains(SecretRef ref) async {
    try {
      return await remote.exists(_rowId(ref));
    } on Object catch (e) {
      throw SecretVaultException('Could not read secret', ref: ref, cause: e);
    }
  }

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    for (final ref in refs) {
      await delete(ref);
    }
  }

  /// Appwrite row ids allow only letters, digits, `.`, `-` and `_`, capped at
  /// 36 characters. [SecretRef.storageKey] is neither — it has slashes, and
  /// `identity/<uuid>/private` alone can run past 50 characters — so the row
  /// id is a truncated SHA-256 of the key rather than the key itself. That
  /// makes a row unreadable by inspection from the Appwrite console, which is
  /// why [SecretRemote.write] also stores `owner_id` and `kind` as plain
  /// (non-`encrypt`) attributes: enough to identify a row by hand without the
  /// secret value itself ever being queryable.
  static String _rowId(SecretRef ref) =>
      sha256.convert(utf8.encode(ref.storageKey)).toString().substring(0, 32);
}
