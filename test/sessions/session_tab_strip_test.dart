import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/widgets/session_tab_strip.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/fake_shell.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// Twenty tabs in a strip that fits six: it scrolls, the selected tab is
/// brought into view however it was selected, and every close button can
/// still be hit.
void main() {
  late ProviderContainer container;
  late SessionManager manager;

  setUp(() async {
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
  });

  /// Not pumpAndSettle: a connecting tab's dot animates for ever.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpStrip(WidgetTester tester, {int count = 20}) async {
    for (var i = 0; i < count; i++) {
      manager.adopt(
        TerminalSession(
          id: 's$i',
          title: 'server-number-$i.example.com',
          hostId: 'h$i',
          connection: SshConnection(
            target: SshTarget(hostname: 'h$i.example', username: 'me'),
            verifierFactory: (_, _) => throw UnimplementedError(),
          ),
          launcher: FakeLauncher(),
          probe: () async => true,
        ),
      );
    }
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: SessionTabStrip(alwaysShow: true)),
        ),
      ),
    );
    await settle(tester);
  }

  Finder tab(int i) => find.text('server-number-$i.example.com');

  /// Whether the tab's whole width is inside the window.
  bool fullyShown(WidgetTester tester, int i) {
    final rect = tester.getRect(
      find.ancestor(of: tab(i), matching: find.byType(InkWell)).first,
    );
    return rect.left >= 0 && rect.right <= 900;
  }

  testWidgets('the strip scrolls; the selected tab is scrolled into view', (
    tester,
  ) async {
    await pumpStrip(tester);
    expect(tester.takeException(), isNull);
    // The last one was adopted last, so it is the active one — and showing.
    expect(fullyShown(tester, 19), isTrue);
    expect(fullyShown(tester, 0), isFalse);

    // Selected from elsewhere (the palette, Ctrl+Tab): brought into view.
    manager.select('s0');
    await settle(tester);
    expect(fullyShown(tester, 0), isTrue);

    manager.select('s12');
    await settle(tester);
    expect(fullyShown(tester, 12), isTrue);

    // A tab already showing does not make the strip jump.
    final before = tester.getRect(tab(12));
    final neighbour = tester.getRect(tab(11)).left >= 0 ? 11 : 13;
    manager.select('s$neighbour');
    await settle(tester);
    expect(tester.getRect(tab(12)), before);
  });

  testWidgets('close buttons stay hittable, far along the strip too', (
    tester,
  ) async {
    await pumpStrip(tester);
    manager.select('s3');
    await settle(tester);
    final close = find.descendant(
      of: find.ancestor(of: tab(3), matching: find.byType(InkWell)).first,
      matching: find.byType(IconButton),
    );
    expect(close.hitTestable(), findsOneWidget);
    await tester.tap(close);
    await settle(tester);
    expect(tab(3), findsNothing);
    expect(container.read(sessionManagerProvider), hasLength(19));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plain mouse wheel scrolls the strip sideways', (tester) async {
    await pumpStrip(tester);
    manager.select('s0');
    await settle(tester);
    final start = tester.getRect(tab(0)).left;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(tab(1))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pump();
    expect(tester.getRect(tab(0)).left, lessThan(start - 200));
  });
}
