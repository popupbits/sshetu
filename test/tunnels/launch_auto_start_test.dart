import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';
import 'package:sshetu/features/sessions/widgets/workspace_restore_listener.dart';
import 'package:sshetu/features/tunnels/launch_auto_start.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';

Tunnel _tunnel(String id, {bool autoStart = true}) {
  final now = DateTime.utc(2026, 1, 1);
  return Tunnel(
    id: id,
    hostId: 'h-$id',
    label: id,
    kind: TunnelKind.local,
    listenPort: 8000,
    targetHost: '127.0.0.1',
    targetPort: 80,
    autoStart: autoStart,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('runLaunchAutoStart', () {
    test('off: nothing is even loaded', () async {
      var loaded = false;
      final started = await runLaunchAutoStart(
        enabled: false,
        load: () async {
          loaded = true;
          return [_tunnel('a')];
        },
        isActive: (_) => false,
        start: (_) async => fail('must not start'),
        cancelled: () => false,
      );
      expect(started, 0);
      expect(loaded, isFalse);
    });

    test('only auto-start tunnels, strictly one after another', () async {
      final log = <String>[];
      final gates = {'a': Completer<void>(), 'c': Completer<void>()};
      final run = runLaunchAutoStart(
        enabled: true,
        load: () async => [
          _tunnel('a'),
          _tunnel('b', autoStart: false),
          _tunnel('c'),
        ],
        isActive: (_) => false,
        start: (tunnel) async {
          log.add('start ${tunnel.id}');
          await gates[tunnel.id]!.future;
          log.add('done ${tunnel.id}');
        },
        cancelled: () => false,
      );

      await Future<void>.delayed(Duration.zero);
      // The second has not begun: the first's dialogs are still up.
      expect(log, ['start a']);
      gates['a']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(log, ['start a', 'done a', 'start c']);
      gates['c']!.complete();
      expect(await run, 2);
      expect(log, ['start a', 'done a', 'start c', 'done c']);
    });

    test('skips what is already starting or running', () async {
      final started = <String>[];
      final count = await runLaunchAutoStart(
        enabled: true,
        load: () async => [_tunnel('a'), _tunnel('b')],
        isActive: (tunnel) => tunnel.id == 'a',
        start: (tunnel) async => started.add(tunnel.id),
        cancelled: () => false,
      );
      expect(started, ['b']);
      expect(count, 1);
    });

    test('stops when cancelled', () async {
      final started = <String>[];
      var cancelled = false;
      await runLaunchAutoStart(
        enabled: true,
        load: () async => [_tunnel('a'), _tunnel('b')],
        isActive: (_) => false,
        start: (tunnel) async {
          started.add(tunnel.id);
          cancelled = true;
        },
        cancelled: () => cancelled,
      );
      expect(started, ['a']);
    });

    test('one failure does not stop the rest', () async {
      final started = <String>[];
      final count = await runLaunchAutoStart(
        enabled: true,
        load: () async => [_tunnel('a'), _tunnel('b')],
        isActive: (_) => false,
        start: (tunnel) async {
          if (tunnel.id == 'a') throw StateError('unreachable');
          started.add(tunnel.id);
        },
        cancelled: () => false,
      );
      expect(started, ['b']);
      expect(count, 1);
    });
  });

  group('the setting', () {
    test('off by default', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      expect(container.read(launchAutoStartSettingProvider), isFalse);
    });

    test('off without preferences at all', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(launchAutoStartSettingProvider), isFalse);
    });

    test('a foreign value reads as off', () async {
      SharedPreferences.setMockInitialValues({
        'settings.startTunnelsAtLaunch': 'yes',
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      expect(container.read(launchAutoStartSettingProvider), isFalse);
    });

    test('turning it on persists', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      container.read(launchAutoStartSettingProvider.notifier).set(true);
      expect(container.read(launchAutoStartSettingProvider), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(preferences.getBool('settings.startTunnelsAtLaunch'), isTrue);

      // And a fresh read, as at the next launch, sees it.
      final next = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(next.dispose);
      expect(next.read(launchAutoStartSettingProvider), isTrue);
    });
  });
  group('LaunchAutoStartListener', () {
    Future<(List<String>, WorkspaceRestoreGate)> pump(
      WidgetTester tester, {
      required bool enabled,
    }) async {
      SharedPreferences.setMockInitialValues({
        'settings.startTunnelsAtLaunch': enabled,
      });
      final preferences = await SharedPreferences.getInstance();
      final started = <String>[];
      final gate = WorkspaceRestoreGate();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            workspaceRestoreGateProvider.overrideWithValue(gate),
            tunnelsProvider.overrideWith(
              (ref) async => [_tunnel('a'), _tunnel('b', autoStart: false)],
            ),
            launchTunnelStarterProvider.overrideWithValue(
              (context, ref, tunnel) async => started.add(tunnel.id),
            ),
          ],
          child: const MaterialApp(
            home: LaunchAutoStartListener(child: SizedBox()),
          ),
        ),
      );
      await tester.pump();
      return (started, gate);
    }

    testWidgets('waits for the workspace restore, then starts', (tester) async {
      final (started, gate) = await pump(tester, enabled: true);
      await tester.pump();
      expect(started, isEmpty);

      gate.markFinished();
      await tester.pump();
      await tester.pump();
      expect(started, ['a']);
    });

    testWidgets('does nothing with the setting off', (tester) async {
      final (started, gate) = await pump(tester, enabled: false);
      gate.markFinished();
      await tester.pump();
      await tester.pump();
      expect(started, isEmpty);
    });
  });
}
