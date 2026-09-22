import 'dart:io';

/// Whether this device could listen on [port] on loopback right now.
typedef PortProbe = Future<bool> Function(int port);

/// Picks the local port an ad-hoc forward listens on: [preferred] itself
/// when it is free — `localhost:3000` for a server's port 3000 is what
/// someone expects to type — otherwise the next free one after it.
///
/// Tries at most [attempts] ports. Null when none of them is free; the
/// caller then asks the operating system for any port (bind to 0) rather
/// than failing, since a forward on an unexpected port beats no forward.
/// Ports below 1024 usually need privileges a client app does not have, so
/// on most systems a request for 80 lands on 81 or later — which is the
/// same rule applied, not a special case.
Future<int?> pickLocalPort(
  int preferred, {
  PortProbe canBind = canBindLoopback,
  int attempts = 20,
}) async {
  for (var i = 0; i < attempts; i++) {
    final port = preferred + i;
    if (port < 1 || port > 65535) break;
    if (await canBind(port)) return port;
  }
  return null;
}

/// Binds and immediately releases [port] on IPv4 loopback — the address an
/// ad-hoc forward listens on.
Future<bool> canBindLoopback(int port) async {
  try {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}
