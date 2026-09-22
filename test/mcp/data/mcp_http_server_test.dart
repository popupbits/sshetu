import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/data/mcp_http_server.dart';
import 'package:sshetu/features/mcp/domain/approval.dart';
import 'package:sshetu/features/mcp/domain/audit_entry.dart';
import 'package:sshetu/features/mcp/domain/mcp_dispatcher.dart';
import 'package:sshetu/features/mcp/domain/sshetu_tools.dart';

import '../fake_mcp_backend.dart';

/// The real server on 127.0.0.1, driven by a real HTTP client: the security
/// checks in front of the dispatcher, and one whole conversation.
void main() {
  const token = 'test-token-0123456789';
  late McpHttpServer server;
  late FakeMcpBackend backend;
  late List<ApprovalRequest> asked;
  late ApprovalDecision answer;
  late List<AuditEntry> audit;
  late HttpClient client;
  late int port;

  setUp(() async {
    backend = FakeMcpBackend();
    asked = [];
    audit = [];
    answer = ApprovalDecision.approveOnce;
    server = McpHttpServer(
      dispatcher: McpDispatcher(
        tools: buildSshetuTools(backend),
        gate: ApprovalGate(
          approver: (request) async {
            asked.add(request);
            return answer;
          },
        ),
        audit: audit.add,
      ),
      token: token,
      preferredPort: 0,
      maxBodyBytes: 4096,
    );
    port = await server.start();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  Future<({int status, Map<String, Object?>? body, HttpHeaders headers})> send(
    Object? body, {
    String method = 'POST',
    String path = '/mcp',
    String? auth = 'Bearer $token',
    Map<String, String> headers = const {},
    String contentType = 'application/json',
    String? rawBody,
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/event-stream',
    );
    if (auth != null) {
      request.headers.set(HttpHeaders.authorizationHeader, auth);
    }
    headers.forEach(request.headers.set);
    if (method == 'POST') {
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      request.write(rawBody ?? jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return (
      status: response.statusCode,
      body: text.isEmpty ? null : jsonDecode(text) as Map<String, Object?>,
      headers: response.headers,
    );
  }

  Map<String, Object?> rpc(
    String method, [
    Map<String, Object?>? params,
    int id = 1,
  ]) => {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': ?params};

  group('refused before the body is read', () {
    test('no token, a wrong token, another scheme', () async {
      for (final auth in [
        null,
        'Bearer wrong',
        'Basic $token',
        'Bearer ${token}x',
      ]) {
        final r = await send(rpc('ping'), auth: auth);
        expect(r.status, 401, reason: '$auth');
        expect(r.headers.value(HttpHeaders.wwwAuthenticateHeader), 'Bearer');
      }
      expect(backend.calls, isEmpty);
    });

    test('a browser Origin', () async {
      final r = await send(
        rpc('ping'),
        headers: {'Origin': 'https://evil.example'},
      );
      expect(r.status, 403);
    });

    test('a rebound Host name', () async {
      final r = await send(
        rpc('ping'),
        headers: {'Host': 'evil.example:$port'},
      );
      expect(r.status, 403);
    });

    test('another path, GET, and a non-JSON body', () async {
      expect((await send(rpc('ping'), path: '/')).status, 404);
      final get = await send(null, method: 'GET');
      expect(get.status, 405);
      expect(get.headers.value(HttpHeaders.allowHeader), 'POST, DELETE');
      expect((await send(rpc('ping'), contentType: 'text/plain')).status, 415);
    });

    test('a body over the cap', () async {
      final r = await send(null, rawBody: '{"x":"${'a' * 5000}"}');
      expect(r.status, 413);
    });

    test('a chunked body that grows past the cap', () async {
      final request = await client.openUrl(
        'POST',
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..chunkedTransferEncoding = true;
      for (var i = 0; i < 5; i++) {
        request.write('a' * 1000);
      }
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 413);
    });

    test('malformed JSON', () async {
      final r = await send(null, rawBody: '{nope');
      expect(r.status, 400);
      expect((r.body!['error']! as Map)['code'], -32700);
    });
  });

  test(
    'a whole conversation: initialize, list, read, act approved and denied',
    () async {
      final init = await send(
        rpc('initialize', {
          'protocolVersion': '2025-06-18',
          'capabilities': {},
          'clientInfo': {'name': 'claude-code', 'version': '2.1'},
        }),
      );
      expect(init.status, 200);
      expect((init.body!['result']! as Map)['protocolVersion'], '2025-06-18');
      final session = init.headers.value('mcp-session-id')!;
      final headers = {
        'Mcp-Session-Id': session,
        'MCP-Protocol-Version': '2025-06-18',
      };

      final initialized = await send({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }, headers: headers);
      expect(initialized.status, 202);
      expect(initialized.body, isNull);

      final list = await send(rpc('tools/list', null, 2), headers: headers);
      expect(((list.body!['result']! as Map)['tools'] as List), hasLength(14));

      final hosts = await send(
        rpc('tools/call', {'name': 'list_sessions', 'arguments': {}}, 3),
        headers: headers,
      );
      final hostText =
          (((hosts.body!['result']! as Map)['content'] as List).single
              as Map)['text'];
      expect(hostText, contains('s-1'));
      expect(asked, isEmpty);

      final approved = await send(
        rpc('tools/call', {
          'name': 'run_command',
          'arguments': {'session_id': 's-1', 'command': 'df -h'},
        }, 4),
        headers: headers,
      );
      expect((approved.body!['result']! as Map)['isError'], isNull);
      expect(asked.single.clientName, 'claude-code');
      expect(backend.calls, ['typeLines s-1 df -h 3']);

      answer = ApprovalDecision.deny;
      final denied = await send(
        rpc('tools/call', {
          'name': 'run_command',
          'arguments': {'session_id': 's-1', 'command': 'rm -rf /tmp/x'},
        }, 5),
        headers: headers,
      );
      final deniedResult = denied.body!['result']! as Map;
      expect(deniedResult['isError'], isTrue);
      expect(
        ((deniedResult['content'] as List).single as Map)['text'],
        kDeniedMessage,
      );
      expect(
        backend.calls,
        hasLength(1),
        reason: 'the denied command never ran',
      );

      expect(audit.map((e) => e.decision), [
        AuditDecision.read,
        AuditDecision.approved,
        AuditDecision.denied,
      ]);

      // DELETE ends the session; using it again is a 404.
      final end = await send(null, method: 'DELETE', headers: headers);
      expect(end.status, 200);
      final after = await send(rpc('tools/list', null, 6), headers: headers);
      expect(after.status, 404);
    },
  );

  test(
    'a modern client, with per-request metadata and mirrored headers',
    () async {
      final r = await send(
        rpc('tools/call', {
          'name': 'list_hosts',
          'arguments': {},
          '_meta': {
            'io.modelcontextprotocol/protocolVersion': '2026-07-28',
            'io.modelcontextprotocol/clientInfo': {
              'name': 'next',
              'version': '1',
            },
            'io.modelcontextprotocol/clientCapabilities': {},
          },
        }),
        headers: {
          'MCP-Protocol-Version': '2026-07-28',
          'Mcp-Method': 'tools/call',
          'Mcp-Name': 'list_hosts',
        },
      );
      expect(r.status, 200);
      expect((r.body!['result']! as Map)['resultType'], 'complete');
    },
  );

  test('falls back to a free port when the preferred one is taken', () async {
    final second = McpHttpServer(
      dispatcher: McpDispatcher(
        tools: const [],
        gate: ApprovalGate(approver: (_) async => ApprovalDecision.deny),
        audit: (_) {},
      ),
      token: token,
      preferredPort: port,
    );
    final got = await second.start();
    addTearDown(second.stop);
    expect(got, isNot(port));
    expect(second.usedFallbackPort, isTrue);
  });
}
