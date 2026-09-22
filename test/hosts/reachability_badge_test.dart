import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/hosts/domain/reachability.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/hosts/reachability_controller.dart';
import 'package:sshetu/features/hosts/widgets/host_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// A reachability state the test decides, with no scheduler behind it.
class _FixedReachability extends ReachabilityController {
  _FixedReachability(this._state);

  final ReachabilityState _state;

  @override
  ReachabilityState build() => _state;
}

/// The host row's reachability dot: what it says, and that it fits.
void main() {
  final created = DateTime.utc(2026);
  SshHost host({String? jump}) => SshHost(
    id: 'web',
    label: 'web-01 production frontend with a long name',
    hostname: 'web.example.com',
    username: 'deploy',
    jumpHostId: jump,
    tags: const ['prod', 'eu-west', 'nginx'],
    createdAt: created,
    updatedAt: created,
  );

  ProbeResult result(ProbeOutcome outcome) => ProbeResult(
    outcome,
    DateTime.now().subtract(const Duration(minutes: 2, seconds: 5)),
  );

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required SshHost row,
    bool enabled = true,
    ProbeResult? probe,
    Set<String> live = const {},
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostsProvider.overrideWith((ref) => [row]),
          liveSessionHostsProvider.overrideWithValue(
            LiveSessionHosts(hostIds: live),
          ),
          reachabilityProvider.overrideWith(
            () => _FixedReachability(
              ReachabilityState(
                enabled: enabled,
                results: {'web.example.com:22': ?probe},
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: ListView(children: [HostTile(host: row)]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final anyState = RegExp('Reachable|Unreachable|Not checked|Connected');

  for (final width in [360.0, 1280.0]) {
    group('at ${width.toInt()} px', () {
      testWidgets('up: latency and age in the label and tooltip', (
        tester,
      ) async {
        await pump(
          tester,
          width: width,
          row: host(),
          probe: result(const ProbeOutcome.up(Duration(milliseconds: 23))),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsLabel(
            RegExp(r'Reachable · 23 ms, Checked 2 min ago'),
          ),
          findsOneWidget,
        );
        expect(
          // material_ui's Tooltip, which `find.byTooltip` does not know.
          find.byWidgetPredicate(
            (w) =>
                w is Tooltip &&
                w.message == 'Reachable · 23 ms\nChecked 2 min ago',
          ),
          findsOneWidget,
        );
      });

      testWidgets('down: says why', (tester) async {
        await pump(
          tester,
          width: width,
          row: host(),
          probe: result(const ProbeOutcome.down(ReachabilityFailure.timedOut)),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsLabel(RegExp(r'Unreachable \(timed out\)')),
          findsOneWidget,
        );
      });

      testWidgets('not probed yet: unknown', (tester) async {
        await pump(tester, width: width, row: host());
        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsLabel(RegExp('Not checked yet')),
          findsOneWidget,
        );
      });

      testWidgets('a live session shows it up, whatever the probe said', (
        tester,
      ) async {
        await pump(
          tester,
          width: width,
          row: host(),
          live: {'web'},
          probe: result(const ProbeOutcome.down(ReachabilityFailure.refused)),
        );
        expect(
          find.bySemanticsLabel(RegExp('Connected · a session is open')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('Unreachable')), findsNothing);
      });

      testWidgets('behind a jump host: no dot', (tester) async {
        await pump(
          tester,
          width: width,
          row: host(jump: 'bastion'),
          probe: result(const ProbeOutcome.up(Duration(milliseconds: 1))),
        );
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel(anyState), findsNothing);
      });

      testWidgets('checking off: no dot', (tester) async {
        await pump(
          tester,
          width: width,
          row: host(),
          enabled: false,
          probe: result(const ProbeOutcome.up(Duration(milliseconds: 1))),
        );
        expect(find.bySemanticsLabel(anyState), findsNothing);
      });
    });
  }

  test('rules resolve in order: off, session, jump, result', () {
    final direct = host();
    final jumped = host(jump: 'bastion');
    final up = result(const ProbeOutcome.up(Duration(milliseconds: 3)));

    expect(
      HostReachability.resolve(
        host: direct,
        enabled: false,
        sessionConnected: true,
        result: up,
      ).kind,
      HostReachabilityKind.hidden,
    );
    expect(
      HostReachability.resolve(
        host: jumped,
        enabled: true,
        sessionConnected: true,
      ).kind,
      HostReachabilityKind.session,
    );
    expect(
      HostReachability.resolve(
        host: jumped,
        enabled: true,
        sessionConnected: false,
        result: up,
      ).kind,
      HostReachabilityKind.hidden,
    );
    expect(
      HostReachability.resolve(
        host: direct,
        enabled: true,
        sessionConnected: false,
      ).kind,
      HostReachabilityKind.unknown,
    );
  });

  test(
    'defaults: 5 min everywhere, desktops included (fail2ban aggressive mode)',
    () {
      expect(
        ReachabilityInterval.defaultFor(TargetPlatform.android),
        ReachabilityInterval.minutes5,
      );
      expect(
        ReachabilityInterval.defaultFor(TargetPlatform.iOS),
        ReachabilityInterval.minutes5,
      );
      for (final desktop in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(
          ReachabilityInterval.defaultFor(desktop),
          ReachabilityInterval.minutes5,
        );
      }
      expect(ReachabilityInterval.fromId('bogus'), isNull);
    },
  );
}
