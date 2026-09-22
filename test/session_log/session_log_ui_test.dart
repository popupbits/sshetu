import 'dart:async';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/session_log/domain/log_format.dart';
import 'package:sshetu/features/session_log/domain/session_logger.dart';
import 'package:sshetu/features/session_log/session_log_controller.dart';
import 'package:sshetu/features/session_log/session_log_palette.dart';
import 'package:sshetu/features/session_log/session_log_settings.dart';
import 'package:sshetu/features/session_log/widgets/session_log_tile.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/terminal_screen.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:sshetu/l10n/app_localizations_en.dart';

import '../sessions/reconnect_triggers_test.dart' show FakeTriggers;
import '../support/fake_shell.dart';
import 'fake_log_sink.dart';

/// The logging entries where a person looks for them — the tab's menu on a
/// desktop, the terminal's More menu on a phone, the palette, Settings —
/// and the dot that says a tab is being logged.
void main() {
  late ProviderContainer container;
  late Map<String, FakeLogSink> sinks;
  late SessionManager manager;

  Future<void> setUpContainer({bool appFolder = true}) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final triggers = FakeTriggers();
    sinks = {};
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(triggers),
        // No save dialog in a test: the app-folder path is the one that
        // does not need a platform channel.
        sessionLogUsesAppFolderProvider.overrideWithValue(appFolder),
        sessionLogAppFolderProvider.overrideWithValue(() async => '/app/logs'),
        sessionLogSinkFactoryProvider.overrideWithValue(
          (path) async => sinks[path] = FakeLogSink(path),
        ),
        sessionLoggerFactoryProvider.overrideWithValue(
          ({required encoder, required sink, onWarn, onError}) => SessionLogger(
            encoder: encoder,
            sink: sink,
            onWarn: onWarn,
            onError: onError,
            timer: (_, _) => _IdleTimer(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(triggers.dispose);
    manager = container.read(sessionManagerProvider.notifier);
  }

  Future<TerminalSession> openTab(WidgetTester tester, String id) async {
    final session = TerminalSession(
      id: id,
      title: 'web-1',
      hostId: id,
      connection: SshConnection(
        target: const SshTarget(hostname: 'web.example', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: FakeLauncher(),
      probe: () async => true,
    );
    manager.adopt(session);
    await tester.runAsync(session.start);
    return session;
  }

  Future<void> pump(WidgetTester tester, Size size, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: home,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final session in List.of(container.read(sessionManagerProvider))) {
      manager.close(session.id);
    }
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> chooseStart(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sessionLog.startDialog')), findsOneWidget);
    // All three formats, and the privacy note, are on offer.
    expect(find.text('Plain text'), findsOneWidget);
    expect(find.text('Raw (with colours)'), findsOneWidget);
    expect(find.text('asciicast (.cast)'), findsOneWidget);
    expect(find.textContaining('Passwords typed at a prompt'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('sessionLog.format.asciicast')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sessionLog.start')));
    await tester.pumpAndSettle();
  }

  group('at 1280 wide', () {
    const desktop = Size(1280, 800);

    testWidgets(
      'the tab menu starts a log; the tab shows the dot; the menu then stops '
      'it',
      (tester) async {
        await setUpContainer();
        await openTab(tester, 'a');
        await pump(tester, desktop, const Scaffold(body: TerminalWorkspace()));
        expect(find.byKey(const ValueKey('sessionLog.dot.a')), findsNothing);

        await tester.tap(find.text('web-1'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start logging…'));
        await chooseStart(tester);

        expect(find.byKey(const ValueKey('sessionLog.dot.a')), findsOneWidget);
        final path = sinks.keys.single;
        expect(path, endsWith('.cast'));
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byKey(const ValueKey('sessionLog.dot.a')),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, contains(p.basename(path)));

        await tester.tap(find.text('web-1'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stop logging'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('sessionLog.dot.a')), findsNothing);
        expect(sinks[path]!.closed, isTrue);
        await tearDownTree(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets('Settings: folder, always-log (off until a folder), format', (
      tester,
    ) async {
      await setUpContainer(appFolder: false);
      await pump(
        tester,
        desktop,
        const Scaffold(body: SingleChildScrollView(child: SessionLogTile())),
      );
      expect(find.byKey(const Key('sessionLog.folder')), findsOneWidget);
      final always = tester.widget<SwitchListTile>(
        find.byKey(const Key('sessionLog.always')),
      );
      expect(always.value, isFalse);
      expect(always.onChanged, isNull, reason: 'no folder yet');

      await container
          .read(sessionLogSettingsProvider.notifier)
          .setFolder('/home/me/logs');
      await tester.pump();
      expect(find.text('/home/me/logs'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sessionLog.always')));
      await tester.pump();
      expect(container.read(sessionLogSettingsProvider).alwaysLog, isTrue);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('at 360 wide', () {
    const phone = Size(360, 740);

    setUp(() {
      // The terminal screen holds a wake lock; there is no plugin here.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.'
            'WakelockPlusApi.toggle',
            (_) async =>
                const StandardMessageCodec().encodeMessage(<Object?>[null]),
          );
    });

    testWidgets('the terminal\'s More menu starts and stops a log, with the '
        'dot in the title', (tester) async {
      await setUpContainer();
      await openTab(tester, 'a');
      await pump(tester, phone, const TerminalScreen(sessionId: 'a'));

      await tester.tap(find.byKey(const Key('terminal.more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terminal.log')), findsOneWidget);
      expect(find.text('Start logging…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('terminal.log')));
      await chooseStart(tester);

      expect(find.byKey(const ValueKey('sessionLog.dot.a')), findsOneWidget);
      expect(sinks.keys.single, startsWith('/app/logs'));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('terminal.more')));
      await tester.pumpAndSettle();
      expect(find.text('Stop logging'), findsOneWidget);
      await tester.tap(find.byKey(const Key('terminal.log')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sessionLog.dot.a')), findsNothing);
      await tearDownTree(tester);
    });

    testWidgets('Settings on a phone: no folder row, always-log available', (
      tester,
    ) async {
      await setUpContainer();
      await pump(
        tester,
        phone,
        const Scaffold(body: SingleChildScrollView(child: SessionLogTile())),
      );
      expect(find.byKey(const Key('sessionLog.folder')), findsNothing);
      final always = tester.widget<SwitchListTile>(
        find.byKey(const Key('sessionLog.always')),
      );
      expect(always.onChanged, isNotNull);
      expect(find.byKey(const Key('sessionLog.formatPicker')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('the palette offers start, then stop, for the tab in front', () async {
    await setUpContainer();
    final session = TerminalSession(
      id: 'a',
      title: 'web-1',
      hostId: 'a',
      connection: SshConnection(
        target: const SshTarget(hostname: 'web.example', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: FakeLauncher(),
      probe: () async => true,
    );
    final l10n = AppLocalizationsEn();
    expect(container.read(sessionLogPaletteItemsProvider(l10n)), isEmpty);
    manager.adopt(session);
    var items = container.read(sessionLogPaletteItemsProvider(l10n));
    expect(items.single.title, 'Start logging…');
    expect(items.single.category, PaletteCategory.action);

    await container
        .read(sessionLogControllerProvider.notifier)
        .start(session, SessionLogFormat.plain, '/x/a.log');
    items = container.read(sessionLogPaletteItemsProvider(l10n));
    expect(items.single.title, 'Stop logging');
    await container.read(sessionLogControllerProvider.notifier).stop('a');
    manager.close('a');
  });
}

class _IdleTimer implements Timer {
  var _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
