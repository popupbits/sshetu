import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ssh/tunnel_runner.dart';
import 'domain/far_end.dart';
import 'tunnels_controller.dart';

/// Whether each running local forward's target is listening, keyed by
/// tunnel id — checked every [interval] while someone is looking.
///
/// Checked only while the Tunnels screen is on screen and the app is in the
/// foreground ([watch] / [unwatch], driven by [FarEndWatcher]). Every check
/// is a channel opened on someone's server; a status nobody can see is not
/// worth one every thirty seconds, let alone from a phone in a pocket.
class FarEndMonitor extends Notifier<Map<String, FarEndStatus>> {
  FarEndMonitor({this.interval = const Duration(seconds: 30)});

  final Duration interval;

  Timer? _timer;
  int _watchers = 0;
  Future<void>? _inFlight;

  @override
  Map<String, FarEndStatus> build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    // A forward that starts while the screen is watched is checked right
    // away, instead of saying nothing for up to [interval].
    ref.listen(tunnelRunnersProvider, (previous, next) {
      if (_watchers == 0) return;
      for (final entry in next.entries) {
        final was = previous?[entry.key]?.isRunning ?? false;
        if (entry.value.isRunning && !was) unawaited(_checkOne(entry.key));
      }
      // A forward that stopped has no far end worth reporting.
      final stale = [
        for (final id in state.keys)
          if (!(next[id]?.isRunning ?? false)) id,
      ];
      if (stale.isNotEmpty) {
        state = {
          for (final entry in state.entries)
            if (!stale.contains(entry.key)) entry.key: entry.value,
        };
      }
    });
    return const {};
  }

  bool get isWatching => _watchers > 0;

  /// One more viewer. The first starts checking, immediately and then every
  /// [interval].
  void watch() {
    _watchers++;
    if (_watchers == 1) {
      _timer = Timer.periodic(interval, (_) => unawaited(check()));
      unawaited(check());
    }
  }

  /// One fewer viewer. The last stops checking; results stay until the
  /// next check replaces them.
  void unwatch() {
    if (_watchers == 0) return;
    _watchers--;
    if (_watchers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Checks every running forward, one at a time — a slow server stretches
  /// the round rather than stacking channels up behind each other.
  ///
  /// A call while a round is running returns that round.
  Future<void> check() =>
      _inFlight ??= _round().whenComplete(() => _inFlight = null);

  Future<void> _round() async {
    try {
      final running = [
        for (final entry in ref.read(tunnelRunnersProvider).entries)
          if (entry.value.isRunning) entry.key,
      ];
      final next = <String, FarEndStatus>{};
      for (final id in running) {
        final result = await ref
            .read(tunnelRunnersProvider.notifier)
            .probeTarget(id);
        if (result != null) next[id] = result;
      }
      if (ref.mounted) state = next;
    } on Object {
      // A failed round leaves the last known answers in place.
    }
  }

  Future<void> _checkOne(String id) async {
    final result = await ref
        .read(tunnelRunnersProvider.notifier)
        .probeTarget(id);
    if (result == null || !ref.mounted) return;
    state = {...state, id: result};
  }
}

final farEndMonitorProvider =
    NotifierProvider<FarEndMonitor, Map<String, FarEndStatus>>(
      FarEndMonitor.new,
    );

/// Watches far ends for as long as [child] is on screen: mounted, in the
/// visible branch of the shell (go_router turns tickers off in the others)
/// and with the app in the foreground.
class FarEndWatcher extends ConsumerStatefulWidget {
  const FarEndWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FarEndWatcher> createState() => _FarEndWatcherState();
}

class _FarEndWatcherState extends ConsumerState<FarEndWatcher> {
  late final AppLifecycleListener _lifecycle;
  late final FarEndMonitor _monitor;
  bool _foreground = true;
  bool _visible = false;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _monitor = ref.read(farEndMonitorProvider.notifier);
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _foreground = false;
        _sync();
      },
      onShow: () {
        _foreground = true;
        _sync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  void _sync() {
    final should = _visible && _foreground;
    if (should == _watching) return;
    _watching = should;
    should ? _monitor.watch() : _monitor.unwatch();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (_watching) _monitor.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The far end of [tunnelId] worth showing, or null: only for a running
/// local forward whose check gave a definite answer.
FarEndStatus? visibleFarEnd(TunnelRunnerStatus status, FarEndStatus? farEnd) {
  if (!status.isRunning || farEnd == null) return null;
  return farEnd == FarEndStatus.unknown ? null : farEnd;
}
