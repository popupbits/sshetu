import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/mcp/domain/mcp_backend.dart';
import 'package:sshetu/features/mcp/domain/mcp_tool.dart';
import 'package:sshetu/features/mcp/mcp_server_controller.dart';
import 'package:sshetu/features/sessions/pane_layouts.dart';
import 'package:sshetu/features/sessions/pane_tree.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';

import '../../sessions/reconnect_triggers_test.dart' show FakeTriggers;
import '../../support/fake_shell.dart';

/// The real backend over the real session manager, with fake shells: what
/// the MCP tools read from a tab and what they type into it.
void main() {
  late ProviderContainer container;
  late SessionManager manager;
  late McpBackend backend;
  late Map<String, FakeLauncher> launchers;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final triggers = FakeTriggers();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(triggers),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(triggers.dispose);
    manager = container.read(sessionManagerProvider.notifier);
    backend = container.read(mcpBackendProvider);
    launchers = {};
  });

  TerminalSession pane(String id) {
    final launcher = launchers[id] = FakeLauncher();
    return TerminalSession(
      id: id,
      title: 'web-$id',
      hostId: 'host',
      connection: SshConnection(
        target: const SshTarget(
          hostname: 'example.invalid',
          username: 'me',
          port: 2200,
        ),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: () async => true,
    );
  }

  FakeShell shell(String id) => launchers[id]!.shells.single;

  test('lists open sessions with their status', () async {
    final a = pane('a');
    manager.adopt(a);
    await a.start();
    final b = pane('b');
    manager.adopt(b);

    final sessions = backend.sessions();
    expect(sessions.map((s) => s.id), ['a', 'b']);
    expect(sessions.first.address, 'me@example.invalid:2200');
    expect(sessions.first.status, 'running');
    expect(sessions.last.status, 'connecting');
    expect(sessions.where((s) => s.isActive), hasLength(1));
  });

  test('reads the terminal buffer as text', () async {
    final a = pane('a');
    manager.adopt(a);
    await a.start();
    a.terminal.write('\x1b[31mred\x1b[0m line\r\nuser@box:~\$ ');
    expect(backend.terminalTail('a', 10), 'red line\nuser@box:~\$');
    expect(
      () => backend.terminalTail('zzz', 10),
      throwsA(isA<McpToolException>()),
    );
  });

  test('types a command with Enter, and returns what came back', () async {
    final a = pane('a');
    manager.adopt(a);
    await a.start();
    final result = backend.typeLines(
      'a',
      'echo hi',
      const Duration(seconds: 2),
    );
    // The shell answers once it has the command.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(shell('a').written.join(), 'echo hi\r');
    shell('a').emit('hi\r\nuser@box:~\$ ');
    expect(await result, 'hi\nuser@box:~\$ ');
  });

  test('typing never reaches the other panes of a broadcasting tab', () async {
    final a = pane('a');
    final b = pane('b');
    manager.adopt(a);
    manager.adopt(
      b,
      split: const PaneSplitRequest(target: 'a', axis: SplitAxis.horizontal),
    );
    await a.start();
    await b.start();
    container.read(paneLayoutsProvider.notifier).setBroadcast('a', true);
    // Proof that broadcast is on: what the user types into a reaches b.
    a.terminal.textInput('x');
    expect(shell('b').written, ['x']);

    await backend.typeLines('a', 'whoami', Duration.zero);
    expect(shell('a').written.join(), endsWith('whoami\r'));
    expect(shell('b').written, ['x'], reason: 'the approved session only');
    expect(manager.broadcastCount('a'), 1, reason: 'and broadcast is still on');
  });

  test('sends raw input untouched', () async {
    final a = pane('a');
    manager.adopt(a);
    await a.start();
    await backend.sendRaw('a', '\u0003', Duration.zero);
    expect(shell('a').written, ['\u0003']);
  });

  test('refuses a session that is not connected', () async {
    final a = pane('a');
    manager.adopt(a);
    expect(
      () => backend.typeLines('a', 'ls', Duration.zero),
      throwsA(isA<McpToolException>()),
    );
    expect(
      () => backend.sendRaw('missing', 'x', Duration.zero),
      throwsA(isA<McpToolException>()),
    );
  });
}
