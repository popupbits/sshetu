import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/tunnel_runner.dart';
import 'package:sshetu/features/tunnels/ad_hoc_forwards.dart';
import 'package:sshetu/features/tunnels/domain/listening_ports.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';

import 'fake_tunnel_runner.dart';

void main() {
  const node = ListeningPort(
    port: 3000,
    addresses: ['127.0.0.1'],
    process: 'node',
    pid: 4242,
  );

  late List<FakeTunnelRunner> runners;
  late List<int> picked;

  ProviderContainer container({int? Function(int)? pick, String? failWith}) {
    runners = [];
    picked = [];
    final c = ProviderContainer(
      overrides: [
        adHocRunnerFactoryProvider.overrideWithValue((tunnel, _) {
          final runner = FakeTunnelRunner(tunnel, failWith: failWith);
          runners.add(runner);
          return runner;
        }),
        adHocPortPickerProvider.overrideWithValue((port) async {
          picked.add(port);
          return pick == null ? port : pick(port);
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'forwards localhost:<same port> to the server port, on loopback',
    () async {
      final c = container();
      final forward = await c
          .read(adHocForwardsProvider.notifier)
          .forward(
            sessionId: 's1',
            hostId: 'h1',
            connection: idleConnection(),
            port: node,
          );

      expect(picked, [3000]);
      expect(forward.status.isRunning, isTrue);
      expect(forward.localPort, 3000);
      expect(forward.address, 'localhost:3000');
      expect(forward.url, 'http://localhost:3000');
      expect(forward.id, startsWith(adHocIdPrefix));
      expect(forward.tunnel.kind, TunnelKind.local);
      expect(forward.tunnel.listenHost, '127.0.0.1');
      expect(forward.tunnel.targetHost, '127.0.0.1');
      expect(forward.tunnel.targetPort, 3000);
      expect(c.read(adHocForwardsProvider), hasLength(1));
      expect(
        c.read(adHocForwardsProvider.notifier).forPort('s1', 3000)?.id,
        forward.id,
      );
    },
  );

  test('the next free port when the same one is taken', () async {
    final c = container(pick: (port) => port + 2);
    final forward = await c
        .read(adHocForwardsProvider.notifier)
        .forward(
          sessionId: 's1',
          hostId: 'h1',
          connection: idleConnection(),
          port: node,
        );
    expect(forward.localPort, 3002);
    expect(forward.tunnel.targetPort, 3000);
  });

  test('no free port nearby: the operating system picks one', () async {
    final c = container(pick: (_) => null);
    final forward = await c
        .read(adHocForwardsProvider.notifier)
        .forward(
          sessionId: 's1',
          hostId: 'h1',
          connection: idleConnection(),
          port: node,
        );
    expect(forward.tunnel.listenPort, 0);
    expect(forward.localPort, 49152);
  });

  test('forwarding the same port twice reuses the running forward', () async {
    final c = container();
    final notifier = c.read(adHocForwardsProvider.notifier);
    final connection = idleConnection();
    final first = await notifier.forward(
      sessionId: 's1',
      hostId: 'h1',
      connection: connection,
      port: node,
    );
    final second = await notifier.forward(
      sessionId: 's1',
      hostId: 'h1',
      connection: connection,
      port: node,
    );
    expect(second.id, first.id);
    expect(runners, hasLength(1));
  });

  test('stop frees it and forgets it', () async {
    final c = container();
    final notifier = c.read(adHocForwardsProvider.notifier);
    final forward = await notifier.forward(
      sessionId: 's1',
      hostId: 'h1',
      connection: idleConnection(),
      port: node,
    );
    await notifier.stop(forward.id);
    expect(c.read(adHocForwardsProvider), isEmpty);
    expect(runners.single.disposed, isTrue);
  });

  test(
    'a failed start stays listed as failed, and a retry replaces it',
    () async {
      final c = container(failWith: 'Address already in use');
      final notifier = c.read(adHocForwardsProvider.notifier);
      final connection = idleConnection();
      final failed = await notifier.forward(
        sessionId: 's1',
        hostId: 'h1',
        connection: connection,
        port: node,
      );
      expect(failed.status.state, TunnelRunState.failed);
      expect(failed.status.error, 'Address already in use');

      await notifier.forward(
        sessionId: 's1',
        hostId: 'h1',
        connection: connection,
        port: node,
      );
      expect(runners, hasLength(2));
      expect(runners.first.disposed, isTrue);
      expect(c.read(adHocForwardsProvider), hasLength(1));
    },
  );

  test('closing the tab\'s connection removes its forwards', () async {
    final c = container();
    final notifier = c.read(adHocForwardsProvider.notifier);
    final connection = idleConnection();
    await notifier.forward(
      sessionId: 's1',
      hostId: 'h1',
      connection: connection,
      port: node,
    );
    await connection.close();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(adHocForwardsProvider), isEmpty);
    expect(runners.single.disposed, isTrue);
  });

  group('tunnelFromAdHoc', () {
    final now = DateTime.utc(2026, 9, 22, 12);

    AdHocForward forward({String? process, int boundPort = 3001}) =>
        AdHocForward(
          tunnel: Tunnel(
            id: '${adHocIdPrefix}x',
            hostId: 'h1',
            label: 'Port 3000',
            kind: TunnelKind.local,
            listenPort: 3001,
            targetHost: '127.0.0.1',
            targetPort: 3000,
            createdAt: now,
            updatedAt: now,
          ),
          sessionId: 's1',
          remotePort: 3000,
          process: process,
          status: TunnelRunnerStatus(
            state: TunnelRunState.running,
            boundPort: boundPort,
            connections: 0,
          ),
        );

    test('same mapping, a real id, loopback, not auto-start', () {
      final saved = tunnelFromAdHoc(
        forward(process: 'node'),
        id: 'abc',
        now: now,
      );
      expect(saved.id, 'abc');
      expect(saved.hostId, 'h1');
      expect(saved.kind, TunnelKind.local);
      expect(saved.listenHost, '127.0.0.1');
      expect(saved.listenPort, 3001);
      expect(saved.targetHost, '127.0.0.1');
      expect(saved.targetPort, 3000);
      expect(saved.autoStart, isFalse);
      expect(saved.label, 'node (3000)');
      expect(saved.createdAt, now);
      expect(saved.updatedAt, now);
    });

    test('labelled by port when the process is unknown', () {
      expect(
        tunnelFromAdHoc(forward(), id: 'abc', now: now).label,
        'Port 3000',
      );
    });

    test('listens where the forward actually bound', () {
      final saved = tunnelFromAdHoc(
        forward(boundPort: 49152),
        id: 'abc',
        now: now,
      );
      expect(saved.listenPort, 49152);
      expect(Tunnel.isValidPort(saved.listenPort), isTrue);
    });
  });
}
