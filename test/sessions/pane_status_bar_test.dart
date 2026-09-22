import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/widgets/pane_status_bar.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/fake_shell.dart';
import '../support/fake_timers.dart';

/// What the bar over a dropped pane says, at a phone's width and a
/// desktop's.
void main() {
  late FakeTimers timers;
  late FakeLauncher launcher;

  TerminalSession build() {
    final session = TerminalSession(
      id: 'host-0',
      title: 'test',
      hostId: 'host',
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: () async => true,
      reconnectTimer: timers.create,
      clock: timers.now,
    );
    addTearDown(session.dispose);
    return session;
  }

  setUp(() {
    timers = FakeTimers();
    launcher = FakeLauncher();
  });

  Future<void> pump(
    WidgetTester tester,
    TerminalSession session,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: Column(
            children: [PaneStatusBar(session: session, clock: timers.now)],
          ),
        ),
      ),
    );
  }

  Future<TerminalSession> dropped(WidgetTester tester) async {
    final session = build();
    await session.start();
    launcher.shells.single.drop();
    await tester.pump();
    return session;
  }

  testWidgets('desktop: the whole sentence, with the attempt number', (
    tester,
  ) async {
    final session = await dropped(tester);
    await pump(tester, session, 1200);

    expect(
      find.text('Connection lost — reconnecting in 2 s (attempt 1)'),
      findsOneWidget,
    );
    expect(find.text('Retry now'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: the short form, and nothing overflows', (tester) async {
    final session = await dropped(tester);
    await pump(tester, session, 360);

    expect(find.text('Reconnecting in 2 s'), findsOneWidget);
    expect(find.text('Retry now'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the countdown ticks, and the attempt count climbs', (
    tester,
  ) async {
    final session = await dropped(tester);
    await pump(tester, session, 1200);

    timers.elapse(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Connection lost — reconnecting in 1 s (attempt 1)'),
      findsOneWidget,
    );

    // The first attempt fails; the next wait is 3 s.
    launcher.failWith = SshConnectionException('unreachable', retryable: true);
    timers.elapse(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Connection lost — reconnecting in 3 s (attempt 2)'),
      findsOneWidget,
    );
  });

  testWidgets('while an attempt runs it says so, and can still be stopped', (
    tester,
  ) async {
    final session = await dropped(tester);
    await pump(tester, session, 1200);

    launcher.hold = Completer<void>();
    await tester.tap(find.text('Retry now'));
    await tester.pump();
    expect(find.text('Reconnecting…'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    launcher.hold!.complete();
    await tester.pumpAndSettle();
    expect(session.status, TerminalSessionStatus.running);
  });

  for (final width in [360.0, 1200.0]) {
    testWidgets('Stop leaves the manual Reconnect at ${width.toInt()}px', (
      tester,
    ) async {
      final session = await dropped(tester);
      await pump(tester, session, width);

      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(find.text('Session ended'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Retry now'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a clean exit offers Reconnect and no countdown', (tester) async {
    final session = build();
    await session.start();
    launcher.shells.single.exit();
    await tester.pump();
    await pump(tester, session, 1200);

    expect(find.text('Session ended'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Retry now'), findsNothing);
  });
}
