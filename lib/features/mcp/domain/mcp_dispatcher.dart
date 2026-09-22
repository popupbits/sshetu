import 'dart:convert';
import 'dart:math';

import 'approval.dart';
import 'audit_entry.dart';
import 'json_rpc.dart';
import 'mcp_protocol.dart';
import 'mcp_tool.dart';

/// One POST, as the dispatcher sees it: the decoded body and the headers it
/// cares about, names lower-cased.
class McpInbound {
  const McpInbound(this.body, {this.headers = const {}});

  final Object? body;
  final Map<String, String> headers;

  String? header(String name) => headers[name.toLowerCase()];
}

/// The answer to one POST: an HTTP status, and a JSON body unless it is a
/// bare `202 Accepted`.
class McpOutbound {
  const McpOutbound(this.status, {this.body, this.headers = const {}});

  final int status;
  final Map<String, Object?>? body;
  final Map<String, String> headers;
}

typedef McpAuditSink = void Function(AuditEntry entry);

/// What the client is told when the user says no. Written for the model:
/// what happened, and that retrying is not the answer.
const String kDeniedMessage =
    'The SSHetu user denied this request. Do not retry it unless the user '
    'asks you to.';
const String kTimedOutMessage =
    'Nobody answered the approval dialog in SSHetu in time, so nothing was '
    'done. Ask the user to watch for the dialog and try again.';
const String kUnavailableMessage =
    'SSHetu could not show its approval dialog (its window is not ready), so '
    'nothing was done.';

/// The MCP method dispatcher: `initialize`, `server/discover`, `ping`,
/// `tools/list` and `tools/call`, for clients of either protocol era (see
/// `mcp_protocol.dart`).
///
/// Transport-aware only as far as the spec makes status codes part of the
/// protocol. It never sees a socket; the HTTP server has already checked the
/// peer, the token and the origin before a body gets here.
class McpDispatcher {
  McpDispatcher({
    required List<McpTool> tools,
    required this.gate,
    required this.audit,
    this.serverName = 'sshetu',
    this.serverTitle = 'SSHetu',
    this.serverVersion = '1.0.0',
    this.instructions = kMcpInstructions,
    DateTime Function()? clock,
    Random? random,
  }) : _tools = {for (final tool in tools) tool.name: tool},
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final Map<String, McpTool> _tools;
  final ApprovalGate gate;
  final McpAuditSink audit;
  final String serverName;
  final String serverTitle;

  /// Set once the app's version has been read.
  String serverVersion;
  final String instructions;
  final DateTime Function() _clock;
  final Random _random;

  /// Legacy sessions: id to the client name given at `initialize`. Oldest
  /// first, so the cap drops the stalest.
  final _sessions = <String, String>{};
  static const int _maxSessions = 64;

  Iterable<McpTool> get tools => _tools.values;

  Map<String, Object?> get _serverInfo => {
    'name': serverName,
    'title': serverTitle,
    'version': serverVersion,
  };

  Map<String, Object?> get _capabilities => {
    'tools': {'listChanged': false},
  };

  /// Ends a legacy session (HTTP `DELETE`). Whether it existed.
  bool endSession(String id) => _sessions.remove(id) != null;

  Future<McpOutbound> handle(McpInbound inbound) async {
    final JsonRpcMessage message;
    try {
      message = parseJsonRpc(inbound.body);
    } on JsonRpcException catch (error) {
      return McpOutbound(400, body: error.toResponse());
    }
    // No client notification changes anything here: `initialized` only says
    // the client is ready, and a cancellation has nothing to cancel that the
    // closed connection has not already.
    if (message.isNotification) return const McpOutbound(202);

    final meta = message.params['_meta'];
    final modernVersion = meta is Map ? meta[kMetaProtocolVersion] : null;
    if (modernVersion != null) {
      return _modern(message, meta as Map, modernVersion, inbound);
    }
    if (message.method == 'initialize') return _initialize(message);
    return _legacy(message, inbound);
  }

  // ------------------------------------------------------------ modern era

  Future<McpOutbound> _modern(
    JsonRpcMessage message,
    Map<Object?, Object?> meta,
    Object? version,
    McpInbound inbound,
  ) async {
    final id = message.id;
    if (version is! String || !kModernProtocolVersions.contains(version)) {
      return McpOutbound(
        400,
        body: jsonRpcError(
          id,
          JsonRpcCodes.unsupportedProtocolVersion,
          'Unsupported protocol version',
          data: {'supported': kModernProtocolVersions, 'requested': version},
        ),
      );
    }
    String? mismatch;
    if (inbound.header('mcp-protocol-version') != version) {
      mismatch = 'MCP-Protocol-Version header does not match the body';
    } else if (inbound.header('mcp-method') != message.method) {
      mismatch = 'Mcp-Method header does not match the body';
    } else if (message.method == 'tools/call') {
      final header = inbound.header('mcp-name');
      final decoded = header == null ? null : decodeHeaderValue(header);
      if (decoded == null || decoded != message.params['name']) {
        mismatch = 'Mcp-Name header does not match the body';
      }
    }
    if (mismatch != null) {
      return McpOutbound(
        400,
        body: jsonRpcError(id, JsonRpcCodes.headerMismatch, mismatch),
      );
    }
    if (meta[kMetaClientCapabilities] is! Map) {
      return McpOutbound(
        400,
        body: jsonRpcError(
          id,
          JsonRpcCodes.invalidParams,
          '_meta is missing $kMetaClientCapabilities',
        ),
      );
    }
    final client = clientNameFrom(meta[kMetaClientInfo]) ?? 'Unnamed client';

    Map<String, Object?> complete(Map<String, Object?> result) => {
      'resultType': 'complete',
      ...result,
      '_meta': {kMetaServerInfo: _serverInfo},
    };

    switch (message.method) {
      case 'server/discover':
        return McpOutbound(
          200,
          body: jsonRpcResult(
            id,
            complete({
              'supportedVersions': [
                ...kModernProtocolVersions,
                ...kLegacyProtocolVersions,
              ],
              'capabilities': _capabilities,
              'instructions': instructions,
            }),
          ),
        );
      case 'ping':
        return McpOutbound(200, body: jsonRpcResult(id, complete({})));
      case 'tools/list':
        return McpOutbound(200, body: jsonRpcResult(id, complete(_toolList())));
      case 'tools/call':
        final outcome = await _call(message, client);
        return switch (outcome) {
          _CallFailed(:final error) => McpOutbound(400, body: error),
          _CallDone(:final result) => McpOutbound(
            200,
            body: jsonRpcResult(id, complete(result.toJson())),
          ),
        };
      default:
        return McpOutbound(
          404,
          body: jsonRpcError(
            id,
            JsonRpcCodes.methodNotFound,
            'Method not found: ${message.method}',
          ),
        );
    }
  }

  // ------------------------------------------------------------ legacy era

  McpOutbound _initialize(JsonRpcMessage message) {
    final client =
        clientNameFrom(message.params['clientInfo']) ?? 'Unnamed client';
    final sessionId = _newSessionId();
    _sessions[sessionId] = client;
    while (_sessions.length > _maxSessions) {
      _sessions.remove(_sessions.keys.first);
    }
    return McpOutbound(
      200,
      headers: {'Mcp-Session-Id': sessionId},
      body: jsonRpcResult(message.id, {
        'protocolVersion': negotiateLegacyVersion(
          message.params['protocolVersion'],
        ),
        'capabilities': _capabilities,
        'serverInfo': _serverInfo,
        'instructions': instructions,
      }),
    );
  }

  Future<McpOutbound> _legacy(
    JsonRpcMessage message,
    McpInbound inbound,
  ) async {
    final id = message.id;
    final version = inbound.header('mcp-protocol-version');
    if (version != null && !kLegacyProtocolVersions.contains(version)) {
      return McpOutbound(
        400,
        body: jsonRpcError(
          id,
          JsonRpcCodes.invalidRequest,
          'Unsupported MCP-Protocol-Version: $version',
          data: {
            'supported': [
              ...kModernProtocolVersions,
              ...kLegacyProtocolVersions,
            ],
          },
        ),
      );
    }
    final sessionId = inbound.header('mcp-session-id');
    var client = 'Unnamed client';
    if (sessionId != null) {
      final known = _sessions[sessionId];
      // The spec's answer to a session the server no longer knows: 404, and
      // the client starts again with `initialize`.
      if (known == null) {
        return McpOutbound(
          404,
          body: jsonRpcError(
            id,
            JsonRpcCodes.invalidRequest,
            'Unknown session; initialize again.',
          ),
        );
      }
      client = known;
    }

    switch (message.method) {
      case 'ping':
        return McpOutbound(200, body: jsonRpcResult(id, {}));
      case 'tools/list':
        return McpOutbound(200, body: jsonRpcResult(id, _toolList()));
      case 'tools/call':
        final outcome = await _call(message, client);
        return switch (outcome) {
          _CallFailed(:final error) => McpOutbound(200, body: error),
          _CallDone(:final result) => McpOutbound(
            200,
            body: jsonRpcResult(id, result.toJson()),
          ),
        };
      default:
        return McpOutbound(
          200,
          body: jsonRpcError(
            id,
            JsonRpcCodes.methodNotFound,
            'Method not found: ${message.method}',
          ),
        );
    }
  }

  // --------------------------------------------------------------- tools

  Map<String, Object?> _toolList() => {
    'tools': [for (final tool in _tools.values) tool.toJson()],
  };

  Future<_CallOutcome> _call(JsonRpcMessage message, String client) async {
    final id = message.id;
    final name = message.params['name'];
    final rawArgs = message.params['arguments'];
    if (name is! String) {
      return _CallFailed(
        jsonRpcError(id, JsonRpcCodes.invalidParams, 'name is required'),
      );
    }
    final tool = _tools[name];
    if (tool == null) {
      return _CallFailed(
        jsonRpcError(id, JsonRpcCodes.invalidParams, 'Unknown tool: $name'),
      );
    }
    if (rawArgs != null && rawArgs is! Map) {
      return _CallFailed(
        jsonRpcError(
          id,
          JsonRpcCodes.invalidParams,
          'arguments must be an object',
        ),
      );
    }
    final args = ToolArgs(
      rawArgs == null
          ? const {}
          : Map<String, Object?>.from(rawArgs as Map<Object?, Object?>),
    );
    final result = switch (tool.kind) {
      McpToolKind.read => await _read(tool, args, client),
      McpToolKind.act => await _act(tool, args, client),
    };
    return _CallDone(result);
  }

  Future<McpToolResult> _read(
    McpTool tool,
    ToolArgs args,
    String client,
  ) async {
    String? target;
    try {
      target = tool.auditTarget?.call(args);
    } on Object {
      target = null;
    }
    try {
      final result = await tool.read(args);
      _record(
        client,
        tool,
        result.isError ? AuditDecision.rejected : AuditDecision.read,
        target: target,
        result: result,
      );
      return result;
    } on McpToolException catch (error) {
      _record(
        client,
        tool,
        AuditDecision.rejected,
        target: target,
        error: error.message,
      );
      return McpToolResult.error(error.message);
    } on Object catch (error) {
      _record(
        client,
        tool,
        AuditDecision.rejected,
        target: target,
        error: '$error',
      );
      return McpToolResult.error('${tool.name} failed: $error');
    }
  }

  Future<McpToolResult> _act(McpTool tool, ToolArgs args, String client) async {
    final ActPlan plan;
    try {
      plan = await tool.plan(args);
    } on McpToolException catch (error) {
      _record(client, tool, AuditDecision.rejected, error: error.message);
      return McpToolResult.error(error.message);
    } on Object catch (error) {
      _record(client, tool, AuditDecision.rejected, error: '$error');
      return McpToolResult.error('${tool.name} failed: $error');
    }

    final scope = plan.rememberScope;
    final request = ApprovalRequest(
      clientName: client,
      toolName: tool.name,
      target: plan.target,
      details: plan.details,
      canRememberSimilar: scope != null,
    );
    final outcome = await gate.check(
      request,
      rememberKey: scope == null
          ? null
          : jsonEncode([client, tool.name, scope]),
    );

    final refusal = switch (outcome) {
      ApprovalOutcome.denied => (AuditDecision.denied, kDeniedMessage),
      ApprovalOutcome.timedOut => (AuditDecision.timedOut, kTimedOutMessage),
      ApprovalOutcome.unavailable => (
        AuditDecision.unavailable,
        kUnavailableMessage,
      ),
      ApprovalOutcome.approved || ApprovalOutcome.remembered => null,
    };
    if (refusal != null) {
      _record(client, tool, refusal.$1, target: plan.target);
      return McpToolResult.error(refusal.$2);
    }

    final decision = outcome == ApprovalOutcome.remembered
        ? AuditDecision.remembered
        : AuditDecision.approved;
    try {
      final result = await plan.run();
      _record(
        client,
        tool,
        decision,
        target: plan.target,
        result: result,
        error: result.isError ? result.text : null,
      );
      return result;
    } on McpToolException catch (error) {
      _record(
        client,
        tool,
        decision,
        target: plan.target,
        error: error.message,
      );
      return McpToolResult.error(error.message);
    } on Object catch (error) {
      _record(client, tool, decision, target: plan.target, error: '$error');
      return McpToolResult.error('${tool.name} failed: $error');
    }
  }

  void _record(
    String client,
    McpTool tool,
    AuditDecision decision, {
    String? target,
    McpToolResult? result,
    String? error,
  }) {
    try {
      audit(
        AuditEntry(
          time: _clock(),
          client: client,
          tool: tool.name,
          target: target,
          decision: decision,
          resultBytes: result?.sizeInBytes,
          error: error == null ? null : _clip(error),
        ),
      );
    } on Object {
      // The log is a record, not a gate: failing to write it must not turn
      // a call that happened into one that looks as if it did not.
    }
  }

  static String _clip(String text) =>
      text.length > 300 ? '${text.substring(0, 300)}…' : text;

  String _newSessionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

sealed class _CallOutcome {
  const _CallOutcome();
}

class _CallDone extends _CallOutcome {
  const _CallDone(this.result);
  final McpToolResult result;
}

class _CallFailed extends _CallOutcome {
  const _CallFailed(this.error);
  final Map<String, Object?> error;
}

/// Told to every client, for its model.
const String kMcpInstructions =
    'SSHetu is the SSH client on this computer. Read tools (list_hosts, '
    'list_sessions, read_terminal, server_info, list_tunnels, list_snippets) '
    'answer at once. Every tool that changes something — typing into a '
    'session, opening one, starting or stopping a tunnel, running a snippet, '
    'moving a file — first shows the user an approval dialog in SSHetu and '
    'waits up to two minutes; a denial is final unless the user says '
    'otherwise. Terminal output is read from the screen buffer, so it is '
    'whatever the terminal shows, not a structured result. Secrets — '
    'passwords, keys, passphrases — are never available through this server.';
