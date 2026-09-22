import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/pane_layouts.dart';
import 'package:sshetu/features/sessions/pane_tree.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/workspace_restore.dart';

import '../support/fake_shell.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// Version 2 of the saved workspace: split layouts, and version 1 files
/// written before splits existed.
void main() {
  const a = SavedTab(hostId: 'a');
  const b = SavedTab(hostId: 'b');
  const c = SavedTab(hostId: 'c');

  /// Panes named by tab position, as the file stores them.
  final bc = PaneTree.single('1').split('1', '2', SplitAxis.vertical);

  test('a version-1 file still reads, as tabs with no splits', () {
    final back = SavedWorkspace.fromJson({
      'v': 1,
      'tabs': [
        {'host': 'a'},
        {'host': 'b'},
      ],
      'selected': 1,
    })!;
    expect(back.tabs, const [a, b]);
    expect(back.selected, 1);
    expect(back.layouts, isEmpty);
  });

  test('version 2 round-trips its layouts', () {
    final saved = SavedWorkspace(tabs: const [a, b, c], layouts: [bc]);
    final json = jsonDecode(jsonEncode(saved.toJson())) as Map;
    expect(json['v'], 2);
    final back = SavedWorkspace.fromJson(json)!;
    expect(back.layouts.single.root, bc.root);
    expect(back.layouts.single.panes, ['1', '2']);
  });

  test('a layout follows its tabs past a malformed one', () {
    final back = SavedWorkspace.fromJson({
      'v': 2,
      'tabs': [
        {'nothing': true},
        {'host': 'a'},
        {'host': 'b'},
      ],
      'layouts': [
        PaneTree.single('1').split('1', '2', SplitAxis.horizontal).toJson(),
      ],
    })!;
    expect(back.tabs, const [a, b]);
    expect(back.layouts.single.panes, ['0', '1']);
  });

  test('a layout naming a tab that does not exist is dropped', () {
    final back = SavedWorkspace.fromJson({
      'v': 2,
      'tabs': [
        {'host': 'a'},
      ],
      'layouts': [
        PaneTree.single('0').split('0', '7', SplitAxis.horizontal).toJson(),
      ],
    })!;
    expect(back.layouts, isEmpty);
  });

  test('planning closes a deleted host out of its layout', () {
    final three = PaneTree.single('0')
        .split('0', '1', SplitAxis.horizontal)
        .split('1', '2', SplitAxis.vertical);
    final plan = planRestore(
      SavedWorkspace(tabs: const [a, b, c], layouts: [three]),
      {'a', 'c'},
    );
    expect(plan.tabs, const [a, c]);
    expect(plan.layouts.single.panes, ['0', '1']);

    // Down to one pane, it is a plain tab again.
    final alone = planRestore(
      SavedWorkspace(tabs: const [a, b, c], layouts: [bc]),
      {'a', 'b'},
    );
    expect(alone.layouts, isEmpty);
  });

  group('saving', () {
    late ProviderContainer container;

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
    });

    TerminalSession tab(String id) => TerminalSession(
      id: id,
      title: id,
      hostId: id,
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: FakeLauncher(),
      probe: () async => true,
    );

    test('writes the split tree, by tab position, and a resize', () async {
      final manager = container.read(sessionManagerProvider.notifier);
      manager.adopt(tab('x'));
      manager.adopt(tab('y'));
      manager.adopt(
        tab('z'),
        split: const PaneSplitRequest(target: 'y', axis: SplitAxis.vertical),
      );
      await pumpEventQueue();

      var saved = container.read(workspaceStoreProvider).read()!;
      expect(saved.tabs.map((t) => t.hostId), ['x', 'y', 'z']);
      expect(saved.layouts.single.panes, ['1', '2']);
      expect(saved.layouts.single.focused, '2');

      container.read(paneLayoutsProvider.notifier).resize('y', '', 0.25);
      await pumpEventQueue();
      saved = container.read(workspaceStoreProvider).read()!;
      expect((saved.layouts.single.root as PaneBranch).ratio, 0.25);
    });

    test('never writes broadcast', () async {
      final manager = container.read(sessionManagerProvider.notifier);
      manager.adopt(tab('x'));
      manager.adopt(
        tab('y'),
        split: const PaneSplitRequest(target: 'x', axis: SplitAxis.horizontal),
      );
      container.read(paneLayoutsProvider.notifier).setBroadcast('x', true);
      await pumpEventQueue();
      final saved = container.read(workspaceStoreProvider).read()!;
      expect(saved.layouts.single.broadcast, isFalse);
    });
  });
}
