/// A host key the user has told this device to trust for one `host:port`.
///
/// The stored value is the OpenSSH-style `SHA256:<base64>` fingerprint, not
/// the key: it is all that is needed to detect a substituted key, and it is
/// safe to show the user verbatim.
class KnownHostKey {
  const KnownHostKey({
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.trustedAt,
  });

  final String hostname;
  final int port;

  /// SSH key algorithm, e.g. `ssh-ed25519`.
  final String keyType;

  /// `SHA256:<base64>` — the same form `ssh-keygen -lf` prints, so a user can
  /// compare it against what the server told them without conversion.
  final String fingerprint;

  final DateTime trustedAt;

  @override
  bool operator ==(Object other) =>
      other is KnownHostKey &&
      other.hostname == hostname &&
      other.port == port &&
      other.keyType == keyType &&
      other.fingerprint == fingerprint &&
      other.trustedAt == trustedAt;

  @override
  int get hashCode =>
      Object.hash(hostname, port, keyType, fingerprint, trustedAt);

  @override
  String toString() => 'KnownHostKey($hostname:$port, $keyType, $fingerprint)';
}

/// What checking a presented host key against the known-hosts store concluded.
enum HostKeyVerdict {
  /// The fingerprint matches the one already trusted for this `host:port`.
  trusted,

  /// Nothing is stored for this `host:port` yet — trust-on-first-use
  /// territory, which requires an explicit decision from the user.
  unknown,

  /// A key **is** stored and the server presented a different one. This is the
  /// man-in-the-middle signal. It is never auto-accepted and never prompted
  /// for as a yes/no.
  changed,
}

/// The host key a server presented, together with the verdict.
class HostKeyPresentation {
  const HostKeyPresentation({
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.verdict,
    this.known,
  });

  final String hostname;
  final int port;
  final String keyType;
  final String fingerprint;
  final HostKeyVerdict verdict;

  /// The previously trusted key, when one exists.
  final KnownHostKey? known;

  /// A message safe to show the user and to log. Fingerprints only — never key
  /// material, never a credential.
  String describe() => switch (verdict) {
    HostKeyVerdict.trusted =>
      'Host key for $hostname:$port matches the trusted $keyType key.',
    HostKeyVerdict.unknown =>
      'The authenticity of $hostname:$port cannot be established. '
          'Its $keyType key fingerprint is $fingerprint.',
    HostKeyVerdict.changed =>
      'REMOTE HOST IDENTIFICATION HAS CHANGED for $hostname:$port. '
          'Expected ${known?.keyType} ${known?.fingerprint}, '
          'got $keyType $fingerprint. Someone could be eavesdropping right '
          'now (man-in-the-middle attack), or the host was legitimately '
          'rebuilt. The connection was refused.',
  };
}

/// Raised when a connection is refused because the host key could not be
/// trusted.
///
/// Distinct from an authentication failure: this is an *identity* failure, and
/// the user has to resolve it deliberately rather than by retyping a password.
class HostKeyRejected implements Exception {
  const HostKeyRejected(this.presentation);

  final HostKeyPresentation presentation;

  HostKeyVerdict get verdict => presentation.verdict;

  @override
  String toString() => 'HostKeyRejected: ${presentation.describe()}';
}
