import 'package:dartssh2/dartssh2.dart';

import '../secrets/locked_secret_vault.dart';
import 'host_key.dart';
import 'ssh_connection.dart';

/// Why a session stopped, as far as reconnecting is concerned.
///
/// Coarser than the error that caused it on purpose: the only question asked
/// of it is "would trying again help?", and a dozen socket errors all answer
/// that the same way.
enum DisconnectReason {
  /// The user closed the tab or chose Disconnect. Their decision stands.
  userInitiated,

  /// The host key was refused. Retrying would either nag or, for a changed
  /// key, keep knocking on a door that may belong to someone else.
  hostKeyRejected,

  /// The server rejected the credential, or the user declined a prompt, the
  /// credential lock, or a keyboard-interactive challenge. The same answer
  /// would be rejected again.
  authenticationFailed,

  /// The remote shell ended by itself — it sent an exit status, which is what
  /// happens when someone types `exit`. The link was fine; the program ended.
  remoteExited,

  /// The socket dropped, the server stopped answering, a keepalive went
  /// unanswered, the network went away. The case this whole feature exists
  /// for.
  network,
}

/// When to reconnect a dropped session, and whether to at all.
///
/// Pure: no timers, no clock, no Flutter. The session layer asks it two
/// questions — [shouldReconnect] and [delayBefore] — and does the waiting
/// itself, which is what lets both be tested exactly.
class ReconnectPolicy {
  const ReconnectPolicy({
    this.ramp = const [
      Duration(milliseconds: 1500),
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 8),
    ],
    this.steady = const Duration(seconds: 10),
    this.patience = const Duration(minutes: 3),
    this.slow = const Duration(seconds: 30),
  });

  /// The first few waits. Short, because a phone that walked out of Wi-Fi
  /// range or dropped a cell usually has a network again within seconds.
  final List<Duration> ramp;

  /// The wait once [ramp] is used up, for as long as [patience] lasts.
  final Duration steady;

  /// How long to keep retrying at [steady] before settling for [slow].
  final Duration patience;

  /// The wait after [patience]: indefinitely, because a laptop closed over a
  /// weekend should still come back on Monday — just without spending the
  /// battery hammering a host that is not there.
  final Duration slow;

  /// Whether a session that stopped for [reason] should come back by itself.
  bool shouldReconnect(DisconnectReason reason) =>
      reason == DisconnectReason.network;

  /// How long to wait before attempt number [attempt] (zero-based), given
  /// the session has been trying to come back for [elapsed].
  ///
  /// 1.5 s, 3 s, 5 s, 8 s, then 10 s until three minutes have gone by, then
  /// every 30 s.
  Duration delayBefore(int attempt, {required Duration elapsed}) {
    if (elapsed >= patience) return slow;
    if (attempt < ramp.length) return ramp[attempt < 0 ? 0 : attempt];
    return steady;
  }

  /// What a failed connection attempt means for reconnecting.
  ///
  /// Walks the whole cause chain rather than trusting the outermost error.
  /// dartssh2 wraps anything thrown from inside authentication — a declined
  /// password prompt, a locked vault — as an internal error inside an
  /// "authentication aborted" error, which [SshConnection] then reports as a
  /// retryable handshake failure. Taken at face value, a user who cancelled
  /// a password dialog would get the same dialog back every ten seconds.
  static DisconnectReason classify(Object error) {
    var sawNonRetryable = false;
    Object? current = error;
    // Bounded: a cause chain is a handful deep, and a cycle must not hang.
    for (var depth = 0; current != null && depth < 16; depth++) {
      switch (current) {
        case HostKeyRejected():
        case SSHHostkeyError():
          return DisconnectReason.hostKeyRejected;
        case VaultLockedException():
        case SSHAuthFailError():
          return DisconnectReason.authenticationFailed;
        case SshConnectionException(:final retryable, :final cause):
          if (!retryable) sawNonRetryable = true;
          current = cause;
        case SSHAuthAbortError(:final reason):
          current = reason;
        case SSHInternalError(error: final inner):
          current = inner;
        case SSHSocketError():
          return sawNonRetryable
              ? DisconnectReason.authenticationFailed
              : DisconnectReason.network;
        default:
          current = null;
      }
    }
    // A failure [SshConnection] itself judged hopeless — a missing key, no
    // password supplied — is a configuration problem, not a network one.
    return sawNonRetryable
        ? DisconnectReason.authenticationFailed
        : DisconnectReason.network;
  }
}
