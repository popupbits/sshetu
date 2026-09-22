import 'dart:async';

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
import 'package:sshetu/features/sessions/terminal_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/fake_shell.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// The phone terminal's bar on the narrowest phone still in use (320 pt):
/// nothing overflows, and every action — the buttons and each row of the
/// More menu, even on a short landscape screen — can be reached.
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

  Future<void> pumpScreen(WidgetTester tester, Size size, Locale locale) async {
    final session = TerminalSession(
      id: 'a',
      title: 'production-database-eu-west-1',
      hostId: 'a',
      connection: SshConnection(
        target: const SshTarget(
          hostname: 'production-database-eu-west-1.internal.example.com',
          username: 'deploy',
          port: 2222,
          // A password session, so the menu has its longest list.
          authMethod: SshAuthMethod.password,
        ),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: FakeLauncher(),
      probe: () async => true,
    );
    manager.adopt(session);
    await tester.runAsync(session.start);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          navigatorKey: navigator,
          home: const SizedBox(),
        ),
      ),
    );
    // Pushed, as it is in the app, so the bar has its back button too.
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const TerminalScreen(sessionId: 'a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final session in List.of(container.read(sessionManagerProvider))) {
      manager.close(session.id);
    }
    await tester.pump(const Duration(seconds: 3));
  }

  const menuKeys = [
    'terminal.files',
    'terminal.runningSessions',
    'terminal.serverInfo',
    'terminal.log',
    'terminal.ports',
    'terminal.keySetup',
  ];

  for (final locale in const [Locale('en'), Locale('ne')]) {
    for (final size in const [Size(320, 568), Size(320, 260)]) {
      testWidgets('${locale.languageCode} at ${size.width.toInt()}×'
          '${size.height.toInt()}: bar fits, every action reachable', (
        tester,
      ) async {
        await pumpScreen(tester, size, locale);
        expect(tester.takeException(), isNull, reason: 'the bar overflowed');
        expect(
          tester.getSize(find.text('production-database-eu-west-1')).width,
          greaterThanOrEqualTo(64),
          reason: 'the title kept some room',
        );

        for (final button in const ['terminal.snippets', 'terminal.more']) {
          expect(find.byKey(Key(button)).hitTestable(), findsOneWidget);
        }

        await tester.tap(find.byKey(const Key('terminal.more')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'the menu overflowed');
        for (final key in menuKeys) {
          final item = find.byKey(Key(key));
          expect(item, findsOneWidget, reason: key);
          await tester.ensureVisible(item);
          await tester.pumpAndSettle();
          expect(item.hitTestable(), findsOneWidget, reason: '$key reachable');
        }
        await tearDownTree(tester);
      });
    }
  }

  testWidgets('at 360 pt Files is a button, not a menu row', (tester) async {
    await pumpScreen(tester, const Size(360, 640), const Locale('en'));
    expect(
      find.byKey(const Key('terminal.files')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('terminal.more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terminal.files')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownTree(tester);
  });
}
