import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/pane_layouts.dart';
import 'package:sshetu/features/sessions/pane_tree.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/terminal_paste.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/fake_shell.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// "Type in all panes", end to end through the session manager: what each
/// pane's shell actually receives.
void main() {
  late ProviderContainer container;
  late SessionManager manager;
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
    launchers = {};
  });

  TerminalSession pane(String id) {
    final launcher = launchers[id] = FakeLauncher();
    return TerminalSession(
      id: id,
      title: id,
      hostId: 'host',
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: () async => true,
    );
  }

  List<String> written(String id) => launchers[id]!.shells.single.written;

  /// Three connected panes in one tab, a | b / c.
  Future<void> threePanes({bool startC = true}) async {
    final a = pane('a');
    final b = pane('b');
    final c = pane('c');
    manager.adopt(a);
    manager.adopt(
      b,
      split: const PaneSplitRequest(target: 'a', axis: SplitAxis.horizontal),
    );
    manager.adopt(
      c,
      split: const PaneSplitRequest(target: 'b', axis: SplitAxis.vertical),
    );
    await a.start();
    await b.start();
    if (startC) await c.start();
  }

  PaneLayouts layouts() => container.read(paneLayoutsProvider.notifier);

  test('splits share one tab, adjacent in the session list', () async {
    manager.adopt(pane('x'));
    await threePanes();
    manager.adopt(pane('y'));
    manager.adopt(
      pane('a2'),
      split: const PaneSplitRequest(target: 'a', axis: SplitAxis.vertical),
    );
    expect(container.read(sessionManagerProvider).map((s) => s.id), [
      'x',
      'a',
      'b',
      'c',
      'a2',
      'y',
    ]);
    expect(manager.tabs.map((t) => t.panes), [
      ['x'],
      ['a', 'a2', 'b', 'c'],
      ['y'],
    ]);
    expect(manager.activeId, 'a2', reason: 'a split focuses the new pane');
  });

  test('off by default: typing stays in its pane', () async {
    await threePanes();
    manager.byId('a')!.terminal.textInput('ls\r');
    expect(written('a'), ['ls\r']);
    expect(written('b'), isEmpty);
    expect(written('c'), isEmpty);
  });

  test('on: a keystroke reaches every included, connected pane', () async {
    await threePanes();
    layouts().setBroadcast('a', true);
    manager.byId('b')!.terminal.textInput('uptime\r');
    expect(written('a'), ['uptime\r']);
    expect(written('b'), ['uptime\r']);
    expect(written('c'), ['uptime\r']);
    expect(manager.broadcastCount('b'), 2);
  });

  test('an excluded pane is left out', () async {
    await threePanes();
    layouts()
      ..setBroadcast('a', true)
      ..toggleExcluded('c');
    manager.byId('a')!.terminal.textInput('x');
    expect(written('b'), ['x']);
    expect(written('c'), isEmpty);
    // Typing in the excluded pane itself goes nowhere else.
    manager.byId('c')!.terminal.textInput('y');
    expect(written('a'), ['x']);
    expect(written('c'), ['y']);
  });

  test('a disconnected pane is skipped', () async {
    await threePanes(startC: false);
    layouts().setBroadcast('a', true);
    manager.byId('a')!.terminal.textInput('z');
    expect(written('b'), ['z']);
    expect(launchers['c']!.shells, isEmpty);
    expect(manager.broadcastCount('a'), 1);
  });

  test("the terminal's own replies are never broadcast", () async {
    await threePanes();
    layouts().setBroadcast('a', true);
    // A cursor-position request: the terminal answers it on its own, and the
    // answer belongs to this shell alone.
    manager.byId('a')!.terminal.write('\x1b[6n');
    expect(written('a'), hasLength(1));
    expect(written('a').single, startsWith('\x1b['));
    expect(written('b'), isEmpty);
    expect(written('c'), isEmpty);
  });

  test('closing panes turns broadcast off at the last other pane', () async {
    await threePanes();
    layouts().setBroadcast('a', true);
    manager.close('c');
    expect(layouts().treeFor('a')!.broadcast, isTrue);
    manager.close('b');
    expect(layouts().treeFor('a'), isNull, reason: 'one pane is a plain tab');
    manager.adopt(
      pane('d'),
      split: const PaneSplitRequest(target: 'a', axis: SplitAxis.horizontal),
    );
    expect(layouts().treeFor('a')!.broadcast, isFalse);
  });

  test('closing a pane focuses its neighbour in the same tab', () async {
    manager.adopt(pane('x'));
    await threePanes();
    manager.select('c');
    manager.close('c');
    expect(manager.activeId, 'b');
    manager.closeTab('a');
    expect(manager.activeId, 'x');
    expect(container.read(sessionManagerProvider).map((s) => s.id), ['x']);
  });

  test('next tab skips the panes of a split; selecting returns to its '
      'last pane', () async {
    manager.adopt(pane('x'));
    await threePanes();
    manager.select('b');
    manager.cycle(1);
    expect(manager.activeId, 'x');
    manager.cycle(1);
    expect(manager.activeId, 'b');
    manager.selectTabAt(1);
    expect(manager.activeId, 'x');
    manager.selectTabAt(2);
    expect(manager.activeId, 'b');
    manager.cyclePane(1);
    expect(manager.activeId, 'c');
  });

  group('paste', () {
    Future<void> paste(WidgetTester tester, String raw) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () {
                    final source = manager.byId('a')!;
                    pasteTextInto(
                      context,
                      ref,
                      source.terminal,
                      raw,
                      deliver: (text) => manager.pasteToTab(source, text),
                    );
                  },
                  child: const Text('paste'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('paste'));
      await tester.pumpAndSettle();
    }

    testWidgets('is sanitised once, then reaches every pane once', (
      tester,
    ) async {
      await tester.runAsync(threePanes);
      layouts().setBroadcast('a', true);
      await paste(tester, 'echo ${String.fromCharCode(0x202e)}evil\x1b[31m');
      for (final id in ['a', 'b', 'c']) {
        expect(written(id), ['echo evil'], reason: id);
      }
      // The toast about the removed characters.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });

    testWidgets('a multi-line paste is confirmed before any pane gets it', (
      tester,
    ) async {
      await tester.runAsync(threePanes);
      layouts().setBroadcast('a', true);
      await paste(tester, 'rm -rf build\n');
      for (final id in ['a', 'b', 'c']) {
        expect(written(id), isEmpty, reason: id);
      }
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      for (final id in ['a', 'b', 'c']) {
        expect(written(id), hasLength(1), reason: id);
      }
    });

    testWidgets('with broadcast off only the pane pasted into gets it', (
      tester,
    ) async {
      await tester.runAsync(threePanes);
      await paste(tester, 'whoami');
      expect(written('a'), ['whoami']);
      expect(written('b'), isEmpty);
    });
  });
}
