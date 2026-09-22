import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/server_info/server_info_panel.dart';
import 'package:sshetu/features/server_info/widgets/sparkline.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_server_exec.dart';
import 'fixtures.dart';

/// The panel as someone sees it: a phone's sheet (360) and a desktop's side
/// column inside a wide window (1280).
void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeServerExec exec, {
    required Size size,
    double? panelWidth,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final panel = ServerInfoPanel(title: 'web-1', exec: exec, onClose: () {});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: panelWidth == null
              ? panel
              : Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    SizedBox(width: panelWidth, child: panel),
                  ],
                ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Answers stats with the two Ubuntu samples in turn, then the later one
  /// forever; ps and kill as given.
  FakeServerExec ubuntu({ExecResult Function(String command)? kill}) {
    var polls = 0;
    return FakeServerExec((command, stdin) {
      if (command.startsWith('kill ')) {
        return kill?.call(command) ?? const ExecResult(stdout: '', exitCode: 0);
      }
      if (stdin != null && stdin.contains('ps -eo')) {
        return const ExecResult(stdout: psProcps, exitCode: 0);
      }
      polls++;
      return ExecResult(
        stdout: polls == 1 ? ubuntuStats : ubuntuStatsLater,
        exitCode: 0,
      );
    });
  }

  for (final (name, size, width) in const [
    ('phone 360', Size(360, 740), null),
    ('desktop 1280', Size(1280, 800), 320.0),
  ]) {
    testWidgets('overview at $name: identity, CPU, memory, disks, network', (
      tester,
    ) async {
      final exec = ubuntu();
      await pump(tester, exec, size: size, panelWidth: width);

      expect(find.text('Server info · web-1'), findsOneWidget);
      expect(find.text('web-1'), findsOneWidget); // hostname row
      expect(find.text('Ubuntu 24.04.1 LTS'), findsOneWidget);
      expect(find.text('Linux 6.8.0-45-generic'), findsOneWidget);
      expect(find.text('4d 1h'), findsOneWidget);
      expect(find.text('0.52  0.58  0.59'), findsOneWidget);
      // First sample: no CPU % yet.
      expect(find.text('Measuring…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('serverInfo.cpuPercent')))
            .data,
        '40%',
      );
      expect(find.byType(Sparkline), findsOneWidget);
      expect(find.text('2 cores'), findsOneWidget);

      final overview = find.byKey(const Key('serverInfo.overview'));
      await tester.dragUntilVisible(
        find.text('/mnt/backup disk'),
        overview,
        const Offset(0, -120),
      );
      expect(find.text('/dev/shm'), findsNothing);
      await tester.dragUntilVisible(
        find.text('98 KB/s'),
        overview,
        const Offset(0, -120),
      );
      expect(find.text('9.8 KB/s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('processes at $name: sorted, filtered, kill confirmed', (
      tester,
    ) async {
      final exec = ubuntu();
      await pump(tester, exec, size: size, panelWidth: width);
      await tester.tap(find.widgetWithText(Tab, 'Processes'));
      await tester.pumpAndSettle();

      // Polling pauses on this tab.
      final polls = exec.calls.where((c) => c.command == 'sh -s').length;
      await tester.pump(const Duration(seconds: 9));
      expect(
        exec.calls.where((c) => c.command == 'sh -s').length,
        polls,
        reason: 'no stats polls while the Processes tab shows',
      );

      final rows = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(rows.first, 'nginx');

      await tester.tap(find.text('Memory'));
      await tester.pump();
      expect(
        (tester.widgetList<ListTile>(find.byType(ListTile)).first.title!
                as Text)
            .data,
        'postgres',
      );

      await tester.enterText(find.byKey(const Key('processes.filter')), 'ngin');
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget);

      await tester.tap(find.byTooltip('Actions for nginx'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('process.term')));
      await tester.pumpAndSettle();
      expect(find.text('Stop nginx?'), findsOneWidget);
      expect(find.textContaining('PID 1234'), findsOneWidget);
      await tester.tap(find.text('Kill'));
      await tester.pumpAndSettle();
      expect(exec.calls.map((c) => c.command), contains('kill -15 1234'));
      expect(find.text('Sent SIGTERM to nginx (PID 1234)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a refused kill says why, in the server\'s words', (
    tester,
  ) async {
    final exec = ubuntu(
      kill: (_) => const ExecResult(
        stdout: '',
        stderr: 'sh: kill: (1) - Operation not permitted\n',
        exitCode: 1,
      ),
    );
    await pump(tester, exec, size: const Size(360, 740));
    await tester.tap(find.widgetWithText(Tab, 'Processes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('processes.filter')),
      'systemd',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Actions for systemd'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('process.kill')));
    await tester.pumpAndSettle();
    expect(find.text('Force kill systemd?'), findsOneWidget);
    await tester.tap(find.text('Force kill'));
    await tester.pumpAndSettle();
    expect(exec.calls.map((c) => c.command), contains('kill -9 1'));
    expect(find.textContaining('Operation not permitted'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation sends nothing', (tester) async {
    final exec = ubuntu();
    await pump(tester, exec, size: const Size(360, 740));
    await tester.tap(find.widgetWithText(Tab, 'Processes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actions for nginx'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('process.term')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(exec.calls.any((c) => c.command.startsWith('kill')), isFalse);
  });

  testWidgets('limited system: says so, shows what it has', (tester) async {
    final exec = FakeServerExec(
      (_, _) => const ExecResult(
        stdout: '@@sshetu:uname\nOpenBSD\n7.5\n@@sshetu:end\n',
        exitCode: 0,
      ),
    );
    await pump(tester, exec, size: const Size(360, 740));
    expect(
      find.textContaining('Limited information on this system'),
      findsOneWidget,
    );
    expect(find.text('OpenBSD 7.5'), findsOneWidget);
  });

  testWidgets('offline before the first sample: says so, never dials', (
    tester,
  ) async {
    final exec = FakeServerExec(
      (_, _) => const ExecResult(stdout: ubuntuStats),
      connected: false,
    );
    await pump(tester, exec, size: const Size(1280, 800), panelWidth: 320);
    expect(find.text('Not connected'), findsOneWidget);
    expect(exec.calls, isEmpty);
  });

  testWidgets('busybox ps: CPU and memory sorting disabled, note shown', (
    tester,
  ) async {
    final exec = FakeServerExec((command, stdin) {
      if (stdin != null && stdin.contains('ps -eo')) {
        return const ExecResult(stdout: psBusybox, exitCode: 0);
      }
      return const ExecResult(stdout: routerStats, exitCode: 0);
    });
    await pump(tester, exec, size: const Size(360, 740));
    await tester.tap(find.widgetWithText(Tab, 'Processes'));
    await tester.pumpAndSettle();
    expect(
      find.text("This server's ps does not report CPU or memory use."),
      findsOneWidget,
    );
    expect(find.text('/sbin/init'), findsOneWidget);
    expect(find.text('dropbear -p 22'), findsOneWidget);
  });
}
