import 'dart:async';

import 'package:dartssh2/dartssh2.dart';

/// Whether anything accepts connections at a forward's target, as seen from
/// the server.
enum FarEndStatus {
  /// The server opened a connection to the target.
  listening,

  /// The server tried and the target refused: nothing is listening there.
  notListening,

  /// No answer either way — a timeout, forwarding refused by the server's
  /// policy, a dropped link. Shown as nothing rather than as a guess.
  unknown,
}

/// SSH_OPEN_CONNECT_FAILED (RFC 4254 §5.1): the server could not connect to
/// the target — for OpenSSH, a refused or unreachable port.
const int _openConnectFailed = 2;

/// Asks the server to connect to a forward's target and hangs up at once.
///
/// [open] opens one `direct-tcpip` channel to the target — the same request
/// a forwarded connection makes, so the answer is exactly whether a real
/// connection would get through. It is closed the moment it opens and no
/// byte is sent. It never passes through a runner's accept path, so it is
/// not an active connection and no connection count ever includes it.
///
/// A channel that opens after [timeout] is still closed when it arrives.
Future<FarEndStatus> probeFarEnd(
  Future<SSHSocket> Function() open, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final attempt = open();
  try {
    final channel = await attempt.timeout(timeout);
    channel.destroy();
    return FarEndStatus.listening;
  } on SSHChannelOpenError catch (e) {
    return e.code == _openConnectFailed
        ? FarEndStatus.notListening
        : FarEndStatus.unknown;
  } on TimeoutException {
    unawaited(attempt.then((late) => late.destroy(), onError: (Object _) {}));
    return FarEndStatus.unknown;
  } on Object {
    return FarEndStatus.unknown;
  }
}
