import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// The checks every request to the MCP endpoint passes before its body is
/// read. Pure functions, so each rule has a test of its own.

/// Loopback only. The socket is bound to 127.0.0.1 anyway; this is the
/// second lock on the same door.
bool isLoopbackPeer(InternetAddress? address) =>
    address != null && address.isLoopback;

/// Whether [host] — the `Host` header — names this server on loopback.
///
/// The DNS-rebinding defence. A web page that points its own hostname at
/// 127.0.0.1 can make the browser connect here, but the browser still sends
/// that hostname, not ours.
bool isAllowedHostHeader(String? host, int port) {
  if (host == null) return false;
  final value = host.trim().toLowerCase();
  return value == '127.0.0.1:$port' ||
      value == 'localhost:$port' ||
      value == '[::1]:$port';
}

/// Whether a request with [origin] — the `Origin` header — may proceed.
///
/// Only when there is none. Browsers send one on every cross-origin request
/// and every POST; MCP clients are programs and send none. Nothing a browser
/// shows is meant to reach this server, so any origin at all is refused.
bool isAllowedOrigin(String? origin) => origin == null;

/// The token in an `Authorization: Bearer <token>` header, or null.
String? bearerToken(String? header) {
  if (header == null) return null;
  final match = RegExp(
    r'^\s*bearer\s+(\S+)\s*$',
    caseSensitive: false,
  ).firstMatch(header);
  return match?.group(1);
}

/// Compares [given] with [expected] in time that depends only on
/// [expected]'s length, so response timing does not leak how much of a
/// guessed token was right.
bool constantTimeEquals(String given, String expected) {
  final a = utf8.encode(given);
  final b = utf8.encode(expected);
  var diff = a.length ^ b.length;
  for (var i = 0; i < b.length; i++) {
    diff |= (i < a.length ? a[i] : 0) ^ b[i];
  }
  return diff == 0;
}

/// A new access token: 32 random bytes, Base64url without padding.
String generateMcpToken([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
