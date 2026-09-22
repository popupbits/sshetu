import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_connection_state.dart';
import '../../core/ssh/tunnel_runner.dart';
import 'domain/free_port.dart';
import 'domain/listening_ports.dart';
import 'domain/tunnel.dart';

/// A forward made with one tap from "Ports on this server": not saved, tied
/// to one terminal tab's connection, and gone when that tab closes.
class AdHocForward {
  const AdHocForward({
    required this.tunnel,
    required this.sessionId,
    required this.remotePort,
    this.process,
    this.status = const TunnelRunnerStatus.stopped(),
  });

  /// The forward as an unsaved [Tunnel], so it runs through the same
  /// [TunnelRunner] a saved one does and saving it is a copy, not a
  /// translation.
  final Tunnel tunnel;

  /// The terminal tab whose connection carries it.
  final String sessionId;

  /// The server port it reaches.
  final int remotePort;

  /// The server process listening there, when known — the saved tunnel's
  /// label.
  final String? process;
  final TunnelRunnerStatus status;

  String get id => tunnel.id;
  String get hostId => tunnel.hostId;

  /// The port on this device: the one actually bound once running, the one
  /// asked for before.
  int get localPort => status.boundPort ?? tunnel.listenPort;

  /// What to paste into a client.
  String get address => 'localhost:$localPort';

  /// What "Open in browser" opens.
  String get url => 'http://localhost:$localPort';

  AdHocForward withStatus(TunnelRunnerStatus next) => AdHocForward(
    tunnel: tunnel,
    sessionId: sessionId,
    remotePort: remotePort,
    process: process,
    status: next,
  );
}

/// The prefix every ad-hoc forward's id carries, so one can never be
/// mistaken for a saved row's.
const String adHocIdPrefix = 'adhoc-';

/// A saved [Tunnel] with the same mapping as [forward], ready to write.
///
/// Listens on the port the forward actually holds, so a client already
/// pointed at it keeps working, and is labelled after the server process
/// when that is known — "node (3000)" says more in a list than "Port 3000".
Tunnel tunnelFromAdHoc(
  AdHocForward forward, {
  required String id,
  required DateTime now,
}) {
  final label = forward.process == null
      ? 'Port ${forward.remotePort}'
      : '${forward.process} (${forward.remotePort})';
  return Tunnel(
    id: id,
    hostId: forward.hostId,
    label: label,
    kind: TunnelKind.local,
    listenHost: Tunnel.defaultListenHost,
    listenPort: forward.localPort,
    targetHost: forward.tunnel.targetHost,
    targetPort: forward.tunnel.targetPort,
    createdAt: now,
    updatedAt: now,
  );
}

/// Makes the runner for one ad-hoc forward. A seam for tests, which have no
/// SSH server to dial.
typedef AdHocRunnerFactory = TunnelRunner Function(
  Tunnel tunnel,
  SshConnection connection,
);

final adHocRunnerFactoryProvider = Provider<AdHocRunnerFactory>(
  (ref) =>
      (tunnel, connection) => TunnelRunner(
        tunnel: tunnel,
        // Never dials: a tab's connection is brought back by the tab.
        connect: connection.client,
      ),
);

/// Picks the local port for a forward to [remotePort]. A seam for tests.
final adHocPortPickerProvider = Provider<Future<int?> Function(int)>(
  (ref) => pickLocalPort,
);

/// Every ad-hoc forward open this run.
///
/// Each rides its tab's connection and follows it: stopped when it drops,
/// started again on the same port when the tab reconnects, and removed
/// when the connection is closed for good — a forward outliving the tab
/// that made it would be a port open on this device with nothing on screen
/// to say so.
class AdHocForwardsNotifier extends Notifier<List<AdHocForward>> {
  final Map<String, TunnelRunner> _runners = {};
  final Map<String, StreamSubscription<TunnelRunnerStatus>> _statusSubs = {};
  final Map<String, SshConnection> _connections = {};
  final Map<SshConnection, StreamSubscription<SshConnectionState>> _watches =
      {};

  /// Forwards stopped by a dropped connection, waiting for it to return.
  final Set<String> _suspended = {};

  static final Random _random = Random.secure();

  @override
  List<AdHocForward> build() {
    ref.onDispose(_disposeAll);
    return const [];
  }

  /// The forward to [remotePort] over [sessionId]'s connection, if any.
  AdHocForward? forPort(String sessionId, int remotePort) {
    for (final forward in state) {
      if (forward.sessionId == sessionId && forward.remotePort == remotePort) {
        return forward;
      }
    }
    return null;
  }

  /// Forwards `localhost:<remote port or the next free one>` to [port] on
  /// the server, over [connection]. Only ever called from a tap.
  ///
  /// Returns the existing forward when there already is one for this tab
  /// and port.
  Future<AdHocForward> forward({
    required String sessionId,
    required String hostId,
    required SshConnection connection,
    required ListeningPort port,
  }) async {
    final existing = forPort(sessionId, port.port);
    if (existing != null && existing.status.state != TunnelRunState.failed) {
      return existing;
    }
    if (existing != null) await stop(existing.id);

    final local = await ref.read(adHocPortPickerProvider)(port.port);
    final now = DateTime.now().toUtc();
    final tunnel = Tunnel(
      id: '$adHocIdPrefix${_newToken()}',
      hostId: hostId,
      label: 'Port ${port.port}',
      kind: TunnelKind.local,
      // Loopback, always: a one-tap forward must never put a server's
      // private port on the local network.
      listenHost: Tunnel.defaultListenHost,
      // 0 asks the operating system for any free port.
      listenPort: local ?? 0,
      targetHost: port.targetHost,
      targetPort: port.port,
      createdAt: now,
      updatedAt: now,
    );
    final runner = ref.read(adHocRunnerFactoryProvider)(tunnel, connection);
    final forward = AdHocForward(
      tunnel: tunnel,
      sessionId: sessionId,
      remotePort: port.port,
      process: port.process,
      status: const TunnelRunnerStatus(state: TunnelRunState.starting),
    );
    _runners[tunnel.id] = runner;
    _connections[tunnel.id] = connection;
    state = [...state, forward];
    _statusSubs[tunnel.id] = runner.statuses.listen(
      (status) => _setStatus(tunnel.id, status),
    );
    _watch(connection);
    await runner.start();
    _setStatus(tunnel.id, runner.status);
    return _byId(tunnel.id) ?? forward.withStatus(runner.status);
  }

  /// Stops and forgets one forward, freeing its local port.
  Future<void> stop(String id) async {
    _suspended.remove(id);
    final runner = _runners.remove(id);
    _connections.remove(id);
    // Off the list at once, before anything is awaited: the row flips back
    // to Forward the moment Stop is tapped.
    unawaited(_statusSubs.remove(id)?.cancel());
    if (ref.mounted) {
      state = [
        for (final forward in state)
          if (forward.id != id) forward,
      ];
    }
    if (runner != null) await runner.dispose();
  }

  /// Stops every forward riding [sessionId]'s connection.
  Future<void> stopAllFor(String sessionId) async {
    for (final forward in List.of(state)) {
      if (forward.sessionId == sessionId) await stop(forward.id);
    }
  }

  AdHocForward? _byId(String id) {
    for (final forward in state) {
      if (forward.id == id) return forward;
    }
    return null;
  }

  void _setStatus(String id, TunnelRunnerStatus status) {
    if (_byId(id) == null) return;
    state = [
      for (final forward in state)
        forward.id == id ? forward.withStatus(status) : forward,
    ];
  }

  void _watch(SshConnection connection) {
    _watches.putIfAbsent(
      connection,
      () => connection.states.listen(
        (next) => _onConnectionState(connection, next),
        onDone: () => _onConnectionClosed(connection),
      ),
    );
  }

  List<String> _on(SshConnection connection) => [
    for (final entry in _connections.entries)
      if (identical(entry.value, connection)) entry.key,
  ];

  void _onConnectionState(SshConnection connection, SshConnectionState next) {
    switch (next.status) {
      case SshConnectionStatus.disconnected:
        for (final id in _on(connection)) {
          final runner = _runners[id];
          if (runner == null || !runner.status.isRunning) continue;
          _suspended.add(id);
          unawaited(
            runner.stop().then((_) {
              if (!_suspended.contains(id)) return;
              _setStatus(
                id,
                const TunnelRunnerStatus(
                  state: TunnelRunState.failed,
                  error:
                      'Connection lost. The forward restarts when the tab '
                      'reconnects.',
                ),
              );
            }),
          );
        }
      case SshConnectionStatus.connected:
        for (final id in _on(connection)) {
          if (_suspended.remove(id)) unawaited(_runners[id]?.start());
        }
      default:
        break;
    }
  }

  void _onConnectionClosed(SshConnection connection) {
    unawaited(_watches.remove(connection)?.cancel());
    for (final id in _on(connection)) {
      unawaited(stop(id));
    }
  }

  void _disposeAll() {
    for (final sub in _statusSubs.values) {
      unawaited(sub.cancel());
    }
    for (final watch in _watches.values) {
      unawaited(watch.cancel());
    }
    for (final runner in _runners.values) {
      unawaited(runner.dispose());
    }
    _statusSubs.clear();
    _watches.clear();
    _runners.clear();
    _connections.clear();
    _suspended.clear();
  }

  static String _newToken() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      16,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}

final adHocForwardsProvider =
    NotifierProvider<AdHocForwardsNotifier, List<AdHocForward>>(
      AdHocForwardsNotifier.new,
    );
