import 'dart:async';
import 'dart:collection';
import 'dart:math';

import '../domain/reachability.dart';
import 'reachability_probe.dart';

/// Creates a timer, matching `Timer.new`, so tests can move time by hand.
typedef ProbeTimerFactory = Timer Function(Duration delay, void Function() fn);

/// The one place in the app that decides when an address is probed.
///
/// Built around a failure other SSH clients have shipped: polling every saved
/// host every few seconds, which on a server behind `ufw limit` (six
/// connections in thirty seconds) or fail2ban locks the user out of their own
/// machine. So:
///
///  * **One probe per address**, however many saved hosts share it.
///  * **An interval with a floor** — [ReachabilityInterval.minimum] — and
///    ±[jitter] on every period, so thirty hosts added in one import do not
///    all come due in the same second forever after.
///  * **At most [maxConcurrent] probes in flight**, and the first round
///    staggered by [stagger], so opening the list is a trickle rather than a
///    burst.
///  * **Nothing while nobody is looking.** [setActive] is driven by whether
///    the host list is on screen with the app in front; paused, no timer runs.
///    Coming back probes only what has gone stale, so flicking between tabs
///    costs nothing.
class ReachabilityScheduler {
  ReachabilityScheduler({
    required this.probe,
    required this.onChanged,
    ProbeTimerFactory? timer,
    DateTime Function()? now,
    Random? random,
    this.maxConcurrent = 4,
    this.stagger = const Duration(milliseconds: 250),
    this.jitter = 0.2,
  }) : _timer = timer ?? Timer.new,
       _now = now ?? DateTime.now,
       _random = random ?? Random();

  final ReachabilityProbe probe;

  /// Called after [results] changes. Never synchronously from a setter.
  final void Function() onChanged;

  final int maxConcurrent;
  final Duration stagger;

  /// The fraction each period may move either way: 0.2 is ±20%.
  final double jitter;

  final ProbeTimerFactory _timer;
  final DateTime Function() _now;
  final Random _random;

  final Map<String, ProbeAddress> _targets = {};
  final Map<String, ProbeResult> _results = {};
  final Map<String, DateTime> _due = {};
  final Set<String> _inFlight = {};
  final Queue<String> _queue = Queue();
  Duration? _interval;
  bool _active = false;
  bool _disposed = false;
  Timer? _wake;

  /// The latest result per address key.
  Map<String, ProbeResult> get results => UnmodifiableMapView(_results);

  /// How many probes are running right now.
  int get inFlight => _inFlight.length;

  bool get isRunning => _active && _interval != null && !_disposed;

  /// The addresses to keep checked. Anything dropped is forgotten.
  void setTargets(Iterable<ProbeAddress> targets) {
    if (_disposed) return;
    final next = {for (final t in targets) t.key: t};
    final removed = _targets.keys.where((k) => !next.containsKey(k)).toList();
    for (final key in removed) {
      _targets.remove(key);
      _due.remove(key);
      _queue.remove(key);
    }
    _targets.addAll(next);
    final pruned = removed.where((k) => _results.remove(k) != null).isNotEmpty;
    if (isRunning) _planOverdue();
    _reschedule();
    if (pruned) scheduleMicrotask(_notify);
  }

  /// The period between checks of one address, or null for none at all.
  /// Clamped to [ReachabilityInterval.minimum].
  void setInterval(Duration? interval) {
    if (_disposed) return;
    final clamped = interval == null
        ? null
        : (interval < ReachabilityInterval.minimum
              ? ReachabilityInterval.minimum
              : interval);
    if (clamped == _interval) return;
    _interval = clamped;
    // Every plan was made for the old period.
    _due.clear();
    if (clamped == null) _queue.clear();
    if (isRunning) _planOverdue();
    _reschedule();
  }

  /// Whether anyone is looking. Off cancels the timer and anything queued;
  /// a probe already in flight finishes and its result is kept.
  void setActive(bool active) {
    if (_disposed || active == _active) return;
    _active = active;
    if (!active) {
      _queue.clear();
    } else {
      _planOverdue();
    }
    _reschedule();
  }

  void dispose() {
    _disposed = true;
    _wake?.cancel();
    _wake = null;
    _queue.clear();
  }

  /// A period with jitter applied: uniformly within ±[jitter] of [period].
  Duration jittered(Duration period) {
    final factor = 1 - jitter + 2 * jitter * _random.nextDouble();
    return Duration(microseconds: (period.inMicroseconds * factor).round());
  }

  /// Gives every target without a plan one, and spreads everything already
  /// due across [stagger]-spaced slots from now.
  void _planOverdue() {
    final interval = _interval;
    if (interval == null) return;
    final now = _now();
    final overdue = <String>[];
    for (final key in _targets.keys) {
      if (_inFlight.contains(key) || _queue.contains(key)) continue;
      final result = _results[key];
      final due = _due[key] ??= result == null
          ? now
          : result.checkedAt.add(jittered(interval));
      if (!due.isAfter(now)) overdue.add(key);
    }
    for (final (i, key) in overdue.indexed) {
      _due[key] = now.add(stagger * i);
    }
  }

  void _reschedule() {
    _wake?.cancel();
    _wake = null;
    if (!isRunning) return;
    DateTime? earliest;
    for (final MapEntry(:key, :value) in _due.entries) {
      if (_inFlight.contains(key) || _queue.contains(key)) continue;
      if (earliest == null || value.isBefore(earliest)) earliest = value;
    }
    if (earliest == null) return;
    final delay = earliest.difference(_now());
    _wake = _timer(delay.isNegative ? Duration.zero : delay, _tick);
  }

  void _tick() {
    _wake = null;
    if (!isRunning) return;
    final now = _now();
    final due =
        _due.entries
            .where(
              (e) =>
                  !e.value.isAfter(now) &&
                  !_inFlight.contains(e.key) &&
                  !_queue.contains(e.key),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in due) {
      _due.remove(entry.key);
      _queue.add(entry.key);
    }
    _pump();
    _reschedule();
  }

  void _pump() {
    while (isRunning && _inFlight.length < maxConcurrent && _queue.isNotEmpty) {
      final key = _queue.removeFirst();
      final address = _targets[key];
      if (address == null) continue;
      _inFlight.add(key);
      unawaited(_run(key, address));
    }
  }

  Future<void> _run(String key, ProbeAddress address) async {
    ProbeOutcome outcome;
    try {
      outcome = await probe.probe(address);
    } on Object {
      outcome = const ProbeOutcome.down(ReachabilityFailure.unreachable);
    }
    _inFlight.remove(key);
    if (_disposed) return;
    if (_targets.containsKey(key)) {
      final now = _now();
      _results[key] = ProbeResult(outcome, now);
      final interval = _interval;
      if (interval != null) _due[key] = now.add(jittered(interval));
      _notify();
    }
    _pump();
    _reschedule();
  }

  void _notify() {
    if (!_disposed) onChanged();
  }
}
