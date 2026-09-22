import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/http_guard.dart';
import '../domain/json_rpc.dart';
import '../domain/mcp_dispatcher.dart';
import '../domain/mcp_protocol.dart';

/// The port SSHetu asks for first. Fixed, so a client configured once keeps
/// working across restarts; if something else holds it, the server falls
/// back to any free port and Settings says so.
const int kDefaultMcpPort = 47832;

/// The largest request body accepted. Tool arguments are commands and paths
/// — a file transfer names a local path rather than carrying the bytes — so
/// a megabyte is generous.
const int kMaxMcpBodyBytes = 1024 * 1024;

/// MCP's Streamable HTTP transport, on 127.0.0.1 only.
///
/// Every request passes, in order: a loopback peer, a `Host` header naming
/// loopback (DNS rebinding), no `Origin` at all (no browser), the `/mcp`
/// path, a bearer token compared in constant time, POST or DELETE, a body
/// within [maxBodyBytes], and a JSON content type. Only then is the body
/// decoded and handed to [dispatcher]. Answers are always a single JSON
/// object; the server never opens an SSE stream.
class McpHttpServer {
  McpHttpServer({
    required this.dispatcher,
    required this.token,
    this.preferredPort = kDefaultMcpPort,
    this.maxBodyBytes = kMaxMcpBodyBytes,
  });

  final McpDispatcher dispatcher;
  final String token;
  final int preferredPort;
  final int maxBodyBytes;

  HttpServer? _server;

  /// The port it is listening on, once started.
  int? get port => _server?.port;

  /// Whether [preferredPort] was taken and another was used.
  bool get usedFallbackPort => port != null && port != preferredPort;

  /// Binds and starts answering. Returns the port.
  Future<int> start() async {
    HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        preferredPort,
      );
    } on SocketException {
      if (preferredPort == 0) rethrow;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    // A request waiting on an approval dialog is not idle; the socket is.
    server.idleTimeout = const Duration(minutes: 5);
    _server = server;
    server.listen((request) => unawaited(_handle(request)));
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final port = this.port ?? 0;
      if (!isLoopbackPeer(request.connectionInfo?.remoteAddress)) {
        return await _refuse(request, HttpStatus.forbidden, 'Loopback only.');
      }
      if (!isAllowedHostHeader(
        _single(request, HttpHeaders.hostHeader),
        port,
      )) {
        return await _refuse(request, HttpStatus.forbidden, 'Bad Host header.');
      }
      if (!isAllowedOrigin(request.headers['origin']?.join(','))) {
        return await _refuse(
          request,
          HttpStatus.forbidden,
          'Browser origins are not allowed.',
        );
      }
      if (request.uri.path != kMcpPath) {
        return await _refuse(request, HttpStatus.notFound, 'Not found.');
      }
      final given = bearerToken(
        _single(request, HttpHeaders.authorizationHeader),
      );
      if (given == null || !constantTimeEquals(given, token)) {
        response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
        return await _refuse(
          request,
          HttpStatus.unauthorized,
          'Missing or wrong access token.',
        );
      }

      if (request.method == 'DELETE') {
        final session = _single(request, 'mcp-session-id');
        if (session != null && dispatcher.endSession(session)) {
          response.statusCode = HttpStatus.ok;
          return await response.close();
        }
      }
      if (request.method != 'POST') {
        response.headers.set(HttpHeaders.allowHeader, 'POST, DELETE');
        return await _refuse(
          request,
          HttpStatus.methodNotAllowed,
          'POST JSON-RPC messages to this endpoint.',
        );
      }

      if (request.contentLength > maxBodyBytes) {
        return await _refuse(
          request,
          HttpStatus.requestEntityTooLarge,
          'Request too large.',
        );
      }
      if (request.headers.contentType?.mimeType != 'application/json') {
        return await _refuse(
          request,
          HttpStatus.unsupportedMediaType,
          'Content-Type must be application/json.',
        );
      }
      final bytes = await _readCapped(request);
      if (bytes == null) {
        return await _refuse(
          request,
          HttpStatus.requestEntityTooLarge,
          'Request too large.',
          bodyRead: true,
        );
      }
      final Object? body;
      try {
        body = jsonDecode(utf8.decode(bytes));
      } on FormatException {
        return await _send(
          response,
          HttpStatus.badRequest,
          jsonRpcError(null, JsonRpcCodes.parseError, 'Parse error'),
        );
      }

      final outbound = await dispatcher.handle(
        McpInbound(
          body,
          headers: {
            for (final name in const [
              'mcp-protocol-version',
              'mcp-method',
              'mcp-name',
              'mcp-session-id',
            ])
              name: ?_single(request, name),
          },
        ),
      );
      outbound.headers.forEach(response.headers.set);
      final outBody = outbound.body;
      if (outBody == null) {
        response.statusCode = outbound.status;
        return await response.close();
      }
      await _send(response, outbound.status, outBody);
    } on Object {
      // The client may have gone away while a dialog was up; there is
      // nobody left to tell.
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } on Object {
        // Already closed.
      }
    }
  }

  /// The single value of header [name]; null when absent or repeated — a
  /// repeated `Authorization` is not a token.
  static String? _single(HttpRequest request, String name) {
    final values = request.headers[name];
    if (values == null || values.length != 1) return null;
    return values.single;
  }

  /// How much of a refused body is read and thrown away before the answer
  /// goes out. Closing a socket with unread data in it resets the connection
  /// on some platforms, and the client then sees a reset instead of the
  /// refusal; past this, a reset is what an oversized body gets.
  int get _discardLimit => maxBodyBytes * 4;

  /// The body, or null once it passes [maxBodyBytes] — in which case the
  /// rest is read and dropped, up to [_discardLimit], never kept.
  Future<Uint8List?> _readCapped(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    var seen = 0;
    var over = false;
    await for (final chunk in request) {
      seen += chunk.length;
      if (over) {
        if (seen > _discardLimit) break;
        continue;
      }
      builder.add(chunk);
      if (builder.length > maxBodyBytes) {
        over = true;
        builder.clear();
      }
    }
    return over ? null : builder.takeBytes();
  }

  Future<void> _discard(HttpRequest request) async {
    var seen = 0;
    try {
      await for (final chunk in request.timeout(const Duration(seconds: 2))) {
        seen += chunk.length;
        if (seen > _discardLimit) break;
      }
    } on Object {
      // A client that stalls or vanishes gets its refusal all the same.
    }
  }

  static Future<void> _send(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }

  /// Refuses with a JSON-RPC error that has no id — what the spec suggests
  /// for a 403 — after discarding any body not yet read.
  Future<void> _refuse(
    HttpRequest request,
    int status,
    String message, {
    bool bodyRead = false,
  }) async {
    if (!bodyRead) await _discard(request);
    await _send(
      request.response,
      status,
      jsonRpcError(null, JsonRpcCodes.invalidRequest, message),
    );
  }
}
