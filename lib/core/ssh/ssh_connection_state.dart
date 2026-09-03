/// Where a connection is in its lifecycle.
enum SshConnectionStatus {
  /// Nothing has been attempted yet.
  idle,

  /// A socket is open or a handshake is in progress.
  connecting,

  /// Authenticated, with a usable session.
  connected,

  /// The link was lost. A retry may recover it.
  disconnected,

  /// Gave up, or failed for a reason retrying cannot fix — a refused host key,
  /// a rejected credential.
  failed,
}

/// A connection's current state, and why.
class SshConnectionState {
  const SshConnectionState({
    required this.status,
    this.error,
    this.attempt = 0,
    this.nextRetryIn,
  });

  const SshConnectionState.idle() : this(status: SshConnectionStatus.idle);

  final SshConnectionStatus status;

  /// User-facing explanation. Never contains a credential or key material.
  final String? error;

  /// How many attempts have already failed.
  final int attempt;

  /// How long until the next attempt, when one is scheduled. Shown as a
  /// countdown rather than a spinner, so a reconnect that is waiting looks
  /// different from one that is stuck.
  final Duration? nextRetryIn;

  bool get isConnected => status == SshConnectionStatus.connected;
  bool get isBusy => status == SshConnectionStatus.connecting;

  @override
  bool operator ==(Object other) =>
      other is SshConnectionState &&
      other.status == status &&
      other.error == error &&
      other.attempt == attempt &&
      other.nextRetryIn == nextRetryIn;

  @override
  int get hashCode => Object.hash(status, error, attempt, nextRetryIn);

  @override
  String toString() =>
      'SshConnectionState($status${error == null ? '' : ', $error'})';
}

/// How long to wait before retry [attempt].
///
/// Exponential with a ceiling: a phone that has walked out of Wi-Fi range
/// should retry quickly at first, because the network usually comes back in
/// seconds, and then back off rather than burning the battery hammering a
/// host that is genuinely down.
Duration reconnectBackoff(int attempt) {
  const base = Duration(milliseconds: 500);
  const ceiling = Duration(seconds: 30);
  final scaled = base * (1 << (attempt.clamp(0, 6)));
  return scaled > ceiling ? ceiling : scaled;
}
