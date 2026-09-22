import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/tunnel_runner.dart';
import 'package:sshetu/features/tunnels/domain/far_end.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';

/// A [TunnelRunner] that "binds" without a socket or an SSH server: start
/// reports running on the tunnel's listen port, or fails with [failWith].
class FakeTunnelRunner implements TunnelRunner {
  FakeTunnelRunner(this.tunnel, {this.failWith});

  @override
  final Tunnel tunnel;

  final String? failWith;
  int starts = 0;
  int stops = 0;
  bool disposed = false;

  final _statuses = StreamController<TunnelRunnerStatus>.broadcast();
  TunnelRunnerStatus _status = const TunnelRunnerStatus.stopped();

  @override
  Future<SSHClient> Function() get connect =>
      () => throw UnimplementedError();

  @override
  Stream<TunnelRunnerStatus> get statuses => _statuses.stream;

  @override
  TunnelRunnerStatus get status => _status;

  void _emit(TunnelRunnerStatus next) {
    _status = next;
    if (!_statuses.isClosed) _statuses.add(next);
  }

  @override
  Future<void> start() async {
    starts++;
    _emit(const TunnelRunnerStatus(state: TunnelRunState.starting));
    await Future<void>.value();
    final failure = failWith;
    _emit(
      failure == null
          ? TunnelRunnerStatus(
              state: TunnelRunState.running,
              connections: 0,
              boundPort: tunnel.listenPort == 0 ? 49152 : tunnel.listenPort,
            )
          : TunnelRunnerStatus(state: TunnelRunState.failed, error: failure),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    _emit(const TunnelRunnerStatus.stopped());
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _status = const TunnelRunnerStatus.stopped();
    await _statuses.close();
  }

  @override
  Future<FarEndStatus?> probeTarget({
    Duration timeout = const Duration(seconds: 5),
  }) async => null;
}

/// An [SshConnection] that is never dialled — its state stream is all a
/// forward watches.
SshConnection idleConnection() => SshConnection(
  target: const SshTarget(hostname: 'web-1', username: 'deploy'),
  verifierFactory: (_, _) => throw UnimplementedError('never dialled'),
);
