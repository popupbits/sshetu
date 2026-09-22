import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/workspace_restore.dart';

import '../support/fake_shell.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

void main() {
  group('planning', () {
    const a = SavedTab(hostId: 'a', tmuxName: 'sshetu-dev001-aaaaaaaa');
    const b = SavedTab(hostId: 'b');
    const c = SavedTab(hostId: 'c', tmuxName: 'sshetu-dev001-cccccccc');

    test('keeps order and the selected tab', () {
      final plan = planRestore(
        const SavedWorkspace(tabs: [a, b, c], selected: 2),
        {'a', 'b', 'c'},
      );
      expect(plan.tabs, [a, b, c]);
      expect(plan.selected, 2);
      expect(plan.dropped, 0);
    });

    test('drops tabs whose host was deleted, selection follows its tab', () {
      final plan = planRestore(
        const SavedWorkspace(tabs: [a, b, c], selected: 2),
        {'a', 'c'},
      );
      expect(plan.tabs, [a, c]);
      expect(plan.selected, 1);
      expect(plan.dropped, 1);
    });

    test('a dropped selected tab passes selection to the one before it', () {
      final plan = planRestore(
        const SavedWorkspace(tabs: [a, b, c], selected: 1),
        {'a', 'c'},
      );
      expect(plan.selected, 0);
    });

    test('...or to the first, when nothing came before it', () {
      final plan = planRestore(
        const SavedWorkspace(tabs: [a, b, c], selected: 0),
        {'b', 'c'},
      );
      expect(plan.tabs, [b, c]);
      expect(plan.selected, 0);
    });

    test('every host deleted is an empty plan', () {
      final plan = planRestore(
        const SavedWorkspace(tabs: [a, b], selected: 0),
        const {},
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.selected, isNull);
    });
  });

  group('stored form', () {
    test('round-trips through JSON', () {
      const saved = SavedWorkspace(
        tabs: [
          SavedTab(hostId: 'a', tmuxName: 'sshetu-dev001-aaaaaaaa'),
          SavedTab(
            hostId: 'b',
            tmuxName: 'sshetu-other1-bbbbbbbb',
            ownsTmux: false,
          ),
          SavedTab(hostId: 'c'),
        ],
        selected: 1,
      );
      final back = SavedWorkspace.fromJson(
        jsonDecode(jsonEncode(saved.toJson())),
      )!;
      expect(back.tabs, saved.tabs);
      expect(back.selected, 1);
    });

    test('an unsafe tmux name from disk is dropped, not trusted', () {
      final back = SavedWorkspace.fromJson({
        'v': 1,
        'tabs': [
          {'host': 'a', 'tmux': "x'; rm -rf ~"},
          {'nothing': true},
        ],
        'selected': 5,
      })!;
      expect(back.tabs, [const SavedTab(hostId: 'a')]);
      expect(back.selected, isNull);
    });

    test('a version this build does not know is ignored', () {
      expect(SavedWorkspace.fromJson({'v': 99, 'tabs': []}), isNull);
      expect(SavedWorkspace.fromJson('garbage'), isNull);
    });

    test('the store survives a corrupt value', () async {
      SharedPreferences.setMockInitialValues({WorkspaceStore.key: '{nope'});
      final store = WorkspaceStore(await SharedPreferences.getInstance());
      expect(store.read(), isNull);
    });
  });

  group('sequencing', () {
    test('one tab at a time: the next waits for the last to finish', () async {
      const plan = RestorePlan(
        tabs: [
          SavedTab(hostId: 'a'),
          SavedTab(hostId: 'b'),
          SavedTab(hostId: 'c'),
        ],
      );
      final gates = {
        for (final host in ['a', 'b', 'c']) host: Completer<String?>(),
      };
      final started = <String>[];
      final done = runRestore(
        plan,
        open: (tab) {
          started.add(tab.hostId);
          return gates[tab.hostId]!.future;
        },
      );

      await pumpEventQueue();
      // The first tab's dialogs are up; nothing else has begun.
      expect(started, ['a']);

      gates['a']!.complete('tab-a');
      await pumpEventQueue();
      expect(started, ['a', 'b']);

      // One that fails does not stop the rest.
      gates['b']!.completeError(StateError('refused'));
      await pumpEventQueue();
      expect(started, ['a', 'b', 'c']);

      gates['c']!.complete(null);
      expect(await done, ['tab-a', null, null]);
    });

    test('stops when cancelled', () async {
      const plan = RestorePlan(
        tabs: [
          SavedTab(hostId: 'a'),
          SavedTab(hostId: 'b'),
        ],
      );
      var cancelled = false;
      final opened = <String>[];
      await runRestore(
        plan,
        cancelled: () => cancelled,
        open: (tab) async {
          opened.add(tab.hostId);
          cancelled = true;
          return tab.hostId;
        },
      );
      expect(opened, ['a']);
    });
  });

  group('the session list remembers its tabs', () {
    late ProviderContainer container;
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
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

    TerminalSession tab(
      String id,
      String hostId, {
      bool keep = true,
      bool owns = true,
    }) => TerminalSession(
      id: id,
      title: id,
      hostId: hostId,
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      keepOnServer: keep,
      tmuxName: 'sshetu-dev001-${id.padRight(8, '0')}',
      ownsTmuxSession: owns,
      launcher: FakeLauncher()..origins = [ShellOrigin.tmuxCreated],
      probe: () async => true,
    );

    SavedWorkspace? saved() => container.read(workspaceStoreProvider).read();

    test('on every change: open, select, close', () async {
      final manager = container.read(sessionManagerProvider.notifier);
      manager.adopt(tab('one', 'h1'));
      manager.adopt(tab('two', 'h2', keep: false));
      manager.adopt(tab('three', 'h3', owns: false));
      await pumpEventQueue();

      expect(saved()!.tabs, const [
        SavedTab(hostId: 'h1', tmuxName: 'sshetu-dev001-one00000'),
        // A plain shell has nothing on the server to come back to.
        SavedTab(hostId: 'h2'),
        SavedTab(
          hostId: 'h3',
          tmuxName: 'sshetu-dev001-three000',
          ownsTmux: false,
        ),
      ]);

      manager.select('one');
      await pumpEventQueue();
      expect(saved()!.selected, 0);

      manager.close('one');
      await pumpEventQueue();
      expect(saved()!.tabs.map((t) => t.hostId), ['h2', 'h3']);
    });

    test('not while a restore is part-way through', () async {
      final manager = container.read(sessionManagerProvider.notifier);
      manager.adopt(tab('one', 'h1'));
      await pumpEventQueue();

      manager.beginRestore();
      manager.adopt(tab('two', 'h2'));
      await pumpEventQueue();
      expect(saved()!.tabs, hasLength(1));

      manager.endRestore();
      await pumpEventQueue();
      expect(saved()!.tabs, hasLength(2));
    });

    test('an app exiting is not the user closing every tab', () async {
      final manager = container.read(sessionManagerProvider.notifier);
      manager.adopt(tab('one', 'h1'));
      await pumpEventQueue();

      container.dispose();
      await pumpEventQueue();
      expect(WorkspaceStore(preferences).read()!.tabs.single.hostId, 'h1');
    });
  });
}
