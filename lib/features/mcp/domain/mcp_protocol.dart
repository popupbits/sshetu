/// The MCP protocol versions this server speaks, and the reserved `_meta`
/// keys it reads and writes.
///
/// **Two eras on one endpoint.** Revision `2026-07-28` is stateless: every
/// request carries its protocol version and client identity in `_meta`, and
/// there is no `initialize`. Every revision up to `2025-11-25` opens with an
/// `initialize` handshake instead. Clients of both kinds are in use, so this
/// server answers both — a request carrying the modern `_meta` is served the
/// modern way, an `initialize` starts a legacy session.
library;

import 'dart:convert';

/// Stateless, per-request-metadata revisions. Newest first.
const List<String> kModernProtocolVersions = ['2026-07-28'];

/// `initialize`-handshake revisions. Newest first; the first is what a
/// client asking for something unknown is offered instead.
const List<String> kLegacyProtocolVersions = [
  '2025-11-25',
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

/// What a legacy request without an `MCP-Protocol-Version` header is taken
/// to be. The header arrived in `2025-06-18`; the spec lets a server treat
/// its absence as `2025-03-26`.
const String kLegacyDefaultVersion = '2025-03-26';

const String kMetaProtocolVersion = 'io.modelcontextprotocol/protocolVersion';
const String kMetaClientInfo = 'io.modelcontextprotocol/clientInfo';
const String kMetaClientCapabilities =
    'io.modelcontextprotocol/clientCapabilities';
const String kMetaServerInfo = 'io.modelcontextprotocol/serverInfo';

/// The only path the server answers on.
const String kMcpPath = '/mcp';

/// The version a legacy `initialize` is answered with: the one asked for
/// when this server speaks it, otherwise the newest it does.
String negotiateLegacyVersion(Object? requested) =>
    requested is String && kLegacyProtocolVersions.contains(requested)
    ? requested
    : kLegacyProtocolVersions.first;

/// Reads `clientInfo.name` out of [info], for the approval dialog and the
/// activity log. Self-reported and never trusted for anything else.
String? clientNameFrom(Object? info) {
  if (info is! Map) return null;
  final name = info['name'] ?? info['title'];
  if (name is! String) return null;
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  // A name is shown in a dialog; a client that sends a novel is cut short.
  return trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed;
}

/// Decodes the Base64 sentinel form a header value may take
/// (`=?base64?…?=`), and returns any other value unchanged. Null for a
/// sentinel that is not valid Base64 or UTF-8.
String? decodeHeaderValue(String value) {
  const prefix = '=?base64?';
  const suffix = '?=';
  if (!value.startsWith(prefix) || !value.endsWith(suffix)) return value;
  final body = value.substring(prefix.length, value.length - suffix.length);
  try {
    return utf8.decode(base64.decode(body));
  } on FormatException {
    return null;
  }
}
