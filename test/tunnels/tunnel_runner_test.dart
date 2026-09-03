import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/ssh/tunnel_runner.dart';
import 'package:ssh_navigator/features/tunnels/domain/tunnel.dart';

/// Binds a loopback server and returns one accepted connection paired with
/// the client end that dialed it — two independent, real TCP sockets, no SSH
/// involved.
///
/// Ownership passes to the caller, which destroys both — the `close_sinks`
/// lint cannot see across that handoff, so it is silenced at each
/// declaration rather than where the tests already account for their own
/// sockets.
Future<(Socket client, Socket accepted)> _loopbackPair() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final acceptedFuture = server.first;
  // ignore: close_sinks
  final client = await Socket.connect(
    InternetAddress.loopbackIPv4,
    server.port,
  );
  // ignore: close_sinks
  final accepted = await acceptedFuture;
  await server.close();
  return (client, accepted);
}

Tunnel _tunnel({
  TunnelKind kind = TunnelKind.local,
  String? targetHost = 'target',
  int? targetPort = 1,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Tunnel(
    id: 't1',
    hostId: 'h1',
    label: 'test',
    kind: kind,
    listenPort: 0,
    targetHost: targetHost,
    targetPort: targetPort,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('pipeSockets', () {
    // This is the primitive every forward kind relies on to actually move
    // bytes; TunnelRunner itself cannot be driven end-to-end without a real
    // SSHClient (which needs a real SSH server — see live_connection_test.dart
    // for that), so this is where the real work is proven with real sockets.
    test(
      'relays bytes in both directions between two unrelated connections',
      () async {
        final (clientA, acceptedA) = await _loopbackPair();
        final (clientB, acceptedB) = await _loopbackPair();
        addTearDown(() {
          clientA.destroy();
          clientB.destroy();
        });

        final pipe = pipeSockets(
          SocketAsSshSocket(acceptedA),
          SocketAsSshSocket(acceptedB),
        );

        clientA.add(utf8.encode('hello from A'));
        await clientA.flush();
        final fromA = await clientB
            .cast<List<int>>()
            .transform(utf8.decoder)
            .first;
        expect(fromA, 'hello from A');

        clientB.add(utf8.encode('hello from B'));
        await clientB.flush();
        final fromB = await clientA
            .cast<List<int>>()
            .transform(utf8.decoder)
            .first;
        expect(fromB, 'hello from B');

        await clientA.close();
        // Must actually finish: a version of this that only waits on `.done`
        // (a Socket's *write* side) rather than the stream ending would hang
        // here forever, because a half-closed client never calls close() on
        // the far end either.
        await pipe.timeout(const Duration(seconds: 2));
      },
    );

    test(
      'destroying one end unblocks the pipe and destroys the other',
      () async {
        final (clientA, acceptedA) = await _loopbackPair();
        final (clientB, acceptedB) = await _loopbackPair();
        addTearDown(clientA.destroy);

        final pipe = pipeSockets(
          SocketAsSshSocket(acceptedA),
          SocketAsSshSocket(acceptedB),
        );

        // Simulates a manual `stop()` reaching into an active connection —
        // nothing sent EOF, the socket was simply torn down from outside.
        acceptedA.destroy();

        await pipe.timeout(const Duration(seconds: 2));
        // acceptedB (the far end of the *other* pair) should have been torn
        // down too, which its peer clientB sees as its stream ending — not as
        // `clientB.done`, which reflects clientB's own write side and would
        // never complete just because the remote end closed on it.
        await clientB.drain<void>().timeout(const Duration(seconds: 2));
      },
    );
  });

  group('TunnelRunner state machine', () {
    // These drive the runner through its real transitions using a fake
    // `connect` — the one seam the runner has — instead of a real SSHClient.
    // That covers the logic this code is actually responsible for (not
    // reopening a connection on a double tap, surfacing a dial failure as a
    // safe message, being restartable) without needing dartssh2's own
    // forwarding, which is exercised by its own test suite, not this one.

    test(
      'a connect failure surfaces its message and does not hang in starting',
      () async {
        final runner = TunnelRunner(
          tunnel: _tunnel(),
          connect: () async => throw TunnelException('host unreachable'),
        );

        await runner.start();

        expect(runner.status.state, TunnelRunState.failed);
        expect(runner.status.error, 'host unreachable');
      },
    );

    test(
      'a generic SocketException is described, never shown as a raw stack',
      () async {
        final runner = TunnelRunner(
          tunnel: _tunnel(),
          connect: () async =>
              throw const SocketException('connection refused'),
        );

        await runner.start();

        expect(runner.status.error, 'connection refused');
      },
    );

    test(
      'an empty SocketException message still produces readable text',
      () async {
        final runner = TunnelRunner(
          tunnel: _tunnel(),
          connect: () async => throw const SocketException(''),
        );

        await runner.start();

        expect(runner.status.error, 'Socket error');
      },
    );

    test('start() can be retried after a failure', () async {
      var calls = 0;
      final runner = TunnelRunner(
        tunnel: _tunnel(),
        connect: () async {
          calls++;
          throw TunnelException('down');
        },
      );

      await runner.start();
      await runner.start();

      // Guards the bug where a failed runner gets stuck refusing to try
      // again because its state never left something that looked "busy".
      expect(calls, 2);
    });

    test(
      'calling start() again while already starting does not dial twice',
      () async {
        var calls = 0;
        final gate = Completer<SSHClient>();
        final runner = TunnelRunner(
          tunnel: _tunnel(),
          connect: () {
            calls++;
            return gate.future;
          },
        );

        final first = runner.start();
        // Same tunnel started again mid-handshake — a double-tap on the
        // toggle button before the first attempt has resolved.
        final second = runner.start();
        expect(runner.status.state, TunnelRunState.starting);

        gate.completeError(TunnelException('unreachable'));
        await Future.wait([first, second]);

        expect(
          calls,
          1,
          reason: 'a double tap must not open a second connection attempt',
        );
      },
    );

    test('stop() before start() is a harmless no-op', () async {
      final runner = TunnelRunner(
        tunnel: _tunnel(),
        connect: () async => throw TunnelException('unused'),
      );
      await runner.stop();
      expect(runner.status.state, TunnelRunState.stopped);
    });

    test('dispose() closes the status stream', () async {
      final runner = TunnelRunner(
        tunnel: _tunnel(),
        connect: () async => throw TunnelException('down'),
      );
      final events = <TunnelRunnerStatus>[];
      final sub = runner.statuses.listen(events.add);

      await runner.start();
      await runner.dispose();
      await sub.cancel();

      expect(events, isNotEmpty);
      // A stop reaching a disposed runner (a stray callback firing late)
      // must not throw — `_emit`'s closed-controller guard is what this
      // checks.
      await runner.stop();
    });
  });
}
