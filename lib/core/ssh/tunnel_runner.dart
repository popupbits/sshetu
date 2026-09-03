import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../features/tunnels/domain/tunnel.dart';

/// Where one forward is in its lifecycle.
enum TunnelRunState { stopped, starting, running, failed }

/// A forward's live status, safe to show as-is.
class TunnelRunnerStatus {
  const TunnelRunnerStatus({
    required this.state,
    this.error,
    this.connections,
    this.boundPort,
  });

  const TunnelRunnerStatus.stopped() : this(state: TunnelRunState.stopped);

  final TunnelRunState state;

  /// User-facing explanation. Never a credential or key material.
  final String? error;

  /// Sockets currently piping bytes for this tunnel.
  ///
  /// Null rather than 0 when it is not tracked: a SOCKS forward hands every
  /// connection to dartssh2's own proxy engine, which exposes no count, and
  /// printing a confident "0" next to a running dynamic tunnel would be a
  /// claim this code cannot back up.
  final int? connections;

  /// The port actually bound, once running.
  final int? boundPort;

  bool get isRunning => state == TunnelRunState.running;

  TunnelRunnerStatus _withConnections(int count) => TunnelRunnerStatus(
    state: state,
    error: error,
    connections: count,
    boundPort: boundPort,
  );

  @override
  bool operator ==(Object other) =>
      other is TunnelRunnerStatus &&
      other.state == state &&
      other.error == error &&
      other.connections == connections &&
      other.boundPort == boundPort;

  @override
  int get hashCode => Object.hash(state, error, connections, boundPort);

  @override
  String toString() =>
      'TunnelRunnerStatus($state${error == null ? '' : ', $error'})';
}

/// A forward-specific failure that is safe to show verbatim — "the server
/// refused to listen on that port", not an SSH internal.
class TunnelException implements Exception {
  TunnelException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Pipes bytes between two open ends until either side closes, then tears
/// down the other.
///
/// The one piece of plumbing every forward kind needs, written once: a local
/// forward pipes an accepted socket against a `forwardLocal` channel, a
/// remote forward pipes an incoming channel against a dialed local socket.
/// Both ends are [SSHSocket] — dartssh2's own channels implement it, and
/// [SocketAsSshSocket] below gives a plain [Socket] the same shape — so this
/// is one implementation instead of two that would drift apart.
Future<void> pipeSockets(SSHSocket a, SSHSocket b) async {
  final done = Completer<void>();
  void finish() {
    if (!done.isCompleted) done.complete();
  }

  final aToB = a.stream.listen(
    (data) => b.sink.add(data),
    // A plain Socket's `done` reflects its *write* side finishing, not the
    // peer sending EOF — that arrives as the stream ending. Relying on
    // `.done` alone (the first version of this function did) meant a client
    // that sent its request and half-closed, the normal shape of a short
    // HTTP-over-a-tunnel request, would never unblock the pipe: nobody ever
    // called `close()`, so `.done` simply never completed. `onDone` here is
    // what makes a half-close actually end the pipe.
    onDone: finish,
    onError: (Object _) => finish(),
    cancelOnError: true,
  );
  final bToA = b.stream.listen(
    (data) => a.sink.add(data),
    onDone: finish,
    onError: (Object _) => finish(),
    cancelOnError: true,
  );
  // Covers the other direction: something outside this pipe (`stop()`
  // destroying every active connection) closing a socket without it ever
  // producing a stream event.
  unawaited(a.done.then((_) => finish(), onError: (_) => finish()));
  unawaited(b.done.then((_) => finish(), onError: (_) => finish()));

  await done.future;

  await aToB.cancel();
  await bToA.cancel();
  a.destroy();
  b.destroy();
}

/// Adapts a plain [Socket] to [SSHSocket], so the accepted end of a local
/// forward's [ServerSocket] can be piped with exactly the code an SSH channel
/// uses. Mirrors the private adapter dartssh2 keeps for `SSHSocket.connect` —
/// there is no public constructor for that one, so a local forward's server
/// side needs its own.
class SocketAsSshSocket implements SSHSocket {
  SocketAsSshSocket(this._socket);

  final Socket _socket;

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  Future<void> flush() => _socket.flush();
}

/// Runs one [Tunnel]: binds or asks the server to listen, and pipes bytes for
/// as long as it is running.
///
/// Deliberately knows nothing about Riverpod, a screen, or how its
/// [SSHClient] was obtained — [connect] is the only seam. That is what lets a
/// test drive this with a fake dial and no real SSH server, and lets the
/// controller layer decide freely whose connection to reuse.
class TunnelRunner {
  TunnelRunner({required this.tunnel, required this.connect});

  final Tunnel tunnel;
  final Future<SSHClient> Function() connect;

  final _statusController = StreamController<TunnelRunnerStatus>.broadcast();

  /// Transitions from here on. A broadcast stream, not a replay: a listener
  /// that subscribes after [start] has already run must read [status] for
  /// where things stand right now, the same way any other broadcast stream
  /// works.
  Stream<TunnelRunnerStatus> get statuses => _statusController.stream;

  TunnelRunnerStatus _status = const TunnelRunnerStatus.stopped();
  TunnelRunnerStatus get status => _status;

  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSub;

  SSHRemoteForward? _remoteForward;
  StreamSubscription<SSHForwardChannel>? _remoteSub;

  SSHDynamicForward? _dynamicForward;

  final _connections = <_ActiveConnection>{};

  /// Starts the forward. Safe to call again after [stop] or a failure.
  Future<void> start() async {
    if (_status.state == TunnelRunState.running ||
        _status.state == TunnelRunState.starting) {
      return;
    }
    _emit(const TunnelRunnerStatus(state: TunnelRunState.starting));
    try {
      final client = await connect();
      switch (tunnel.kind) {
        case TunnelKind.local:
          await _startLocal(client);
        case TunnelKind.remote:
          await _startRemote(client);
        case TunnelKind.socks:
          await _startDynamic(client);
      }
    } on Object catch (e) {
      await _teardown();
      _emit(
        TunnelRunnerStatus(state: TunnelRunState.failed, error: _describe(e)),
      );
    }
  }

  Future<void> stop() async {
    await _teardown();
    _emit(const TunnelRunnerStatus.stopped());
  }

  /// Releases everything and closes [statuses]. The runner is unusable after
  /// this — a fresh one is cheap, and reusing a closed stream controller is
  /// not worth the complexity of un-closing it.
  Future<void> dispose() async {
    await _teardown();
    await _statusController.close();
  }

  Future<void> _startLocal(SSHClient client) async {
    final target = _requireTarget();
    final server = await ServerSocket.bind(
      tunnel.listenHost,
      tunnel.listenPort,
    );
    _server = server;
    _serverSub = server.listen(
      (socket) => _accept(
        SocketAsSshSocket(socket),
        () => client.forwardLocal(target.host, target.port),
      ),
      onError: (Object e) => _fail(e),
    );
    _emit(
      TunnelRunnerStatus(
        state: TunnelRunState.running,
        boundPort: server.port,
        connections: 0,
      ),
    );
  }

  Future<void> _startRemote(SSHClient client) async {
    final target = _requireTarget();
    final forward = await client.forwardRemote(
      host: tunnel.listenHost,
      port: tunnel.listenPort,
    );
    if (forward == null) {
      throw TunnelException(
        'The server refused to listen on ${tunnel.listenHost}:'
        '${tunnel.listenPort}.',
      );
    }
    _remoteForward = forward;
    _remoteSub = forward.connections.listen(
      (channel) =>
          _accept(channel, () => SSHSocket.connect(target.host, target.port)),
      onError: (Object e) => _fail(e),
    );
    _emit(
      TunnelRunnerStatus(
        state: TunnelRunState.running,
        boundPort: forward.port,
        connections: 0,
      ),
    );
  }

  Future<void> _startDynamic(SSHClient client) async {
    final forward = await client.forwardDynamic(
      bindHost: tunnel.listenHost,
      bindPort: tunnel.listenPort,
    );
    _dynamicForward = forward;
    _emit(
      TunnelRunnerStatus(
        state: TunnelRunState.running,
        boundPort: forward.port,
      ),
    );
  }

  ({String host, int port}) _requireTarget() {
    final host = tunnel.targetHost;
    final port = tunnel.targetPort;
    if (host == null || port == null) {
      throw TunnelException('"${tunnel.label}" has no target set.');
    }
    return (host: host, port: port);
  }

  /// Dials [dial] for one inbound end and pipes it against [near], tracking
  /// it as an active connection for as long as bytes could still flow.
  void _accept(SSHSocket near, Future<SSHSocket> Function() dial) {
    final active = _ActiveConnection(near);
    _connections.add(active);
    _emitConnections();

    unawaited(() async {
      try {
        final far = await dial();
        // stop() may have run while the dial was in flight; a connection
        // no longer tracked has already had its near end destroyed, and
        // piping into a stale one would just leak the far socket.
        if (!_connections.contains(active)) {
          far.destroy();
          return;
        }
        active.far = far;
        await pipeSockets(near, far);
      } on Object {
        near.destroy();
      } finally {
        _connections.remove(active);
        _emitConnections();
      }
    }());
  }

  void _emitConnections() {
    if (!_status.isRunning) return;
    _emit(_status._withConnections(_connections.length));
  }

  void _fail(Object error) {
    _emit(
      TunnelRunnerStatus(state: TunnelRunState.failed, error: _describe(error)),
    );
    unawaited(_teardown());
  }

  Future<void> _teardown() async {
    await _serverSub?.cancel();
    _serverSub = null;
    await _server?.close();
    _server = null;

    await _remoteSub?.cancel();
    _remoteSub = null;
    _remoteForward?.close();
    _remoteForward = null;

    await _dynamicForward?.close();
    _dynamicForward = null;

    // Destroyed rather than politely closed: a manual stop must not wait for
    // a slow or wedged far end to notice, and pipeSockets' own `finally`
    // tolerates a socket that is already gone.
    for (final connection in _connections) {
      connection.destroy();
    }
    _connections.clear();
  }

  void _emit(TunnelRunnerStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  static String _describe(Object error) => switch (error) {
    TunnelException e => e.message,
    SocketException e => e.message.isEmpty ? 'Socket error' : e.message,
    _ => error.toString(),
  };
}

class _ActiveConnection {
  _ActiveConnection(this.near);

  final SSHSocket near;
  SSHSocket? far;

  void destroy() {
    near.destroy();
    far?.destroy();
  }
}
