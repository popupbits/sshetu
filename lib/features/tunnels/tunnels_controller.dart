import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ssh/host_key_verifier.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_connection_state.dart';
import '../../core/ssh/tunnel_runner.dart';
import '../../core/ssh/vault_credential_source.dart';
import '../hosts/domain/ssh_host.dart';
import '../sessions/reconnect_triggers.dart';
import '../sessions/session_manager.dart';
import 'domain/tunnel.dart';

/// Every saved forward, across every host.
final tunnelsProvider = FutureProvider<List<Tunnel>>(
  (ref) => ref.watch(tunnelRepositoryProvider).all(),
);

/// Writes, each of which invalidates [tunnelsProvider].
class TunnelsController {
  const TunnelsController(this._ref);

  final Ref _ref;

  Future<void> save(Tunnel tunnel) async {
    await _ref.read(tunnelRepositoryProvider).save(tunnel);
    _ref.invalidate(tunnelsProvider);
  }

  Future<void> delete(Tunnel tunnel) async {
    // Stopped first: a forward tombstoned out from under a running runner
    // would leak the socket it holds open, with nothing left in the list to
    // show it was ever there.
    await _ref.read(tunnelRunnersProvider.notifier).stop(tunnel);
    await _ref
        .read(tunnelRepositoryProvider)
        .delete(tunnel.id, now: DateTime.now().toUtc());
    _ref.invalidate(tunnelsProvider);
  }
}

final tunnelsControllerProvider = Provider<TunnelsController>(
  TunnelsController.new,
);

/// Live status for every forward that has been started this app run, keyed by
/// tunnel id.
///
/// A [Notifier] rather than one provider per tunnel: forwards come and go as
/// the user edits them, and a `.family` provider has no good place to hold
/// the manager-owned connections in [TunnelRunnerManager] — they belong to
/// whichever host the tunnels are for, not to any one tunnel.
class TunnelRunnerManager extends Notifier<Map<String, TunnelRunnerStatus>> {
  final Map<String, TunnelRunner> _runners = {};
  final Map<String, StreamSubscription<TunnelRunnerStatus>> _subscriptions = {};

  /// Connections this manager opened itself, because no terminal session was
  /// open for the host. Keyed by host id, not by tunnel id, so two forwards
  /// to the same host share one transport instead of paying for a second
  /// handshake — the same reasoning `SshConnection`'s doc comment gives for
  /// sharing a session's channels.
  final Map<String, SshConnection> _ownedConnections = {};

  /// How many of this manager's tunnels are currently running against each
  /// host, so the connection for that host can be closed the moment none are
  /// — and not a moment before, while a sibling tunnel still needs it.
  final Map<String, int> _hostRefCounts = {};

  @override
  Map<String, TunnelRunnerStatus> build() {
    ref.onDispose(_disposeAll);
    return const {};
  }

  /// What each tunnel was last started with, so one that stopped because its
  /// connection dropped can be started again exactly as the user started it.
  final Map<String, _StartRequest> _requests = {};

  /// The connection each tunnel last ran on.
  final Map<String, SshConnection> _runsOn = {};

  /// Tunnels stopped by a dropped connection rather than by the user, waiting
  /// for it to come back.
  final Set<String> _awaitingReconnect = {};

  /// One state subscription per connection a tunnel has used.
  final Map<SshConnection, StreamSubscription<SshConnectionState>>
  _connectionWatches = {};

  StreamSubscription<ReconnectTrigger>? _triggers;

  void _disposeAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    for (final watch in _connectionWatches.values) {
      watch.cancel();
    }
    _connectionWatches.clear();
    _triggers?.cancel();
    _triggers = null;
    for (final runner in _runners.values) {
      unawaited(runner.dispose());
    }
    for (final connection in _ownedConnections.values) {
      unawaited(connection.close());
    }
    _subscriptions.clear();
    _runners.clear();
    _ownedConnections.clear();
    _hostRefCounts.clear();
  }

  TunnelRunnerStatus statusFor(String tunnelId) =>
      state[tunnelId] ?? const TunnelRunnerStatus.stopped();

  /// Starts [tunnel], reusing an open session's connection to [host] or
  /// opening one through [SessionManager] — never bypassing host key
  /// verification, because a tunnel is exactly as sensitive a channel as a
  /// shell.
  Future<void> start(
    Tunnel tunnel, {
    required SshHost host,
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
    required KeyboardInteractivePrompter interactivePrompt,
  }) async {
    final runner = _runners.putIfAbsent(
      tunnel.id,
      () => TunnelRunner(
        tunnel: tunnel,
        connect: () async {
          final connection = await _connectionFor(
            host,
            onUnknownHostKey: onUnknownHostKey,
            prompt: prompt,
            interactivePrompt: interactivePrompt,
          );
          _watchConnection(tunnel.id, connection);
          return connection.client();
        },
      ),
    );
    _requests[tunnel.id] = _StartRequest(
      tunnel: tunnel,
      host: host,
      onUnknownHostKey: onUnknownHostKey,
      prompt: prompt,
      interactivePrompt: interactivePrompt,
    );
    _awaitingReconnect.remove(tunnel.id);
    _watchTriggers();

    _subscriptions.putIfAbsent(
      tunnel.id,
      () => runner.statuses.listen((status) {
        state = {...state, tunnel.id: status};
      }),
    );

    // Recorded before the call: TunnelRunner.start() is a no-op when already
    // running, so without this an already-running tunnel started again would
    // inflate the ref count with nothing to ever bring it back down.
    final wasRunning = runner.status.isRunning;

    // Published before the await so the UI shows "starting" immediately —
    // otherwise a slow handshake looks like the tap did nothing.
    state = {...state, tunnel.id: runner.status};
    await runner.start();
    state = {...state, tunnel.id: runner.status};

    if (!wasRunning && runner.status.isRunning) {
      _hostRefCounts[host.id] = (_hostRefCounts[host.id] ?? 0) + 1;
    }
  }

  Future<void> stop(Tunnel tunnel) async {
    // The user's decision: a tunnel they stopped stays stopped, even if the
    // connection it was waiting for comes back.
    _awaitingReconnect.remove(tunnel.id);
    _watchTriggers();
    await _stopRunner(tunnel);
  }

  /// Follows [connection]'s state for as long as a tunnel uses it, so a drop
  /// can take the tunnel down cleanly and a reconnect can bring it back.
  void _watchConnection(String tunnelId, SshConnection connection) {
    _runsOn[tunnelId] = connection;
    _connectionWatches.putIfAbsent(
      connection,
      () => connection.states.listen(
        (state) => _onConnectionState(connection, state),
        onDone: () => _onConnectionClosed(connection),
      ),
    );
  }

  void _onConnectionState(SshConnection connection, SshConnectionState state) {
    switch (state.status) {
      case SshConnectionStatus.disconnected:
        unawaited(_suspendRunningOn(connection));
      case SshConnectionStatus.connected:
        // A terminal tab's connection reconnecting by itself: every forward
        // that was riding it comes back on the same transport.
        for (final id in _tunnelsOn(connection)) {
          if (_awaitingReconnect.contains(id)) unawaited(_restart(id));
        }
      default:
        break;
    }
  }

  /// A dropped connection leaves a local forward bound to a port whose every
  /// new connection would fail, and a remote one gone with the session. Both
  /// are stopped properly, and marked as waiting rather than as stopped: the
  /// user did not stop them, and they will come back.
  Future<void> _suspendRunningOn(SshConnection connection) async {
    for (final id in _tunnelsOn(connection)) {
      final runner = _runners[id];
      final request = _requests[id];
      if (runner == null || request == null || !runner.status.isRunning) {
        continue;
      }
      await _stopRunner(request.tunnel);
      _awaitingReconnect.add(id);
      state = {
        ...state,
        id: const TunnelRunnerStatus(
          state: TunnelRunState.failed,
          error:
              'Connection lost. The forward restarts when the connection is '
              'back.',
        ),
      };
    }
    _watchTriggers();
  }

  void _onConnectionClosed(SshConnection connection) {
    unawaited(_connectionWatches.remove(connection)?.cancel());
    for (final id in _tunnelsOn(connection)) {
      _runsOn.remove(id);
      final request = _requests[id];
      final runner = _runners[id];
      if (request == null || runner == null || !runner.status.isRunning) {
        continue;
      }
      unawaited(
        _stopRunner(request.tunnel).then((_) {
          state = {
            ...state,
            id: const TunnelRunnerStatus(
              state: TunnelRunState.failed,
              error: 'The connection this forward used was closed.',
            ),
          };
        }),
      );
    }
  }

  List<String> _tunnelsOn(SshConnection connection) => [
    for (final entry in _runsOn.entries)
      if (identical(entry.value, connection)) entry.key,
  ];

  Future<void> _restart(String tunnelId) async {
    final request = _requests[tunnelId];
    if (request == null || !_awaitingReconnect.remove(tunnelId)) return;
    _watchTriggers();
    await start(
      request.tunnel,
      host: request.host,
      onUnknownHostKey: request.onUnknownHostKey,
      prompt: request.prompt,
      interactivePrompt: request.interactivePrompt,
    );
  }

  /// Listens for the app returning or the network coming back while any
  /// tunnel is waiting, for forwards that ran on a connection of their own:
  /// no terminal tab will reconnect that one, so the trigger is their cue.
  void _watchTriggers() {
    if (_awaitingReconnect.isEmpty) {
      unawaited(_triggers?.cancel());
      _triggers = null;
      return;
    }
    _triggers ??= ref.read(reconnectTriggersProvider).events.listen((_) {
      final sessions = ref.read(sessionManagerProvider.notifier);
      for (final id in List.of(_awaitingReconnect)) {
        final request = _requests[id];
        // A host with a tab open is brought back by that tab's own
        // reconnect, which the connection watch above picks up.
        if (request == null || sessions.hasTabFor(request.host.id)) continue;
        unawaited(_restart(id));
      }
    });
  }

  Future<void> _stopRunner(Tunnel tunnel) async {
    final runner = _runners[tunnel.id];
    if (runner == null) return;
    final wasRunning = runner.status.isRunning;
    await runner.stop();
    state = {...state, tunnel.id: runner.status};
    if (wasRunning) _release(tunnel.hostId);
  }

  Future<SshConnection> _connectionFor(
    SshHost host, {
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
    required KeyboardInteractivePrompter interactivePrompt,
  }) async {
    final sessions = ref.read(sessionManagerProvider.notifier);

    final reused = sessions.connectionForHost(host.id);
    if (reused != null) return reused;

    final owned = _ownedConnections[host.id];
    if (owned != null && owned.isConnected) return owned;

    final connection = await sessions.openBareConnection(
      host,
      onUnknownHostKey: onUnknownHostKey,
      prompt: prompt,
      interactivePrompt: interactivePrompt,
    );
    _ownedConnections[host.id] = connection;
    return connection;
  }

  void _release(String hostId) {
    final remaining = (_hostRefCounts[hostId] ?? 1) - 1;
    if (remaining > 0) {
      _hostRefCounts[hostId] = remaining;
      return;
    }
    _hostRefCounts.remove(hostId);
    final connection = _ownedConnections.remove(hostId);
    // Never closes a session's own connection — that map only ever holds
    // ones this manager opened itself, checked by identity via the map, not
    // by asking the connection what it is.
    unawaited(connection?.close());
  }
}

final tunnelRunnersProvider =
    NotifierProvider<TunnelRunnerManager, Map<String, TunnelRunnerStatus>>(
      TunnelRunnerManager.new,
    );

/// Everything [TunnelRunnerManager.start] was called with, kept so a forward
/// stopped by a dropped connection can be started again the same way.
class _StartRequest {
  const _StartRequest({
    required this.tunnel,
    required this.host,
    required this.onUnknownHostKey,
    required this.prompt,
    required this.interactivePrompt,
  });

  final Tunnel tunnel;
  final SshHost host;
  final HostKeyTrustDecision onUnknownHostKey;
  final SecretPrompt prompt;
  final KeyboardInteractivePrompter interactivePrompt;
}
