import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/data/reachability_probe.dart';
import 'package:sshetu/features/hosts/domain/reachability.dart';

/// The TCP probe against real sockets on this machine — no network beyond
/// the loopback interface, so not tagged live.
void main() {
  test('an open port is up, with its connect time', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final accepted = <Socket>[];
    final received = <int>[];
    server.listen((socket) {
      accepted.add(socket);
      socket.listen(received.addAll, onDone: socket.destroy);
    });

    const probe = TcpReachabilityProbe();
    final outcome = await probe.probe(ProbeAddress('127.0.0.1', server.port));

    expect(outcome.isUp, isTrue);
    expect(outcome.latency, isNotNull);
    expect(outcome.latency!, lessThan(const Duration(seconds: 3)));

    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(accepted, hasLength(1), reason: 'exactly one connection');
    // Nothing sent: no SSH version string, no bytes at all.
    expect(received, isEmpty);
  });

  test('a closed port is down, refused', () async {
    // Bind to learn a free port, then close it so nothing listens there.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();

    const probe = TcpReachabilityProbe();
    final outcome = await probe.probe(ProbeAddress('127.0.0.1', port));

    expect(outcome.isUp, isFalse);
    // Windows can report a refused loopback connect as a timeout after its
    // own retries; either way it is down, and not for an unknown reason.
    expect(
      outcome.failure,
      anyOf(ReachabilityFailure.refused, ReachabilityFailure.timedOut),
    );
  });

  test('a connect that never settles times out as down', () async {
    final never = Completer<Socket>();
    final probe = TcpReachabilityProbe(
      timeout: const Duration(milliseconds: 20),
      connect: (host, port, {timeout}) => never.future,
    );
    final outcome = await probe.probe(const ProbeAddress('10.255.255.1', 22));
    expect(outcome, const ProbeOutcome.down(ReachabilityFailure.timedOut));
  });

  test('connect errors are classified', () async {
    Future<ProbeOutcome> failWith(SocketException error) =>
        TcpReachabilityProbe(
          connect: (host, port, {timeout}) => Future.error(error),
        ).probe(const ProbeAddress('example.invalid', 22));

    expect(
      (await failWith(
        const SocketException('Connection timed out, host: x, port: 22'),
      )).failure,
      ReachabilityFailure.timedOut,
    );
    expect(
      (await failWith(
        const SocketException('Failed host lookup: example.invalid'),
      )).failure,
      ReachabilityFailure.unresolved,
    );
    for (final code in [111, 61, 10061]) {
      expect(
        (await failWith(
          SocketException('x', osError: OSError('refused', code)),
        )).failure,
        ReachabilityFailure.refused,
      );
    }
    expect(
      (await failWith(
        const SocketException('x', osError: OSError('No route to host', 113)),
      )).failure,
      ReachabilityFailure.unreachable,
    );
  });
}
