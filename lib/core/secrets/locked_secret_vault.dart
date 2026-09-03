import 'dart:async';

import 'secret_ref.dart';
import 'secret_vault.dart';

/// Asks the device to confirm the user is present — fingerprint, face, or the
/// device PIN/password as a fallback. Returns whether it succeeded.
///
/// Injected rather than calling `local_auth` directly so this whole policy is
/// testable without a device, and so a desktop build that has no biometrics
/// can supply a different presence check without changing the vault.
typedef PresenceCheck = Future<bool> Function(String reason);

/// A monotonic clock. Injected so the grace period can be tested exactly
/// rather than by waiting.
typedef MonotonicClock = Duration Function();

/// Raised when the user could not, or would not, prove presence.
///
/// Distinct from [SecretVaultException]: nothing is wrong with the store, the
/// user simply did not unlock it. The UI says "unlock to connect", not
/// "something went wrong".
class VaultLockedException implements Exception {
  const VaultLockedException(this.message);

  final String message;

  @override
  String toString() => 'VaultLockedException: $message';
}

/// Wraps a [SecretVault] so that **reading** a secret requires the user to be
/// present.
///
/// Three deliberate choices:
///
///  * **Only reads are gated.** [contains] is not, so a host list can show
///    "password saved" without a fingerprint prompt per row — the whole reason
///    [SecretVault.contains] exists. [write] is not either: the user is
///    handing over a secret they already have, and prompting for a fingerprint
///    to accept it protects nothing.
///  * **An unlock lasts [gracePeriod].** Prompting once per connection is
///    security; prompting once per key, per host, per reconnect is a tax the
///    user pays by turning the feature off. The window is short and is reset
///    by [lock], which the app calls when it goes to the background.
///  * **It is never on by default.** Constructing this vault is a choice the
///    user makes in settings. A biometric prompt the user did not ask for, on
///    an app they need in a hurry, is how people end up locked out of their
///    own servers — which is why the presence check must also accept the
///    device PIN, not biometrics alone.
class LockedSecretVault implements SecretVault {
  LockedSecretVault({
    required SecretVault inner,
    required PresenceCheck presenceCheck,
    this.gracePeriod = const Duration(minutes: 5),
    MonotonicClock? clock,
    // Both fields stay private, so the lint's suggestion is declined
    // deliberately: an initialising formal would make them `inner` and
    // `presenceCheck` on the public surface, and a caller could then reach
    // straight past the gate with `vault.inner.read(ref)`. A lock with a
    // public handle on the thing it locks is not a lock.
    // ignore: prefer_initializing_formals
  }) : _inner = inner,
       // ignore: prefer_initializing_formals
       _presenceCheck = presenceCheck,
       _clock = clock ?? _defaultClock;

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static Duration _defaultClock() => _stopwatch.elapsed;

  final SecretVault _inner;
  final PresenceCheck _presenceCheck;
  final MonotonicClock _clock;

  /// How long one successful unlock keeps the vault open.
  final Duration gracePeriod;

  Duration? _unlockedAt;

  /// A single in-flight unlock, so several secrets read at once during one
  /// connection raise one prompt rather than a queue of them.
  Future<void>? _unlocking;

  /// Whether a read would go through right now without prompting.
  bool get isUnlocked {
    final at = _unlockedAt;
    if (at == null) return false;
    return _clock() - at < gracePeriod;
  }

  /// Closes the vault, so the next read prompts again.
  ///
  /// Call this when the app is backgrounded or locked. An unlocked vault left
  /// open in the app switcher is an unlocked vault in someone else's hands.
  void lock() {
    _unlockedAt = null;
  }

  Future<void> _requirePresence() {
    if (isUnlocked) return Future.value();
    return _unlocking ??= _authenticate().whenComplete(() {
      _unlocking = null;
    });
  }

  Future<void> _authenticate() async {
    final bool ok;
    try {
      ok = await _presenceCheck('Unlock your saved SSH credentials');
    } on Object catch (e) {
      // A platform that cannot ask must not silently hand the secret over.
      throw VaultLockedException(
        'The device could not verify it is you (${e.runtimeType}).',
      );
    }
    if (!ok) {
      throw const VaultLockedException(
        'Unlock was cancelled, so the credential was not read.',
      );
    }
    _unlockedAt = _clock();
  }

  @override
  Future<String?> read(SecretRef ref) async {
    await _requirePresence();
    return _inner.read(ref);
  }

  @override
  Future<void> write(SecretRef ref, String value) => _inner.write(ref, value);

  @override
  Future<void> delete(SecretRef ref) => _inner.delete(ref);

  @override
  Future<bool> contains(SecretRef ref) => _inner.contains(ref);

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) => _inner.deleteAll(refs);
}
