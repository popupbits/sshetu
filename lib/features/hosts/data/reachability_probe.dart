import 'dart:async';
import 'dart:io';

import '../domain/reachability.dart';

/// Checks whether something answers at an address.
abstract interface class ReachabilityProbe {
  Future<ProbeOutcome> probe(ProbeAddress address);
}

/// Opens a TCP connection, matching `Socket.connect`, so tests can hand in
/// their own.
typedef SocketConnector = Future<Socket> Function(
  String host,
  int port, {
  Duration? timeout,
});

/// A plain TCP connect, closed the moment it succeeds.
///
/// **Never an SSH handshake.** No version string is sent and nothing is
/// authenticated, so no probe can count as a failed login: the server sees a
/// connection open and close, and that is all. The latency reported is the
/// connect time — one round trip plus the name lookup — which is what the
/// user feels as "is it slow right now", without asking the server to do any
/// work.
class TcpReachabilityProbe implements ReachabilityProbe {
  const TcpReachabilityProbe({
    this.timeout = const Duration(seconds: 3),
    this.connect = Socket.connect,
  });

  /// How long a connect may take before the address counts as down.
  final Duration timeout;

  final SocketConnector connect;

  /// Extra time past [timeout] before giving up on a connect that has not
  /// settled — a name lookup can hang outside the socket's own timeout.
  static const Duration _grace = Duration(seconds: 1);

  @override
  Future<ProbeOutcome> probe(ProbeAddress address) async {
    final stopwatch = Stopwatch()..start();
    final pending = connect(address.hostname, address.port, timeout: timeout);
    try {
      final socket = await pending.timeout(timeout + _grace);
      stopwatch.stop();
      // destroy, not close: there is nothing to flush and no reason to wait
      // for the far side to acknowledge anything.
      socket.destroy();
      return ProbeOutcome.up(stopwatch.elapsed);
    } on TimeoutException {
      // The connect may still land later; it must not be left open.
      unawaited(pending.then((s) => s.destroy(), onError: (Object _) {}));
      return const ProbeOutcome.down(ReachabilityFailure.timedOut);
    } on SocketException catch (error) {
      return ProbeOutcome.down(classify(error));
    } on Object {
      return const ProbeOutcome.down(ReachabilityFailure.unreachable);
    }
  }

  /// Error codes for "connection refused": Linux and Android, macOS and iOS,
  /// and Windows.
  static const _refused = {111, 61, 10061};

  /// Error codes for "timed out" from the operating system rather than from
  /// `Socket.connect`'s own timer.
  static const _timedOut = {110, 60, 10060};

  /// Why a connect failed, from what `dart:io` threw.
  static ReachabilityFailure classify(SocketException error) {
    final code = error.osError?.errorCode;
    if (code != null && _refused.contains(code)) {
      return ReachabilityFailure.refused;
    }
    if (code != null && _timedOut.contains(code)) {
      return ReachabilityFailure.timedOut;
    }
    final message = error.message.toLowerCase();
    if (message.contains('host lookup')) return ReachabilityFailure.unresolved;
    // `Socket.connect(timeout:)` throws with no OS error when its own timer
    // fires.
    if (message.contains('timed out')) return ReachabilityFailure.timedOut;
    if (message.contains('refused')) return ReachabilityFailure.refused;
    return ReachabilityFailure.unreachable;
  }
}
