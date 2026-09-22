import 'dart:async';

import 'package:flutter/foundation.dart';

import '../server_info/data/server_exec.dart';
import '../server_info/server_stats_monitor.dart' show MonitorStatus;
import 'domain/listening_ports.dart';

/// Lists the ports [exec]'s server listens on — one exec of [portsScript].
Future<List<ListeningPort>> listListeningPorts(ServerExec exec) async {
  final result = await exec.run('sh -s', stdin: portsScript);
  return parsePortsOutput(result.stdout);
}

/// Polls a server's listening ports while "Ports on this server" is on
/// screen.
///
/// Every five seconds, and **only while visible** — never in the
/// background. The list answers "what did I just start?", so it needs to be
/// fresh while someone is looking at it and needs nothing at all while they
/// are not: a slower background poll would be an exec on someone's server
/// every thirty seconds for a list no one reads, and the first poll on
/// opening costs well under a second anyway. One poll at a time, like
/// [ServerStatsMonitor]; it never dials — [exec] rides the tab's connection.
class PortsMonitor extends ChangeNotifier {
  PortsMonitor(
    this.exec, {
    this.interval = const Duration(seconds: 5),
    this.alsoIgnore = const {},
  });

  final ServerExec exec;
  final Duration interval;

  /// Ports hidden besides [ignoredSystemPorts] — the connection's own sshd.
  final Set<int> alsoIgnore;

  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;

  MonitorStatus _status = MonitorStatus.loading;
  MonitorStatus get status => _status;

  List<ListeningPort> _ports = const [];

  /// The latest list, filtered and sorted; kept through a drop or an error.
  List<ListeningPort> get ports => _ports;

  Object? _error;
  Object? get error => _error;

  bool get isRunning => _timer != null;

  /// Starts polling now and every [interval]. Idempotent.
  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
    unawaited(poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One poll. Public so tests and a retry button can drive it.
  Future<void> poll() async {
    if (_polling || _disposed) return;
    if (!exec.isConnected) {
      _set(MonitorStatus.offline);
      return;
    }
    _polling = true;
    try {
      final ports = await listListeningPorts(exec);
      if (_disposed) return;
      _ports = visiblePorts(ports, alsoIgnore: alsoIgnore);
      _error = null;
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
