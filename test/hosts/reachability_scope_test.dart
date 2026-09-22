import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/hosts/domain/reachability.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/hosts/reachability_controller.dart';
import 'package:sshetu/features/hosts/widgets/reachability_scope.dart';
import 'package:sshetu/features/sessions/session_manager.dart';

import '../support/fake_shell.dart';
import '../support/fake_timers.dart';
import '../support/fake_reachability.dart';

/// The scheduler follows the host list on and off screen and the app in and
/// out of the foreground, and leaves proven and jump-host hosts alone.
void main() {
  final now = DateTime.utc(2026);
  SshHost host(String id, String hostname, {String? jump}) => SshHost(
    id: id,
    label: id,
    hostname: hostname,
    username: 'root',
    jumpHostId: jump,
    createdAt: now,
    updatedAt: now,
  );

  late FakeTimers timers;
  late FakeProbe probe;
  late ProviderContainer container;

  Future<void> setUpContainer(List<SshHost> hosts) async {
    SharedPreferences.setMockInitialValues({
      'settings.reachabilityInterval': '1m',
    });
    final preferences = await SharedPreferences.getInstance();
    timers = FakeTimers();
    probe = FakeProbe()
      ..autoReply = const ProbeOutcome.up(Duration(milliseconds: 5));
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        hostsProvider.overrideWith((ref) => hosts),
        reachabilityProbeProvider.overrideWithValue(probe),
        reachabilityClockProvider.overrideWithValue(
          ReachabilityClock(
            timer: timers.create,
            now: timers.now,
            random: FixedRandom(0.5),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hostsProvider.future);
  }

  Widget app({required bool onStage, bool mounted = true}) =>
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TickerMode(
            enabled: onStage,
            child: mounted
                ? const ReachabilityScope(child: SizedBox())
                : const SizedBox(),
          ),
        ),
      );

  /// Lets the fake clock run [by], settling each probe as it goes.
  Future<void> elapse(WidgetTester tester, Duration by) async {
    timers.elapse(by);
    await tester.pump();
  }

  Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }

  testWidgets('probes once the list is on screen, not before', (tester) async {
    await setUpContainer([host('a', 'a.example'), host('b', 'b.example')]);

    await tester.pumpWidget(app(onStage: true, mounted: false));
    await elapse(tester, const Duration(minutes: 5));
    expect(probe.calls, isEmpty, reason: 'no list, no probes');

    await tester.pumpWidget(app(onStage: true));
    await elapse(tester, const Duration(seconds: 1));
    expect(probe.calls.map((a) => a.key), ['a.example:22', 'b.example:22']);
    expect(container.read(reachabilityProvider).results, hasLength(2));
  });

  testWidgets('an offstage branch or covered route does not probe', (
    tester,
  ) async {
    await setUpContainer([host('a', 'a.example')]);

    await tester.pumpWidget(app(onStage: false));
    await elapse(tester, const Duration(minutes: 5));
    expect(probe.calls, isEmpty);

    await tester.pumpWidget(app(onStage: true));
    await elapse(tester, const Duration(seconds: 1));
    expect(probe.calls, hasLength(1));

    await tester.pumpWidget(app(onStage: false));
    await elapse(tester, const Duration(minutes: 10));
    expect(probe.calls, hasLength(1));
    expect(timers.pending, 0);
  });

  testWidgets('pauses in the background and resumes in front', (tester) async {
    await setUpContainer([host('a', 'a.example')]);
    await tester.pumpWidget(app(onStage: true));
    await elapse(tester, const Duration(seconds: 1));
    expect(probe.calls, hasLength(1));

    await lifecycle(tester, AppLifecycleState.inactive);
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.paused);
    await elapse(tester, const Duration(minutes: 10));
    expect(probe.calls, hasLength(1), reason: 'nothing while paused');
    expect(timers.pending, 0);

    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.inactive);
    await lifecycle(tester, AppLifecycleState.resumed);
    await elapse(tester, const Duration(seconds: 1));
    expect(probe.calls, hasLength(2), reason: 'stale, so checked on return');
  });

  testWidgets('leaving the screen stops probing', (tester) async {
    await setUpContainer([host('a', 'a.example')]);
    await tester.pumpWidget(app(onStage: true));
    await elapse(tester, const Duration(seconds: 1));

    await tester.pumpWidget(app(onStage: true, mounted: false));
    await elapse(tester, const Duration(minutes: 10));
    expect(probe.calls, hasLength(1));
  });

  testWidgets('never probes a host behind a jump host', (tester) async {
    await setUpContainer([
      host('bastion', 'bastion.example'),
      host('inner', '10.9.0.4', jump: 'bastion'),
    ]);
    await tester.pumpWidget(app(onStage: true));
    await elapse(tester, const Duration(seconds: 1));
    expect(probe.calls.map((a) => a.key), ['bastion.example:22']);
  });

  testWidgets('a live session proves its host up without a probe', (
    tester,
  ) async {
    await setUpContainer([host('a', 'a.example'), host('b', 'b.example')]);

    final launcher = FakeLauncher();
    final session = TerminalSession(
      id: 'a-1',
      title: 'a',
      hostId: 'a',
      connection: SshConnection(
        target: const SshTarget(hostname: 'a.example', username: 'root'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: () async => true,
      reconnectTimer: timers.create,
      clock: timers.now,
    );
    container.read(sessionManagerProvider.notifier).adopt(session);
    await session.start();
    expect(container.read(liveSessionHostsProvider).contains('a'), isTrue);

    await tester.pumpWidget(app(onStage: true));
    await elapse(tester, const Duration(seconds: 1));
    expect(probe.calls.map((a) => a.key), ['b.example:22']);

    // The session ends: its host goes back to being probed.
    container.read(sessionManagerProvider.notifier).close(session.id);
    await tester.pump();
    expect(container.read(liveSessionHostsProvider).contains('a'), isFalse);
    await elapse(tester, const Duration(seconds: 1));
    expect(probe.calls.map((a) => a.key), ['b.example:22', 'a.example:22']);
    // The closed session's own drain timeout, so no timer outlives the test.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('turning checking off stops it and hides the state', (
    tester,
  ) async {
    await setUpContainer([host('a', 'a.example')]);
    await tester.pumpWidget(app(onStage: true));
    await elapse(tester, const Duration(seconds: 1));
    expect(container.read(reachabilityProvider).enabled, isTrue);

    container
        .read(reachabilityIntervalSettingProvider.notifier)
        .set(ReachabilityInterval.off);
    await tester.pump();
    expect(container.read(reachabilityProvider).enabled, isFalse);
    await elapse(tester, const Duration(minutes: 30));
    expect(probe.calls, hasLength(1));
  });
}
