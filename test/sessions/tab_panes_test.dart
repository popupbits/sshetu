import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/pane_layouts.dart';
import 'package:sshetu/features/sessions/pane_tree.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/widgets/tab_panes.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:xterm2/xterm.dart';

import '../support/fake_shell.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// A split tab at a desktop width and at a phone width: tiled panes on one,
/// one pane and a switcher on the other — never squeezed panes.
void main() {
  late ProviderContainer container;
  late SessionManager manager;

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final triggers = FakeTriggers();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(triggers),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(triggers.dispose);
    manager = container.read(sessionManagerProvider.notifier);

    TerminalSession pane(String id) => TerminalSession(
      id: id,
      title: 'host-$id',
      hostId: id,
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: FakeLauncher(),
      probe: () async => true,
    );

    final a = pane('a');
    final b = pane('b');
    final c = pane('c');
    manager.adopt(a);
    manager.adopt(
      b,
      split: const PaneSplitRequest(target: 'a', axis: SplitAxis.horizontal),
    );
    manager.adopt(
      c,
      split: const PaneSplitRequest(target: 'b', axis: SplitAxis.vertical),
    );
    await tester.runAsync(() async {
      await a.start();
      await b.start();
      await c.start();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(body: TerminalWorkspace()),
        ),
      ),
    );
    await tester.pump();
  }

  /// Ends the sessions and lets their timers run out.
  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final id in ['a', 'b', 'c']) {
      manager.close(id);
    }
    await tester.pump(const Duration(seconds: 3));
  }

  group('at 1280 wide', () {
    const desktop = Size(1280, 800);

    testWidgets('the panes are tiled side by side, each at least the '
        'minimum', (tester) async {
      await pumpAt(tester, desktop);
      expect(find.byType(SplitPaneView), findsOneWidget);
      expect(find.byType(PaneSwitcherView), findsNothing);
      expect(find.byType(TerminalView), findsNWidgets(3));

      final a = tester.getRect(find.byKey(const ValueKey('pane.header.a')));
      final b = tester.getRect(find.byKey(const ValueKey('pane.header.b')));
      final c = tester.getRect(find.byKey(const ValueKey('pane.header.c')));
      expect(b.left, greaterThan(a.right - 1), reason: 'b is right of a');
      expect(c.top, greaterThan(b.bottom), reason: 'c is below b');
      for (final rect in [a, b, c]) {
        expect(rect.width, greaterThanOrEqualTo(kMinPaneSize.width));
      }
      // One tab in the strip, with its pane count.
      expect(find.byKey(const Key('tab.paneCount')), findsOneWidget);
      await tearDownTree(tester);
    });

    testWidgets('clicking a pane header makes it the active pane', (
      tester,
    ) async {
      await pumpAt(tester, desktop);
      expect(manager.activeId, 'c');
      await tester.tap(find.byKey(const ValueKey('pane.header.a')));
      await tester.pump();
      expect(manager.activeId, 'a');
      await tearDownTree(tester);
    });

    testWidgets('broadcast marks every receiving pane, and exclusion '
        'unmarks one', (tester) async {
      await pumpAt(tester, desktop);
      container.read(paneLayoutsProvider.notifier).setBroadcast('a', true);
      await tester.pump();
      // The pane being typed into says how many others receive it.
      expect(
        find.text('Typing in all panes · 2 other panes receive this'),
        findsOneWidget,
      );
      expect(find.text('Receives what is typed in any pane'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('pane.exclude.b')));
      await tester.pump();
      expect(find.text('Left out of typing in all panes'), findsOneWidget);
      expect(
        find.text('Typing in all panes · 1 other pane receives this'),
        findsOneWidget,
      );
      await tearDownTree(tester);
    });

    testWidgets('closing a pane from its header collapses the split', (
      tester,
    ) async {
      await pumpAt(tester, desktop);
      await tester.tap(find.byKey(const ValueKey('pane.close.b')));
      await tester.pump();
      expect(find.byType(TerminalView), findsNWidgets(2));
      expect(container.read(paneLayoutsProvider).single.panes, ['a', 'c']);
      await tearDownTree(tester);
    });

    testWidgets('maximize shows one pane, and restores', (tester) async {
      await pumpAt(tester, desktop);
      container.read(paneLayoutsProvider.notifier).toggleMaximize('a');
      await tester.pump();
      expect(find.byType(TerminalView), findsOneWidget);
      container.read(paneLayoutsProvider.notifier).toggleMaximize('a');
      await tester.pump();
      expect(find.byType(TerminalView), findsNWidgets(3));
      await tearDownTree(tester);
    });
  });

  group('at 360 wide', () {
    const phone = Size(360, 740);

    testWidgets('one pane at a time, with a switcher', (tester) async {
      await pumpAt(tester, phone);
      expect(find.byType(SplitPaneView), findsNothing);
      expect(find.byKey(const Key('panes.switcher')), findsOneWidget);
      expect(find.byType(TerminalView), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('panes.switch.a')));
      await tester.pump();
      expect(manager.activeId, 'a');
      expect(find.byType(TerminalView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('broadcast shows a banner above the one visible pane', (
      tester,
    ) async {
      await pumpAt(tester, phone);
      expect(find.byKey(const Key('panes.broadcastBanner')), findsNothing);
      container.read(paneLayoutsProvider.notifier).setBroadcast('a', true);
      await tester.pump();
      expect(find.byKey(const Key('panes.broadcastBanner')), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(find.byKey(const Key('panes.broadcastBanner')), findsNothing);
      expect(container.read(paneLayoutsProvider).single.broadcast, isFalse);
      await tearDownTree(tester);
    });
  });
}
