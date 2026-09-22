import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sshetu/features/mcp/domain/approval.dart';
import 'package:sshetu/features/mcp/domain/mcp_tool.dart';
import 'package:sshetu/features/mcp/domain/sshetu_tools.dart';

import '../fake_mcp_backend.dart';

void main() {
  late FakeMcpBackend backend;
  late Map<String, McpTool> tools;

  setUp(() {
    backend = FakeMcpBackend();
    tools = {
      for (final tool in buildSshetuTools(
        backend,
        clock: () => DateTime(2026, 9, 22, 9, 5, 7),
      ))
        tool.name: tool,
    };
  });

  Future<McpToolResult> read(
    String name, [
    Map<String, Object?> args = const {},
  ]) => tools[name]!.read(ToolArgs(args));

  Future<ActPlan> plan(String name, Map<String, Object?> args) =>
      tools[name]!.plan(ToolArgs(args));

  Matcher refused(Pattern message) => throwsA(
    isA<McpToolException>().having(
      (e) => e.message,
      'message',
      contains(message),
    ),
  );

  Map<String, Object?> json(McpToolResult result) =>
      jsonDecode(result.text) as Map<String, Object?>;

  test('six read tools and eight act tools', () {
    expect(tools.values.where((t) => t.kind == McpToolKind.read), hasLength(6));
    expect(tools.values.where((t) => t.kind == McpToolKind.act), hasLength(8));
  });

  group('read tools', () {
    test('list_hosts carries no secrets, and filters', () async {
      final all = json(await read('list_hosts'))['hosts']! as List;
      expect(all, hasLength(2));
      final web = all.first as Map;
      expect(
        web.keys,
        unorderedEquals([
          'id',
          'label',
          'address',
          'hostname',
          'port',
          'username',
          'group',
          'tags',
        ]),
      );
      expect(web['address'], 'deploy@10.0.0.4:22');

      final byQuery = json(await read('list_hosts', {'query': 'DB.int'}));
      expect((byQuery['hosts']! as List).single, containsPair('id', 'h-db'));
      final byTag = json(await read('list_hosts', {'tag': 'web'}));
      expect((byTag['hosts']! as List).single, containsPair('id', 'h-web'));
    });

    test('list_sessions', () async {
      final sessions = json(await read('list_sessions'))['sessions']! as List;
      expect(sessions, hasLength(2));
      expect(sessions.first, containsPair('status', 'running'));
      expect(sessions.first, containsPair('active', true));
    });

    test('read_terminal returns the tail, and checks its arguments', () async {
      expect(
        (await read('read_terminal', {'session_id': 's-1', 'lines': 2})).text,
        'line 2\n\$ ',
      );
      expect(
        () => read('read_terminal', {'session_id': 'nope'}),
        refused('No open session'),
      );
      expect(
        () => read('read_terminal', {'session_id': 's-1', 'lines': 5000}),
        refused('between 1 and 2000'),
      );
      expect(
        () => read('read_terminal', {'session_id': 's-1', 'lines': 1.5}),
        refused('whole number'),
      );
      expect(
        tools['read_terminal']!.auditTarget!(
          const ToolArgs({'session_id': 's-1'}),
        ),
        's-1',
      );
    });

    test('server_info needs a connected session', () async {
      expect(
        json(await read('server_info', {'session_id': 's-1'})),
        containsPair('cpu_count', 4),
      );
      expect(
        () => read('server_info', {'session_id': 's-2'}),
        refused('not connected'),
      );
    });

    test('list_tunnels', () async {
      final tunnels = json(await read('list_tunnels'))['tunnels']! as List;
      expect(tunnels.single, containsPair('state', 'stopped'));
    });

    test('list_snippets names the variables the caller must fill', () async {
      final snippets = json(await read('list_snippets'))['snippets']! as List;
      final variables = (snippets.single as Map)['variables'] as List;
      expect(variables, [
        {'name': 'service'},
        {'name': 'level', 'default': 'info'},
      ]);
    });
  });

  group('act tools plan without acting', () {
    test('run_command', () async {
      final p = await plan('run_command', {
        'session_id': 's-1',
        'command': 'tail -n 5 /var/log/syslog',
        'wait_seconds': 0,
      });
      expect(backend.calls, isEmpty, reason: 'planning must not act');
      expect(p.target, 'web-1 — deploy@10.0.0.4:22 (session s-1)');
      expect(p.details.single.kind, ApprovalDetailKind.command);
      expect(p.rememberScope, 's-1');
      final result = await p.run();
      expect(result.text, 'output\n');
      expect(backend.calls, ['typeLines s-1 tail -n 5 /var/log/syslog 0']);
    });

    test('run_command reports silence honestly', () async {
      backend.output = '';
      final p = await plan('run_command', {
        'session_id': 's-1',
        'command': 'true',
      });
      expect((await p.run()).text, contains('no output within 3 s'));
    });

    test('run_command refuses a closed session, a missing or huge command', () {
      expect(
        () => plan('run_command', {'session_id': 's-2', 'command': 'ls'}),
        refused('not connected'),
      );
      expect(
        () => plan('run_command', {'session_id': 's-1'}),
        refused('"command" is required'),
      );
      expect(
        () =>
            plan('run_command', {'session_id': 's-1', 'command': 'x' * 20000}),
        refused('longer than'),
      );
      expect(
        () => plan('run_command', {
          'session_id': 's-1',
          'command': 'ls',
          'wait_seconds': 99,
        }),
        refused('between 0 and 30'),
      );
    });

    test('send_input shows control keys', () async {
      final p = await plan('send_input', {
        'session_id': 's-1',
        'data': 'q\u001b',
      });
      expect(p.details.single.value, 'q<Esc>');
      await p.run();
      expect(backend.calls, ['sendRaw s-1 q\u001b']);
    });

    test('open_session names the host and is never remembered', () async {
      final p = await plan('open_session', {'host_id': 'h-db'});
      expect(p.target, 'db — root@db.internal:2222');
      expect(p.rememberScope, isNull);
      await p.run();
      expect(backend.calls, ['openSession h-db']);
      expect(
        () => plan('open_session', {'host_id': 'x'}),
        refused('No saved host'),
      );
    });

    test('start and stop a tunnel', () async {
      await (await plan('start_tunnel', {'tunnel_id': 't-1'})).run();
      await (await plan('stop_tunnel', {'tunnel_id': 't-1'})).run();
      expect(backend.calls, ['startTunnel t-1', 'stopTunnel t-1']);
      expect(
        () => plan('stop_tunnel', {'tunnel_id': 'x'}),
        refused('No saved tunnel'),
      );
    });

    test(
      'run_snippet renders with built-ins, defaults and given values',
      () async {
        final p = await plan('run_snippet', {
          'snippet_id': 'sn-1',
          'session_id': 's-1',
          'variables': {'service': 'nginx'},
        });
        const rendered = 'sudo systemctl restart nginx # on 10.0.0.4 info';
        expect(p.details.map((d) => d.value), ['Restart a service', rendered]);
        expect(p.rememberScope, 's-1/sn-1');
        await p.run();
        expect(backend.calls, ['typeLines s-1 $rendered 3']);
      },
    );

    test(
      'run_snippet refuses when a variable without a default is missing',
      () {
        expect(
          () =>
              plan('run_snippet', {'snippet_id': 'sn-1', 'session_id': 's-1'}),
          refused('Missing values for: service'),
        );
        expect(
          () => plan('run_snippet', {
            'snippet_id': 'sn-1',
            'session_id': 's-1',
            'variables': {'service': 3},
          }),
          refused('map names to strings'),
        );
      },
    );

    test(
      'sftp tools need an absolute local path and show both paths',
      () async {
        final local = path.join(path.current, 'report.txt');
        final down = await plan('sftp_download', {
          'session_id': 's-1',
          'remote_path': '~/report.txt',
          'local_path': local,
        });
        expect(down.details.map((d) => d.kind), [
          ApprovalDetailKind.remotePath,
          ApprovalDetailKind.localPath,
        ]);
        expect(down.rememberScope, isNull);
        await down.run();

        final up = await plan('sftp_upload', {
          'session_id': 's-1',
          'local_path': local,
          'remote_path': '/tmp/r.txt',
          'overwrite': true,
        });
        expect(up.details.last.kind, ApprovalDetailKind.overwrite);
        await up.run();
        expect(backend.calls, [
          'download s-1 ~/report.txt $local false',
          'upload s-1 $local /tmp/r.txt true',
        ]);

        expect(
          () => plan('sftp_download', {
            'session_id': 's-1',
            'remote_path': 'a',
            'local_path': 'relative.txt',
          }),
          refused('absolute path'),
        );
      },
    );
  });
}
