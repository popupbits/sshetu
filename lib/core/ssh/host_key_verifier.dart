import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'host_key.dart';
import 'known_hosts_store.dart';

/// Asked when a host presents a key this device has never seen.
///
/// Returning `true` trusts it from now on — trust on first use. Anything else
/// refuses the connection.
///
/// It is only ever called for [HostKeyVerdict.unknown]. A **changed** key is
/// never offered to the user as a yes/no.
typedef HostKeyTrustDecision =
    FutureOr<bool> Function(HostKeyPresentation presentation);

/// Decides whether to accept the host key a server presented.
///
/// The policy is deliberately the one OpenSSH uses:
///
///  * **known and matching** → accept silently.
///  * **unknown** → ask [onUnknownHostKey]. With no handler wired the answer
///    is *no*: an unattended connection never blindly trusts a new host.
///  * **changed** → refuse, always, without asking.
///
/// That last case is the one worth being stubborn about. A different key on an
/// address already pinned is the man-in-the-middle signal, and an interface
/// that lets a user tap through it with a "Trust anyway" button is not host
/// key verification — it is a dialog. The only way past it is to forget the
/// pin explicitly, from the known-hosts screen, having decided the host really
/// was rebuilt.
///
/// The verifier logs fingerprints and addresses only — never key material,
/// never a credential.
class SshHostKeyVerifier {
  SshHostKeyVerifier({
    required this.knownHosts,
    required this.hostname,
    required this.port,
    this.onUnknownHostKey,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final KnownHostsStore knownHosts;
  final String hostname;
  final int port;
  final HostKeyTrustDecision? onUnknownHostKey;
  final DateTime Function() _now;

  /// The most recent presentation.
  ///
  /// Kept because a refused connection surfaces from `dartssh2` as a generic
  /// handshake or auth abort. Without this the user would be told "handshake
  /// failed" when the truth is "that host's identity changed" — the single
  /// most important thing an SSH client ever has to say.
  HostKeyPresentation? lastPresentation;

  /// Classifies [fingerprint] without touching the store's write path or
  /// prompting. Exposed so the UI can show a verdict before connecting.
  HostKeyPresentation classify(String keyType, String fingerprint) {
    final known = knownHosts.find(hostname, port);
    final verdict = known == null
        ? HostKeyVerdict.unknown
        : (known.fingerprint == fingerprint && known.keyType == keyType
              ? HostKeyVerdict.trusted
              : HostKeyVerdict.changed);
    return HostKeyPresentation(
      hostname: hostname,
      port: port,
      keyType: keyType,
      fingerprint: fingerprint,
      verdict: verdict,
      known: known,
    );
  }

  /// The `dartssh2` callback.
  ///
  /// [fingerprintBytes] is the UTF-8 of the OpenSSH-style `SHA256:<base64>`
  /// fingerprint. Decoded with `allowMalformed` because a server controls
  /// these bytes and a malformed one must produce a refusal, not an exception
  /// thrown out of a handshake callback.
  Future<bool> verify(String keyType, Uint8List fingerprintBytes) async {
    final fingerprint = utf8.decode(fingerprintBytes, allowMalformed: true);
    final presentation = classify(keyType, fingerprint);
    lastPresentation = presentation;

    switch (presentation.verdict) {
      case HostKeyVerdict.trusted:
        return true;

      case HostKeyVerdict.changed:
        // Never prompted, never auto-accepted.
        return false;

      case HostKeyVerdict.unknown:
        final decide = onUnknownHostKey;
        // No handler wired means nobody is there to ask, and an unattended
        // connection must not trust a stranger on the user's behalf.
        if (decide == null) return false;

        final accepted = await decide(presentation);
        if (!accepted) return false;

        await knownHosts.trust(
          KnownHostKey(
            hostname: hostname,
            port: port,
            keyType: keyType,
            fingerprint: fingerprint,
            trustedAt: _now(),
          ),
        );
        return true;
    }
  }
}
