import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/session_log/domain/log_format.dart';
import 'package:sshetu/features/session_log/domain/session_logger.dart';
import 'package:sshetu/features/session_log/session_log_controller.dart';
import 'package:sshetu/features/session_log/session_log_settings.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';

import '../sessions/reconnect_triggers_test.dart' show FakeTriggers;
import '../support/fake_shell.dart';
import '../support/fake_timers.dart';
import 'fake_log_sink.dart';

/// A log following its tab: started, fed, marked at a drop and a return,
/// finished on stop, on tab close and on app exit — and started by itself
/// when "always log" is on.
void main() {
  late ProviderContainer container;
  late Map<String, FakeLogSink> sinks;
  late FakeTimers timers;
  late SessionLogController controller;
  late SessionManager manager;

  Future<void> setUpContainer({
    Map<String, Object> prefs = const {},
    bool appFolder = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    final triggers = FakeTriggers();
    sinks = {};
    timers = FakeTimers();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(triggers),
        sessionLogUsesAppFolderProvider.overrideWithValue(appFolder),
        sessionLogAppFolderProvider.overrideWithValue(
          () async => '/app/session-logs',
        ),
        sessionLogSinkFactoryProvider.overrideWithValue(
          (path) async => sinks[path] = FakeLogSink(path),
        ),
        sessionLoggerFactoryProvider.overrideWithValue(
          ({required encoder, required sink, onWarn, onError}) => SessionLogger(
            encoder: encoder,
            sink: sink,
            onWarn: onWarn,
            onError: onError,
            timer: (_, _) => timers.create(const Duration(days: 1), () {}),
          ),
        ),
      ],
    );
    addTearDown(triggers.dispose);
    // Keeps it alive, as the tab strip does in the app.
    container.listen(sessionLogControllerProvider, (_, _) {});
    controller = container.read(sessionLogControllerProvider.notifier);
    manager = container.read(sessionManagerProvider.notifier);
  }

  late FakeLauncher launcher;

  Future<TerminalSession> openTab(String id) async {
    launcher = FakeLauncher();
    final session = TerminalSession(
      id: id,
      title: 'web-1',
      hostId: 'h',
      connection: SshConnection(
        target: const SshTarget(hostname: 'web.example', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: () async => true,
      reconnectTimer: timers.create,
      clock: timers.now,
    );
    manager.adopt(session);
    await session.start();
    await pumpEventQueue();
    return session;
  }

  tearDown(() => container.dispose());

  test('start, output, a drop and a return, stop', () async {
    await setUpContainer();
    final session = await openTab('a');
    await controller.start(session, SessionLogFormat.plain, '/logs/a.log');
    expect(controller.isLogging('a'), isTrue);
    expect(
      container.read(sessionLogControllerProvider)['a']?.fileName,
      'a.log',
    );

    launcher.shells.last.emit('\x1b[32mhello\x1b[0m\r\n');
    await pumpEventQueue();

    launcher.shells.last.drop();
    await pumpEventQueue();
    timers.elapse(const Duration(seconds: 2));
    await pumpEventQueue();
    expect(session.isLive, isTrue, reason: 'reconnected');
    launcher.shells.last.emit('back again\r\n');
    await pumpEventQueue();

    final log = await controller.stop('a');
    expect(log?.path, '/logs/a.log');
    expect(controller.isLogging('a'), isFalse);
    expect(container.read(sessionLogControllerProvider), isEmpty);

    final sink = sinks['/logs/a.log']!;
    expect(sink.closed, isTrue);
    final lines = sink.text.split('\n');
    expect(lines.first, startsWith('# me@web.example'));
    final body = lines.skip(1).join('\n');
    expect(
      body,
      matches(
        RegExp(
          r'^hello\n# connection lost — .+\n# reconnected — .+\n'
          r'back again\n# logging stopped — .+\n$',
        ),
      ),
    );
  });

  test('logging survives the reconnect: one file, still open', () async {
    await setUpContainer();
    final session = await openTab('a');
    await controller.start(session, SessionLogFormat.raw, '/logs/a.log');
    launcher.shells.last.drop();
    await pumpEventQueue();
    timers.elapse(const Duration(seconds: 2));
    await pumpEventQueue();
    expect(sinks, hasLength(1));
    expect(sinks.values.single.closed, isFalse);
    expect(controller.isLogging('a'), isTrue);
    await controller.stop('a');
  });

  test('closing the tab finishes its log', () async {
    await setUpContainer();
    final session = await openTab('a');
    await controller.start(session, SessionLogFormat.plain, '/logs/a.log');
    manager.close('a');
    await pumpEventQueue();
    final sink = sinks['/logs/a.log']!;
    expect(sink.closed, isTrue);
    expect(sink.text, contains('# tab closed'));
    expect(container.read(sessionLogControllerProvider), isEmpty);
  });

  test('the app going away closes every log', () async {
    await setUpContainer();
    final session = await openTab('a');
    await controller.start(session, SessionLogFormat.plain, '/logs/a.log');
    launcher.shells.last.emit('unsaved\r\n');
    await pumpEventQueue();
    container.dispose();
    await pumpEventQueue();
    final sink = sinks['/logs/a.log']!;
    expect(sink.closed, isTrue);
    expect(sink.text, contains('unsaved\n'));
    expect(sink.text, contains('# logging stopped'));
    // tearDown disposes again; that is harmless.
  });

  test('starting twice does not open a second file', () async {
    await setUpContainer();
    final session = await openTab('a');
    await Future.wait([
      controller.start(session, SessionLogFormat.plain, '/logs/1.log'),
      controller.start(session, SessionLogFormat.plain, '/logs/2.log'),
    ]);
    expect(sinks.keys, ['/logs/1.log']);
    await controller.stop('a');
  });

  group('always log new sessions', () {
    test('off by default: a new tab is not logged', () async {
      await setUpContainer(appFolder: true);
      expect(container.read(sessionLogSettingsProvider).alwaysLog, isFalse);
      await openTab('a');
      await pumpEventQueue();
      expect(controller.isLogging('a'), isFalse);
      expect(sinks, isEmpty);
    });

    test('on a phone: new tabs log into the app folder', () async {
      await setUpContainer(appFolder: true);
      await container
          .read(sessionLogSettingsProvider.notifier)
          .setAlwaysLog(true);
      await container
          .read(sessionLogSettingsProvider.notifier)
          .setFormat(SessionLogFormat.asciicast);
      await openTab('a');
      await pumpEventQueue();
      expect(controller.isLogging('a'), isTrue);
      final path = sinks.keys.single;
      expect(path, startsWith('/app/session-logs'));
      expect(path, matches(RegExp(r'web-1-\d{8}-\d{6}\.cast$')));
      await controller.stop('a');
    });

    test(
      'on a desktop: nothing without a folder, the folder with one',
      () async {
        await setUpContainer(prefs: {'sessionLog.alwaysLog': true});
        await openTab('a');
        await pumpEventQueue();
        expect(controller.isLogging('a'), isFalse, reason: 'nowhere to write');

        await container
            .read(sessionLogSettingsProvider.notifier)
            .setFolder('/home/me/logs');
        await openTab('b');
        await pumpEventQueue();
        expect(controller.isLogging('b'), isTrue);
        expect(sinks.keys.single, startsWith('/home/me/logs'));
        expect(
          controller.isLogging('a'),
          isFalse,
          reason: 'only tabs opened after',
        );
        await controller.stop('b');
      },
    );

    test('a tab the user stopped is not restarted', () async {
      await setUpContainer(appFolder: true);
      await container
          .read(sessionLogSettingsProvider.notifier)
          .setAlwaysLog(true);
      await openTab('a');
      await pumpEventQueue();
      await controller.stop('a');
      // Something else changes the list; 'a' is not new any more.
      await openTab('b');
      await pumpEventQueue();
      expect(controller.isLogging('a'), isFalse);
      expect(controller.isLogging('b'), isTrue);
      await controller.stop('b');
    });

    test('settings persist', () async {
      await setUpContainer();
      final settings = container.read(sessionLogSettingsProvider.notifier);
      await settings.setAlwaysLog(true);
      await settings.setFolder('/x');
      await settings.setFormat(SessionLogFormat.raw);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getBool('sessionLog.alwaysLog'), isTrue);
      expect(prefs.getString('sessionLog.folder'), '/x');
      expect(prefs.getString('sessionLog.format'), 'raw');
      await settings.setFolder(null);
      expect(prefs.getString('sessionLog.folder'), isNull);
      expect(container.read(sessionLogSettingsProvider).folder, isNull);
    });
  });
}
