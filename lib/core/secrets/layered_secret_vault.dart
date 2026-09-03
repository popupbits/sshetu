import '../error/error_logger.dart';
import 'secret_ref.dart';
import 'secret_vault.dart';

/// Reads device-local first and only reaches the network when the local
/// vault has nothing, so the common case — connecting to a host you use
/// every day, on the device you always use — never touches Appwrite.
///
/// This is what callers actually get once a user signs in (wired in
/// `core/providers.dart`); [AppwriteSecretVault] is never handed to feature
/// code directly. See `docs/prior-art.md` § "Credential storage — decided,
/// with the tradeoff stated" for why a synced vault exists at all.
class LayeredSecretVault implements SecretVault {
  LayeredSecretVault({required this.local, required this.remote});

  final SecretVault local;
  final SecretVault remote;

  @override
  Future<String?> read(SecretRef ref) async {
    final localValue = await local.read(ref);
    if (localValue != null) return localValue;

    final remoteValue = await remote.read(ref);
    if (remoteValue != null) {
      // Warm the local copy so the *next* read on this device is local-only.
      // Without this, a device that fell back once would fall back on every
      // single read forever, which defeats the entire point of layering.
      // Best-effort: a cache write failing must not turn a successful read
      // into a thrown error.
      try {
        await local.write(ref, remoteValue);
      } on Object catch (e, st) {
        ErrorLogger.instance.record(e, st, source: 'sync.secrets');
      }
    }
    return remoteValue;
  }

  @override
  Future<void> write(SecretRef ref, String value) async {
    // Local-first: the write the user asked for must succeed even offline —
    // an SSH client that cannot save a password without a network connection
    // is worse than the one this app had before sync existed. The remote
    // copy is opportunistic. There is no retry queue for secrets in v1
    // (unlike rows, which retry automatically via `dirty`); the next
    // explicit write to this ref, or a future outbox, is what catches a
    // missed one up. That gap is recorded, not silent.
    await local.write(ref, value);
    try {
      await remote.write(ref, value);
    } on Object catch (e, st) {
      ErrorLogger.instance.record(e, st, source: 'sync.secrets');
    }
  }

  @override
  Future<void> delete(SecretRef ref) async {
    await local.delete(ref);
    try {
      await remote.delete(ref);
    } on Object catch (e, st) {
      ErrorLogger.instance.record(e, st, source: 'sync.secrets');
    }
  }

  @override
  Future<bool> contains(SecretRef ref) async =>
      await local.contains(ref) || await remote.contains(ref);

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    final list = refs.toList(growable: false);
    await local.deleteAll(list);
    try {
      await remote.deleteAll(list);
    } on Object catch (e, st) {
      ErrorLogger.instance.record(e, st, source: 'sync.secrets');
    }
  }
}
