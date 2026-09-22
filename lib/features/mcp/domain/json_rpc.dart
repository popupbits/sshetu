/// JSON-RPC 2.0, as far as an MCP server needs it: reading one request or
/// notification, and writing a result or an error.
///
/// Pure Dart, no Flutter, so every rule is pinned by a plain test.
library;

/// The error codes this server emits.
///
/// The first five are JSON-RPC's own. The two in `-32020..-32099` are the
/// ones the MCP specification defines for itself; nothing else from that
/// range may be used.
abstract final class JsonRpcCodes {
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  /// An `MCP-Protocol-Version`, `Mcp-Method` or `Mcp-Name` header is missing
  /// or disagrees with the body.
  static const int headerMismatch = -32020;

  /// The request asked for a protocol version this server does not speak.
  static const int unsupportedProtocolVersion = -32022;
}

/// A request that could not be read, with what to answer it with.
class JsonRpcException implements Exception {
  const JsonRpcException(this.code, this.message, {this.id, this.data});

  final int code;
  final String message;

  /// The request's id, when it could be read before the failure.
  final Object? id;
  final Object? data;

  Map<String, Object?> toResponse() =>
      jsonRpcError(id, code, message, data: data);

  @override
  String toString() => 'JsonRpcException($code, $message)';
}

/// One request or notification from the client.
class JsonRpcMessage {
  const JsonRpcMessage({
    required this.method,
    required this.params,
    this.id,
    this.hasId = false,
  });

  final String method;
  final Map<String, Object?> params;

  /// A string or an integer. Never null on a request — MCP forbids it.
  final Object? id;

  /// Whether the message carried an id at all, which is what makes it a
  /// request rather than a notification.
  final bool hasId;

  bool get isNotification => !hasId;
}

/// Reads [decoded] — the output of `jsonDecode` — as one JSON-RPC message.
///
/// Throws [JsonRpcException] with [JsonRpcCodes.invalidRequest] for anything
/// that is not a well-formed request or notification: a batch, a response, a
/// missing method, an id that is null or fractional, params that are not an
/// object.
JsonRpcMessage parseJsonRpc(Object? decoded) {
  if (decoded is List) {
    throw const JsonRpcException(
      JsonRpcCodes.invalidRequest,
      'Batches are not supported; send one message per request.',
    );
  }
  if (decoded is! Map) {
    throw const JsonRpcException(
      JsonRpcCodes.invalidRequest,
      'A JSON-RPC message must be an object.',
    );
  }
  final hasId = decoded.containsKey('id');
  final id = decoded['id'];
  final idValid = id is String || id is int;
  final safeId = idValid ? id : null;

  if (decoded['jsonrpc'] != '2.0') {
    throw JsonRpcException(
      JsonRpcCodes.invalidRequest,
      'jsonrpc must be "2.0".',
      id: safeId,
    );
  }
  final method = decoded['method'];
  if (method is! String || method.isEmpty) {
    throw JsonRpcException(
      JsonRpcCodes.invalidRequest,
      decoded.containsKey('result') || decoded.containsKey('error')
          ? 'This server sends no requests, so it takes no responses.'
          : 'method must be a non-empty string.',
      id: safeId,
    );
  }
  if (hasId && !idValid) {
    throw const JsonRpcException(
      JsonRpcCodes.invalidRequest,
      'id must be a string or an integer.',
    );
  }
  final params = decoded['params'];
  if (params != null && params is! Map) {
    throw JsonRpcException(
      JsonRpcCodes.invalidRequest,
      'params must be an object.',
      id: safeId,
    );
  }
  return JsonRpcMessage(
    method: method,
    params: params == null
        ? const {}
        : Map<String, Object?>.from(params as Map<Object?, Object?>),
    id: safeId,
    hasId: hasId,
  );
}

Map<String, Object?> jsonRpcResult(Object? id, Map<String, Object?> result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

/// An error response. [id] is left out when it is null — an error about a
/// message whose id could not be read carries none.
Map<String, Object?> jsonRpcError(
  Object? id,
  int code,
  String message, {
  Object? data,
}) => {
  'jsonrpc': '2.0',
  'id': ?id,
  'error': {'code': code, 'message': message, 'data': ?data},
};
