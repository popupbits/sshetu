import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/domain/approval.dart';
import 'package:sshetu/features/mcp/domain/audit_entry.dart';
import 'package:sshetu/features/mcp/domain/json_rpc.dart';
import 'package:sshetu/features/mcp/domain/mcp_dispatcher.dart';
import 'package:sshetu/features/mcp/domain/mcp_protocol.dart';
import 'package:sshetu/features/mcp/domain/sshetu_tools.dart';

import '../fake_mcp_backend.dart';

void main() {
  late FakeMcpBackend backend;
  late List<AuditEntry> audit;
  late List<ApprovalRequest> asked;
  late ApprovalDecision answer;
  late McpDispatcher dispatcher;

  McpDispatcher build({Duration timeout = const Duration(minutes: 2)}) =>
      McpDispatcher(
        tools: buildSshetuTools(backend),
        gate: ApprovalGate(
          approver: (request) async {
            asked.add(request);
            return answer;
          },
          timeout: timeout,
        ),
        audit: audit.add,
      );

  setUp(() {
    backend = FakeMcpBackend();
    audit = [];
    asked = [];
    answer = ApprovalDecision.approveOnce;
    dispatcher = build();
  });

  Map<String, Object?> request(
    String method, {
    Object id = 1,
    Map<String, Object?>? params,
  }) => {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': ?params};

  Future<McpOutbound> legacy(
    String method, {
    Map<String, Object?>? params,
    String? session,
  }) => dispatcher.handle(
    McpInbound(
      request(method, params: params),
      headers: {'mcp-session-id': ?session},
    ),
  );

  Future<String> initialize({String version = '2025-06-18'}) async {
    final out = await dispatcher.handle(
      McpInbound(
        request(
          'initialize',
          params: {
            'protocolVersion': version,
            'capabilities': {},
            'clientInfo': {'name': 'claude-code', 'version': '2.0'},
          },
        ),
      ),
    );
    return out.headers['Mcp-Session-Id']!;
  }

  Map<String, Object?> result(McpOutbound out) =>
      out.body!['result']! as Map<String, Object?>;

  String text(McpOutbound out) {
    final content = result(out)['content']! as List;
    return (content.single as Map)['text'] as String;
  }

  group('initialize', () {
    test('echoes a version it speaks, and names itself', () async {
      final out = await dispatcher.handle(
        McpInbound(
          request(
            'initialize',
            params: {
              'protocolVersion': '2025-03-26',
              'clientInfo': {'name': 'x'},
            },
          ),
        ),
      );
      expect(out.status, 200);
      final r = result(out);
      expect(r['protocolVersion'], '2025-03-26');
      expect((r['serverInfo']! as Map)['name'], 'sshetu');
      expect((r['capabilities']! as Map).containsKey('tools'), isTrue);
      expect(r['instructions'], isA<String>());
      expect(out.headers['Mcp-Session-Id'], hasLength(32));
    });

    test('offers its newest legacy version for one it does not know', () async {
      final out = await dispatcher.handle(
        McpInbound(request('initialize', params: {'protocolVersion': '1999'})),
      );
      expect(result(out)['protocolVersion'], kLegacyProtocolVersions.first);
    });

    test('the initialized notification is accepted with no body', () async {
      final out = await dispatcher.handle(
        const McpInbound({
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      expect(out.status, 202);
      expect(out.body, isNull);
    });
  });

  group('legacy requests', () {
    test(
      'an unknown session is a 404, so the client initializes again',
      () async {
        final out = await legacy('tools/list', session: 'stale');
        expect(out.status, 404);
      },
    );

    test('an unsupported MCP-Protocol-Version header is refused', () async {
      final out = await dispatcher.handle(
        McpInbound(
          request('tools/list'),
          headers: {'mcp-protocol-version': '2099-01-01'},
        ),
      );
      expect(out.status, 400);
    });

    test('tools/list advertises every tool, reads marked read-only', () async {
      final session = await initialize();
      final out = await legacy('tools/list', session: session);
      final tools = (result(out)['tools']! as List).cast<Map>();
      final names = [for (final t in tools) t['name']];
      expect(names, [
        'list_hosts',
        'list_sessions',
        'read_terminal',
        'server_info',
        'list_tunnels',
        'list_snippets',
        'run_command',
        'send_input',
        'open_session',
        'start_tunnel',
        'stop_tunnel',
        'run_snippet',
        'sftp_download',
        'sftp_upload',
      ]);
      for (final tool in tools) {
        final schema = tool['inputSchema'] as Map;
        expect(schema['type'], 'object', reason: '${tool['name']}');
        final annotations = tool['annotations'] as Map;
        final isRead = names.indexOf(tool['name']) < 6;
        expect(annotations['readOnlyHint'], isRead, reason: '${tool['name']}');
      }
    });

    test('unknown methods and tools are JSON-RPC errors', () async {
      final unknown = await legacy('resources/list');
      expect(
        (unknown.body!['error']! as Map)['code'],
        JsonRpcCodes.methodNotFound,
      );
      final tool = await legacy('tools/call', params: {'name': 'rm_rf'});
      expect((tool.body!['error']! as Map)['code'], JsonRpcCodes.invalidParams);
    });

    test('a batch is refused', () async {
      final out = await dispatcher.handle(McpInbound([request('ping')]));
      expect(out.status, 400);
      expect((out.body!['error']! as Map)['code'], JsonRpcCodes.invalidRequest);
    });
  });

  group('tools/call', () {
    test('a read tool runs without asking and is logged as a read', () async {
      final session = await initialize();
      final out = await legacy(
        'tools/call',
        session: session,
        params: {'name': 'list_hosts', 'arguments': {}},
      );
      expect(text(out), contains('web-1'));
      expect(asked, isEmpty);
      expect(audit.single.decision, AuditDecision.read);
      expect(audit.single.client, 'claude-code');
      expect(audit.single.resultBytes, greaterThan(0));
    });

    test('an act tool asks, naming client, tool, target and command', () async {
      final session = await initialize();
      final out = await legacy(
        'tools/call',
        session: session,
        params: {
          'name': 'run_command',
          'arguments': {'session_id': 's-1', 'command': 'uptime'},
        },
      );
      expect(result(out)['isError'], isNull);
      expect(text(out), 'output\n');
      final request = asked.single;
      expect(request.clientName, 'claude-code');
      expect(request.toolName, 'run_command');
      expect(request.target, contains('deploy@10.0.0.4:22'));
      expect(request.details.single.value, 'uptime');
      expect(backend.calls, ['typeLines s-1 uptime 3']);
      expect(audit.single.decision, AuditDecision.approved);
    });

    test('a denied act call does nothing and says so', () async {
      answer = ApprovalDecision.deny;
      final out = await legacy(
        'tools/call',
        params: {
          'name': 'run_command',
          'arguments': {'session_id': 's-1', 'command': 'reboot'},
        },
      );
      expect(result(out)['isError'], isTrue);
      expect(text(out), kDeniedMessage);
      expect(backend.calls, isEmpty);
      expect(audit.single.decision, AuditDecision.denied);
    });

    test('an unanswered act call times out and does nothing', () async {
      dispatcher = McpDispatcher(
        tools: buildSshetuTools(backend),
        gate: ApprovalGate(
          approver: (_) => Completer<ApprovalDecision>().future,
          timeout: const Duration(milliseconds: 20),
        ),
        audit: audit.add,
      );
      final out = await legacy(
        'tools/call',
        params: {
          'name': 'open_session',
          'arguments': {'host_id': 'h-web'},
        },
      );
      expect(text(out), kTimedOutMessage);
      expect(backend.calls, isEmpty);
      expect(audit.single.decision, AuditDecision.timedOut);
    });

    test('bad arguments are refused before anyone is asked', () async {
      final out = await legacy(
        'tools/call',
        params: {
          'name': 'run_command',
          'arguments': {'session_id': 's-2', 'command': 'ls'},
        },
      );
      expect(result(out)['isError'], isTrue);
      expect(text(out), contains('not connected'));
      expect(asked, isEmpty);
      expect(audit.single.decision, AuditDecision.rejected);
    });

    test(
      'approve similar covers the same client, tool and session only',
      () async {
        answer = ApprovalDecision.approveSimilar;
        final session = await initialize();
        Future<void> run(String id) => legacy(
          'tools/call',
          session: session,
          params: {
            'name': 'run_command',
            'arguments': {'session_id': id, 'command': 'ls'},
          },
        );
        await run('s-1');
        await run('s-1');
        expect(asked, hasLength(1));
        expect(audit.map((e) => e.decision), [
          AuditDecision.approved,
          AuditDecision.remembered,
        ]);

        // open_session never offers it.
        await legacy(
          'tools/call',
          session: session,
          params: {
            'name': 'open_session',
            'arguments': {'host_id': 'h-web'},
          },
        );
        await legacy(
          'tools/call',
          session: session,
          params: {
            'name': 'open_session',
            'arguments': {'host_id': 'h-web'},
          },
        );
        expect(asked, hasLength(3));
        expect(asked.last.canRememberSimilar, isFalse);
      },
    );
  });

  group('modern requests', () {
    Map<String, Object?> meta({String version = '2026-07-28'}) => {
      kMetaProtocolVersion: version,
      kMetaClientInfo: {'name': 'future-client', 'version': '1'},
      kMetaClientCapabilities: {},
    };

    Future<McpOutbound> modern(
      String method, {
      Map<String, Object?> params = const {},
      Map<String, String>? headers,
      String version = '2026-07-28',
    }) => dispatcher.handle(
      McpInbound(
        request(
          method,
          params: {
            ...params,
            '_meta': meta(version: version),
          },
        ),
        headers:
            headers ??
            {
              'mcp-protocol-version': version,
              'mcp-method': method,
              if (params['name'] case final String name) 'mcp-name': name,
            },
      ),
    );

    test('server/discover lists both eras', () async {
      final out = await modern('server/discover');
      expect(out.status, 200);
      final r = result(out);
      expect(r['resultType'], 'complete');
      expect(r['supportedVersions'], containsAll(['2026-07-28', '2025-11-25']));
    });

    test('an unsupported version is a 400 naming the supported ones', () async {
      final out = await modern('tools/list', version: '1900-01-01');
      expect(out.status, 400);
      final error = out.body!['error']! as Map;
      expect(error['code'], JsonRpcCodes.unsupportedProtocolVersion);
      expect((error['data'] as Map)['supported'], kModernProtocolVersions);
    });

    test('headers that disagree with the body are a HeaderMismatch', () async {
      final out = await modern(
        'tools/list',
        headers: {'mcp-protocol-version': '2026-07-28', 'mcp-method': 'ping'},
      );
      expect(out.status, 400);
      expect((out.body!['error']! as Map)['code'], JsonRpcCodes.headerMismatch);

      final noName = await modern(
        'tools/call',
        params: {'name': 'list_hosts'},
        headers: {
          'mcp-protocol-version': '2026-07-28',
          'mcp-method': 'tools/call',
        },
      );
      expect(noName.status, 400);
    });

    test('a Base64 Mcp-Name is decoded before comparing', () async {
      final out = await modern(
        'tools/call',
        params: {'name': 'list_hosts'},
        headers: {
          'mcp-protocol-version': '2026-07-28',
          'mcp-method': 'tools/call',
          'mcp-name': '=?base64?bGlzdF9ob3N0cw==?=',
        },
      );
      expect(out.status, 200);
    });

    test('tools/call carries the client name from _meta', () async {
      final out = await modern(
        'tools/call',
        params: {
          'name': 'send_input',
          'arguments': {'session_id': 's-1', 'data': '\u0003'},
        },
      );
      expect(out.status, 200);
      expect(result(out)['resultType'], 'complete');
      expect(asked.single.clientName, 'future-client');
      expect(asked.single.details.single.value, '<Ctrl-C>');
      expect(backend.calls, ['sendRaw s-1 \u0003']);
    });

    test('an unknown method is a 404', () async {
      final out = await modern('prompts/list');
      expect(out.status, 404);
      expect((out.body!['error']! as Map)['code'], JsonRpcCodes.methodNotFound);
    });
  });
}
