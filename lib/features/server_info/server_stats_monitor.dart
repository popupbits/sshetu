import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/server_exec.dart';
import 'data/server_info_service.dart';
import 'domain/server_sample.dart';
import 'domain/stats_math.dart';

/// Where the monitor stands, for the panel.
enum MonitorStatus {
  /// No sample yet.
  loading,

  /// Showing the latest sample.
  ready,

  /// The connection is down; the monitor is waiting for the tab to bring it
  /// back and will not dial on its own.
  offline,

  /// The last poll failed with the connection up.
  error,
}

/// Polls one host's stats while something is watching.
///
/// Owned by the panel's state, started when it becomes visible and stopped
/// when it is hidden or the app goes to the background — a panel nobody can
/// see has no business running a command on someone's server every three
/// seconds. One poll at a time: a slow server stretches the interval rather
/// than stacking execs up behind each other.
class ServerStatsMonitor extends ChangeNotifier {
  ServerStatsMonitor(
    this.exec, {
    this.interval = const Duration(seconds: 3),
    this.historyLength = 60,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _service = ServerInfoService(exec);

  final ServerExec exec;
  final Duration interval;

  /// How many CPU samples the sparkline keeps — three minutes at 3 s.
  final int historyLength;
  final DateTime Function() _clock;
  final ServerInfoService _service;

  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;

  MonitorStatus _status = MonitorStatus.loading;
  MonitorStatus get status => _status;

  ServerStats? _stats;

  /// The latest figures. Kept through an error or a drop, so the panel can
  /// keep showing what it last knew under a banner saying it is stale.
  ServerStats? get stats => _stats;

  Object? _error;
  Object? get error => _error;

  final List<double> _cpuHistory = [];

  /// CPU %, oldest first, at most [historyLength] long.
  List<double> get cpuHistory => List.unmodifiable(_cpuHistory);

  ServerSample? _previous;
  DateTime? _previousAt;

  bool get isRunning => _timer != null;

  /// Starts polling now and every [interval]. Idempotent.
  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
    unawaited(poll());
  }

  /// Stops polling; the figures stay where they were.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One poll. Public so tests can drive it without a timer.
  Future<void> poll() async {
    if (_polling || _disposed) return;
    if (!exec.isConnected) {
      _set(MonitorStatus.offline);
      return;
    }
    _polling = true;
    try {
      final sample = await _service.sample();
      if (_disposed) return;
      final at = _clock();
      final stats = deriveStats(
        current: sample,
        currentAt: at,
        previous: _previous,
        previousAt: _previousAt,
      );
      _previous = sample;
      _previousAt = at;
      _stats = stats;
      _error = null;
      final cpu = stats.cpuPercent;
      if (cpu != null) {
        _cpuHistory.add(cpu);
        if (_cpuHistory.length > historyLength) {
          _cpuHistory.removeRange(0, _cpuHistory.length - historyLength);
        }
      }
      _set(MonitorStatus.ready);
    } on ServerOfflineException {
      _set(MonitorStatus.offline);
    } on Object catch (e) {
      if (_disposed) return;
      _error = e;
      _set(exec.isConnected ? MonitorStatus.error : MonitorStatus.offline);
    } finally {
      _polling = false;
    }
  }

  void _set(MonitorStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
