import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/server_info/server_info_dock.dart';
import 'package:sshetu/features/server_info/server_info_panel.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/fake_shell.dart';

class _QuietTriggers extends ReconnectTriggers {
  final _controller = StreamController<ReconnectTrigger>.broadcast();

  @override
  Stream<ReconnectTrigger> get events => _controller.stream;

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }
}

/// The desktop panel: beside the terminal when both fit, over it when not,
/// following the selected tab.
void main() {
  late ProviderContainer container;

  TerminalSession tab(String id) => TerminalSession(
    id: id,
    title: id,
    hostId: id,
    connection: SshConnection(
      target: const SshTarget(hostname: 'example.invalid', username: 'me'),
      verifierFactory: (_, _) => throw UnimplementedError(),
    ),
    launcher: FakeLauncher()..origins = [ShellOrigin.plain],
    probe: () async => true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(_QuietTriggers()),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: ServerInfoDock(
              child: ColoredBox(key: Key('terminal'), color: Color(0x00000000)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('closed: just the terminal', (tester) async {
    container.read(sessionManagerProvider.notifier).adopt(tab('a'));
    await pump(tester, 1280);
    expect(find.byType(ServerInfoPanel), findsNothing);
  });

  testWidgets('open at 1280: beside the terminal, following the active tab', (
    tester,
  ) async {
    final manager = container.read(sessionManagerProvider.notifier)
      ..adopt(tab('a'))
      ..adopt(tab('b'));
    manager.select('a');
    container.read(serverInfoDockProvider.notifier).open();
    await pump(tester, 1280);

    expect(find.byType(ServerInfoPanel), findsOneWidget);
    expect(find.text('Server info · a'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('terminal'))).width, 1280 - 321);
    // The tab's connection is not up, and the panel does not dial it.
    expect(find.text('Not connected'), findsOneWidget);

    manager.select('b');
    await tester.pump();
    expect(find.text('Server info · b'), findsOneWidget);

    await tester.tap(find.byKey(const Key('serverInfo.close')));
    await tester.pump();
    expect(find.byType(ServerInfoPanel), findsNothing);
    expect(container.read(serverInfoDockProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('too narrow for both: over the terminal, which keeps its width', (
    tester,
  ) async {
    container.read(sessionManagerProvider.notifier).adopt(tab('a'));
    container.read(serverInfoDockProvider.notifier).open();
    await pump(tester, 600);
    expect(find.byType(ServerInfoPanel), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('terminal'))).width, 600);
    expect(tester.getSize(find.byType(ServerInfoPanel)).width, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no sessions: nothing to show even when open', (tester) async {
    container.read(serverInfoDockProvider.notifier).open();
    await pump(tester, 1280);
    expect(find.byType(ServerInfoPanel), findsNothing);
  });
  testWidgets('openServerInfo: a sheet at phone width, the dock at desktop', (
    tester,
  ) async {
    final session = tab('a');
    container.read(sessionManagerProvider.notifier).adopt(session);

    Future<void> host(double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: ServerInfoDock(
                child: Consumer(
                  builder: (context, ref, _) => Center(
                    child: TextButton(
                      onPressed: () => openServerInfo(context, ref, session),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await host(360);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(ServerInfoPanel), findsOneWidget);
    expect(container.read(serverInfoDockProvider), isFalse);
    await tester.tap(find.byKey(const Key('serverInfo.close')));
    await tester.pumpAndSettle();
    expect(find.byType(ServerInfoPanel), findsNothing);

    await host(1280);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(container.read(serverInfoDockProvider), isTrue);
    expect(find.byType(ServerInfoPanel), findsOneWidget);
    // Again on the same tab: a toggle.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(container.read(serverInfoDockProvider), isFalse);
    expect(tester.takeException(), isNull);
  });
}
