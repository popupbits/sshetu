import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import '../sessions/session_manager.dart';
import 'data/reachability_probe.dart';
import 'data/reachability_scheduler.dart';
import 'domain/reachability.dart';
import 'domain/ssh_host.dart';
import 'hosts_controller.dart';

/// The probe the host list uses, or null for none.
///
/// **Null unless `main` installs one**, which it does with the real TCP
/// probe. Every widget test that renders a host list would otherwise open
/// real sockets to fixture hostnames — and leave a connect timer pending when
/// the test ends. A test that wants reachability overrides this with a fake.
final reachabilityProbeProvider = Provider<ReachabilityProbe?>((ref) => null);

/// Timers, clock and randomness for the scheduler. Overridden in tests.
@immutable
class ReachabilityClock {
  const ReachabilityClock({this.timer, this.now, this.random});

  final ProbeTimerFactory? timer;
  final DateTime Function()? now;
  final Random? random;
}

final reachabilityClockProvider = Provider<ReachabilityClock>(
  (ref) => const ReachabilityClock(),
);

const _keyInterval = 'settings.reachabilityInterval';

/// The interval the user chose, or null for "the default for this device".
///
/// Kept beside the feature rather than in `AppSettings`: the unset state has a
/// meaning of its own — follow [ReachabilityInterval.defaultFor] — which a
/// field with a fixed default could not express.
class ReachabilityIntervalSetting extends Notifier<ReachabilityInterval?> {
  @override
  ReachabilityInterval? build() => ReachabilityInterval.fromId(
    ref.read(sharedPreferencesProvider).getString(_keyInterval),
  );

  void set(ReachabilityInterval interval) {
    state = interval;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(_keyInterval, interval.id)
          .then((_) {}, onError: (Object _) {}),
    );
  }
}

final reachabilityIntervalSettingProvider =
    NotifierProvider<ReachabilityIntervalSetting, ReachabilityInterval?>(
      ReachabilityIntervalSetting.new,
    );

/// The interval in force: the user's choice, or this platform's default.
final effectiveReachabilityIntervalProvider = Provider<ReachabilityInterval>(
  (ref) =>
      ref.watch(reachabilityIntervalSettingProvider) ??
      ReachabilityInterval.defaultFor(defaultTargetPlatform),
);

/// Which saved hosts a connected session proves are up.
@immutable
class LiveSessionHosts {
  const LiveSessionHosts({this.hostIds = const {}});

  final Set<String> hostIds;

  bool contains(String hostId) => hostIds.contains(hostId);

  @override
  bool operator ==(Object other) =>
      other is LiveSessionHosts &&
      other.hostIds.length == hostIds.length &&
      other.hostIds.containsAll(hostIds);

  @override
  int get hashCode => Object.hashAllUnordered(hostIds);
}

/// Hosts with a live session — shell open over a working link — read from
/// the session manager.
///
/// Read-only: it listens to each tab for connection changes and never touches
/// a session.
final liveSessionHostsProvider = Provider<LiveSessionHosts>((ref) {
  final sessions = ref.watch(sessionManagerProvider);
  for (final session in sessions) {
    session.addListener(ref.invalidateSelf);
    ref.onDispose(() => session.removeListener(ref.invalidateSelf));
  }
  return LiveSessionHosts(
    hostIds: {
      for (final session in sessions)
        if (session.isLive) session.hostId,
    },
  );
});

/// Whether a host's row counts as proven up by a session: its own session, or
/// one to another directly-reached host at the same address.
bool sessionProves(SshHost host, LiveSessionHosts live, List<SshHost> hosts) {
  if (live.contains(host.id)) return true;
  final address = probeAddressOf(host);
  if (address == null) return false;
  return hosts.any(
    (other) => live.contains(other.id) && probeAddressOf(other) == address,
  );
}

/// What the host list knows about reachability.
@immutable
class ReachabilityState {
  const ReachabilityState({this.enabled = false, this.results = const {}});

  /// False when there is no probe or checking is off; rows then show nothing.
  final bool enabled;

  /// By [ProbeAddress.key].
  final Map<String, ProbeResult> results;
}

/// Owns the app's single [ReachabilityScheduler] and feeds it.
///
/// What it probes comes from the saved hosts and the live sessions; when it
/// probes comes from the interval setting and from [setVisible], which the
/// host list calls as it appears, disappears, and follows the app in and out
/// of the foreground.
class ReachabilityController extends Notifier<ReachabilityState> {
  ReachabilityScheduler? _scheduler;
  final Set<Object> _visible = {};

  @override
  ReachabilityState build() {
    final probe = ref.watch(reachabilityProbeProvider);
    _scheduler?.dispose();
    _scheduler = null;
    if (probe == null) return const ReachabilityState();

    final clock = ref.watch(reachabilityClockProvider);
    final scheduler = _scheduler = ReachabilityScheduler(
      probe: probe,
      timer: clock.timer,
      now: clock.now,
      random: clock.random,
      onChanged: _publish,
    );
    ref.onDispose(scheduler.dispose);

    void retarget() => scheduler.setTargets(
      probeTargets(
        ref.read(hostsProvider).value ?? const [],
        connectedHostIds: ref.read(liveSessionHostsProvider).hostIds,
      ),
    );

    ref
      ..listen(hostsProvider, (_, _) => retarget())
      ..listen(liveSessionHostsProvider, (_, _) => retarget())
      ..listen(effectiveReachabilityIntervalProvider, (_, next) {
        scheduler.setInterval(next.period);
        state = ReachabilityState(
          enabled: next.period != null,
          results: Map.of(scheduler.results),
        );
      });

    final interval = ref.read(effectiveReachabilityIntervalProvider);
    retarget();
    scheduler
      ..setInterval(interval.period)
      ..setActive(_visible.isNotEmpty);
    return ReachabilityState(enabled: interval.period != null);
  }

  /// Records whether [holder] — a host list on screen — can be seen. Probing
  /// runs while at least one can.
  void setVisible(Object holder, bool visible) {
    visible ? _visible.add(holder) : _visible.remove(holder);
    _scheduler?.setActive(_visible.isNotEmpty);
  }

  void _publish() {
    final scheduler = _scheduler;
    if (scheduler == null) return;
    state = ReachabilityState(
      enabled: state.enabled,
      results: Map.of(scheduler.results),
    );
  }
}

final reachabilityProvider =
    NotifierProvider<ReachabilityController, ReachabilityState>(
      ReachabilityController.new,
    );
