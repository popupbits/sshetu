import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ssh/host_key_verifier.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/tunnel_runner.dart';
import '../../core/ssh/vault_credential_source.dart';
import '../hosts/domain/ssh_host.dart';
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

  void _disposeAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
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
  }) async {
    final runner = _runners.putIfAbsent(
      tunnel.id,
      () => TunnelRunner(
        tunnel: tunnel,
        connect: () async => (await _connectionFor(
          host,
          onUnknownHostKey: onUnknownHostKey,
          prompt: prompt,
        )).client(),
      ),
    );

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
