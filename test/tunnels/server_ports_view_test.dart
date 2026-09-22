import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/ssh/tunnel_runner.dart';
import 'package:sshetu/features/hosts/data/host_repository.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/server_info/server_info_panel.dart';
import 'package:sshetu/features/tunnels/ad_hoc_forwards.dart';
import 'package:sshetu/features/tunnels/data/tunnel_repository.dart';
import 'package:sshetu/features/tunnels/domain/far_end.dart';
import 'package:sshetu/features/tunnels/domain/listening_ports.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';
import 'package:sshetu/features/tunnels/far_end_monitor.dart';
import 'package:sshetu/features/tunnels/ports_monitor.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';
import 'package:sshetu/features/tunnels/widgets/server_ports_view.dart';
import 'package:sshetu/features/tunnels/widgets/tunnel_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../server_info/fake_server_exec.dart';
import 'fake_tunnel_runner.dart';

const _ss = '''
@@sshetu:ss
LISTEN 0 4096 127.0.0.53%lo:53 0.0.0.0:* users:(("systemd-resolve",pid=652,fd=14))
LISTEN 0 128 0.0.0.0:22 0.0.0.0:*
LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:(("node",pid=4242,fd=21))
LISTEN 0 5 0.0.0.0:8000 0.0.0.0:* users:(("python3",pid=5150,fd=3))
LISTEN 0 244 [::1]:5432 [::]:*
LISTEN 0 5 0.0.0.0:2229 0.0.0.0:*
''';

class _Manager extends TunnelRunnerManager {
  _Manager(this.initial);

  final Map<String, TunnelRunnerStatus> initial;

  @override
  Map<String, TunnelRunnerStatus> build() => initial;
}

class _FarEnds extends FarEndMonitor {
  _FarEnds(this.initial);

  final Map<String, FarEndStatus> initial;

  @override
  Map<String, FarEndStatus> build() => initial;
}

/// Records saves; no database, which a widget test's fake clock cannot drive.
class _FakeTunnels implements TunnelRepository {
  final saved = <Tunnel>[];

  /// Takes time, as a real write does: long enough for a frame to land
  /// between stopping the ad-hoc forward and the save completing, which is
  /// when the menu chip unmounts.
  @override
  Future<void> save(Tunnel tunnel) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    saved.add(tunnel);
  }

  @override
  Future<List<Tunnel>> all() async => saved;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Knows no hosts, and records who asked.
class _FakeHosts implements HostRepository {
  final lookedUp = <String>[];

  @override
  Future<SshHost?> byId(String id) async {
    lookedUp.add(id);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, List overrides) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: Scaffold(body: child),
  ),
);

void main() {
  final runners = <FakeTunnelRunner>[];

  var extraOverrides = <Object>[];

  List overrides() => [
    adHocRunnerFactoryProvider.overrideWithValue((tunnel, _) {
      final runner = FakeTunnelRunner(tunnel);
      runners.add(runner);
      return runner;
    }),
    adHocPortPickerProvider.overrideWithValue((port) async => port),
    ...extraOverrides,
  ];

  setUp(() {
    runners.clear();
    extraOverrides = [];
  });

  Future<FakeServerExec> pumpPorts(
    WidgetTester tester, {
    required Size size,
    double? panelWidth,
    String output = _ss,
    bool connected = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final exec = FakeServerExec(
      (command, stdin) => ExecResult(stdout: output, exitCode: 0),
      connected: connected,
    );
    final view = ServerPortsView(
      exec: exec,
      sessionId: 's1',
      hostId: 'h1',
      connection: idleConnection(),
      alsoIgnore: const {2229},
      monitorFactory: (exec) => PortsMonitor(exec, alsoIgnore: const {2229}),
    );
    await tester.pumpWidget(
      _app(
        panelWidth == null
            ? view
            : Row(
                children: [
                  const Expanded(child: SizedBox()),
                  SizedBox(width: panelWidth, child: view),
                ],
              ),
        overrides(),
      ),
    );
    await tester.pump();
    await tester.pump();
    return exec;
  }

  for (final (name, size, width) in const [
    ('phone 360', Size(360, 740), null),
    ('desktop 1280', Size(1280, 800), 320.0),
  ]) {
    testWidgets('at $name: lists user ports, forwards on a tap', (
      tester,
    ) async {
      final exec = await pumpPorts(tester, size: size, panelWidth: width);

      // One exec of the ports script, over the tab's connection.
      expect(exec.calls.single.command, 'sh -s');
      expect(exec.calls.single.stdin, portsScript);

      // System ports and this connection's sshd are left out.
      expect(find.byKey(const Key('ports.row.3000')), findsOneWidget);
      expect(find.byKey(const Key('ports.row.8000')), findsOneWidget);
      expect(find.byKey(const Key('ports.row.5432')), findsOneWidget);
      expect(find.byKey(const Key('ports.row.22')), findsNothing);
      expect(find.byKey(const Key('ports.row.53')), findsNothing);
      expect(find.byKey(const Key('ports.row.2229')), findsNothing);
      expect(find.text('node'), findsOneWidget);
      expect(find.text('python3'), findsOneWidget);
      expect(find.text('This server only'), findsNWidgets(2));
      expect(find.text('All interfaces'), findsOneWidget);

      // Nothing is forwarded until someone taps.
      expect(runners, isEmpty);

      await tester.tap(find.byKey(const Key('ports.forward.3000')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(runners, hasLength(1));
      expect(runners.single.tunnel.listenPort, 3000);
      expect(runners.single.tunnel.targetHost, '127.0.0.1');
      expect(runners.single.tunnel.targetPort, 3000);
      expect(find.text('localhost:3000'), findsOneWidget);
      expect(find.byKey(const Key('ports.forward.3000')), findsNothing);
      expect(find.byKey(const Key('ports.forward.8000')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ports.menu.3000')));
      await tester.pumpAndSettle();
      expect(find.text('Open in browser'), findsOneWidget);
      expect(find.text('Copy address'), findsOneWidget);
      expect(find.text('Save as tunnel'), findsOneWidget);

      await tester.tap(find.text('Stop forward'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ports.forward.3000')), findsOneWidget);
      expect(runners.single.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });

    // Regression: the save ran on the menu chip's context, and the save
    // itself unmounts that chip (stopping the ad-hoc forward swaps it for
    // the Forward button). It returned right there: saved, never started.
    testWidgets('at $name: save as tunnel saves it, then starts it', (
      tester,
    ) async {
      final tunnels = _FakeTunnels();
      final hosts = _FakeHosts();
      extraOverrides = [
        tunnelRepositoryProvider.overrideWithValue(tunnels),
        hostRepositoryProvider.overrideWithValue(hosts),
      ];
      await pumpPorts(tester, size: size, panelWidth: width);

      await tester.tap(find.byKey(const Key('ports.forward.8000')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('ports.menu.8000')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ports.saveAsTunnel')));
      // Frames first (the chip goes), then the write finishes.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(runners.single.disposed, isTrue);
      expect(tunnels.saved.single.label, 'python3 (8000)');
      expect(tunnels.saved.single.hostId, 'h1');
      // startTunnel was reached (it looks the host up), and the save got as
      // far as saying so.
      expect(hosts.lookedUp, ['h1']);
      expect(find.text('Saved as tunnel "python3 (8000)"'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at $name: an IPv6-loopback port dials ::1', (tester) async {
      await pumpPorts(tester, size: size, panelWidth: width);
      await tester.tap(find.byKey(const Key('ports.forward.5432')));
      await tester.pump();
      await tester.pump();
      expect(runners.single.tunnel.targetHost, '::1');
    });
  }

  testWidgets('nothing listening says so', (tester) async {
    await pumpPorts(
      tester,
      size: const Size(360, 740),
      output: '@@sshetu:ss\nLISTEN 0 128 0.0.0.0:22 0.0.0.0:*\n',
    );
    expect(find.text('No listening ports found'), findsOneWidget);
  });

  testWidgets('offline says so, and runs nothing', (tester) async {
    final exec = await pumpPorts(
      tester,
      size: const Size(360, 740),
      connected: false,
    );
    expect(find.text('Not connected'), findsOneWidget);
    expect(exec.calls, isEmpty);
  });

  testWidgets('polls every 5 s while shown, and stops when removed', (
    tester,
  ) async {
    final exec = await pumpPorts(tester, size: const Size(360, 740));
    expect(exec.calls, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    expect(exec.calls, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
    expect(exec.calls, hasLength(2));
  });

  testWidgets('the server info panel opens on its Ports tab', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final exec = FakeServerExec(
      (command, stdin) => const ExecResult(stdout: '', exitCode: 0),
    );
    await tester.pumpWidget(
      _app(
        ServerInfoPanel(
          title: 'web-1',
          exec: exec,
          initialTab: ServerInfoPanel.portsTab,
          portsBuilder: (_) => const Text('ports body'),
        ),
        const [],
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('serverInfo.portsTab')), findsOneWidget);
    expect(find.text('ports body'), findsOneWidget);
  });

  group('tunnel tile far end', () {
    final now = DateTime.utc(2026, 1, 1);
    final tunnel = Tunnel(
      id: 't1',
      hostId: 'h1',
      label: 'db',
      kind: TunnelKind.local,
      listenPort: 15432,
      targetHost: '127.0.0.1',
      targetPort: 5432,
      createdAt: now,
      updatedAt: now,
    );
    const running = TunnelRunnerStatus(
      state: TunnelRunState.running,
      connections: 1,
      boundPort: 15432,
    );

    Future<void> pumpTile(
      WidgetTester tester, {
      required Size size,
      required TunnelRunnerStatus status,
      FarEndStatus? farEnd,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(ListView(children: [TunnelTile(tunnel: tunnel)]), [
          tunnelRunnersProvider.overrideWith(() => _Manager({'t1': status})),
          farEndMonitorProvider.overrideWith(() => _FarEnds({'t1': ?farEnd})),
        ]),
      );
      await tester.pump();
    }

    for (final (name, size) in const [
      ('360', Size(360, 740)),
      ('1280', Size(1280, 800)),
    ]) {
      testWidgets('at $name: target listening', (tester) async {
        await pumpTile(
          tester,
          size: size,
          status: running,
          farEnd: FarEndStatus.listening,
        );
        expect(find.text('Target listening'), findsOneWidget);
        // The probe is not one of its connections.
        expect(find.textContaining('1 active'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('at $name: nothing listening', (tester) async {
        await pumpTile(
          tester,
          size: size,
          status: running,
          farEnd: FarEndStatus.notListening,
        );
        expect(find.text('Nothing listening on target'), findsOneWidget);
      });
    }

    testWidgets('unknown or stopped shows nothing', (tester) async {
      await pumpTile(
        tester,
        size: const Size(360, 740),
        status: running,
        farEnd: FarEndStatus.unknown,
      );
      expect(find.text('Target listening'), findsNothing);
      expect(find.text('Nothing listening on target'), findsNothing);

      await pumpTile(
        tester,
        size: const Size(360, 740),
        status: const TunnelRunnerStatus.stopped(),
        farEnd: FarEndStatus.listening,
      );
      expect(find.text('Target listening'), findsNothing);
    });
  });
}
