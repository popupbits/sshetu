import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/background/keep_alive_platform.dart';
import 'package:sshetu/core/background/keep_alive_service.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/l10n/app_localizations_en.dart';

/// Records every call the controller makes to the native service.
class FakeKeepAlivePlatform implements KeepAlivePlatform {
  final calls = <String>[];
  final notices = <KeepAliveNotice>[];
  Future<void> Function()? handler;
  bool failStart = false;

  @override
  Future<void> start(KeepAliveNotice notice) async {
    if (failStart) throw PlatformException(code: 'keep_alive');
    calls.add('start');
    notices.add(notice);
  }

  @override
  Future<void> update(KeepAliveNotice notice) async {
    calls.add('update');
    notices.add(notice);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> requestNotificationPermission() async => calls.add('permission');

  @override
  set onDisconnectAll(Future<void> Function()? value) => handler = value;
}

/// Counts a test can change, standing in for the session and tunnel lists.
class FakeCounts extends Notifier<KeepAliveCounts> {
  @override
  KeepAliveCounts build() => const KeepAliveCounts(sessions: 0, tunnels: 0);

  void set(int sessions, int tunnels) =>
      state = KeepAliveCounts(sessions: sessions, tunnels: tunnels);
}

final fakeCountsProvider = NotifierProvider<FakeCounts, KeepAliveCounts>(
  FakeCounts.new,
);

KeepAliveCounts counts(int sessions, int tunnels) =>
    KeepAliveCounts(sessions: sessions, tunnels: tunnels);

void main() {
  final l10n = AppLocalizationsEn();

  group('notice text', () {
    test('names both sessions and tunnels', () {
      expect(
        keepAliveNoticeFor(l10n, counts(2, 1)).text,
        '2 sessions, 1 tunnel active',
      );
    });

    test('names only what is open', () {
      expect(keepAliveNoticeFor(l10n, counts(1, 0)).text, '1 session active');
      expect(keepAliveNoticeFor(l10n, counts(0, 3)).text, '3 tunnels active');
    });

    test('carries the channel name and action label', () {
      final notice = keepAliveNoticeFor(l10n, counts(1, 0));
      expect(notice.channelName, 'Active connections');
      expect(notice.disconnectAllLabel, 'Disconnect all');
    });
  });

  group('KeepAliveController', () {
    late FakeKeepAlivePlatform platform;
    var disconnects = 0;

    KeepAliveController controller({bool supported = true}) =>
        KeepAliveController(
          platform: platform,
          supported: supported,
          noticeFor: (c) => keepAliveNoticeFor(l10n, c),
          onDisconnectAll: () async => disconnects++,
        );

    setUp(() {
      platform = FakeKeepAlivePlatform();
      disconnects = 0;
    });

    test(
      'starts at the first session, without asking for notifications',
      () async {
        final c = controller();
        await c.sync(counts(0, 0), enabled: true);
        expect(platform.calls, isEmpty);

        await c.sync(counts(1, 0), enabled: true);
        expect(platform.calls, ['start']);
        expect(platform.notices.single.text, '1 session active');
        expect(c.isRunning, isTrue);
      },
    );

    test('updates the text when the counts change, and only then', () async {
      final c = controller();
      await c.sync(counts(1, 0), enabled: true);
      await c.sync(counts(2, 1), enabled: true);
      await c.sync(counts(2, 1), enabled: true);

      expect(platform.calls, ['start', 'update']);
      expect(platform.notices.last.text, '2 sessions, 1 tunnel active');
    });

    test('stops at zero, and starts again at the next connection', () async {
      final c = controller();
      await c.sync(counts(1, 0), enabled: true);
      await c.sync(counts(0, 0), enabled: true);
      expect(platform.calls.last, 'stop');
      expect(c.isRunning, isFalse);

      await c.sync(counts(0, 1), enabled: true);
      expect(platform.calls, ['start', 'stop', 'start']);
    });

    test('does nothing while disabled, and turning it off stops it', () async {
      final c = controller();
      await c.sync(counts(2, 0), enabled: false);
      expect(platform.calls, isEmpty);

      await c.sync(counts(2, 0), enabled: true);
      await c.sync(counts(2, 0), enabled: false);
      expect(platform.calls, ['start', 'stop']);
    });

    test('is a no-op where there is no service', () async {
      final c = controller(supported: false);
      await c.sync(counts(3, 2), enabled: true);
      await c.dispose();
      expect(platform.calls, isEmpty);
      expect(platform.handler, isNull);
    });

    test('Disconnect all reaches the callback', () async {
      controller();
      expect(platform.handler, isNotNull);
      await platform.handler!();
      expect(disconnects, 1);
    });

    test('a refused start is retried on the next change', () async {
      final c = controller();
      platform.failStart = true;
      await c.sync(counts(1, 0), enabled: true);
      expect(c.isRunning, isFalse);

      platform.failStart = false;
      await c.sync(counts(2, 0), enabled: true);
      expect(c.isRunning, isTrue);
      expect(platform.calls, ['start']);
    });

    test('asks for notifications once, and only when told to', () async {
      final c = controller();
      await c.sync(counts(1, 0), enabled: true);
      expect(platform.calls, isNot(contains('permission')));

      await c.askForNotificationsOnce();
      await c.askForNotificationsOnce();
      expect(
        platform.calls.where((call) => call == 'permission'),
        hasLength(1),
      );
    });

    test('never asks where there is no service', () async {
      await controller(supported: false).askForNotificationsOnce();
      expect(platform.calls, isEmpty);
    });

    test('dispose stops a running service and drops the handler', () async {
      final c = controller();
      await c.sync(counts(1, 0), enabled: true);
      await c.dispose();
      expect(platform.calls.last, 'stop');
      expect(platform.handler, isNull);
    });
  });

  group('keepAliveControllerProvider', () {
    late FakeKeepAlivePlatform platform;
    late ProviderContainer container;
    var disconnects = 0;

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      platform = FakeKeepAlivePlatform();
      disconnects = 0;
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          keepAlivePlatformProvider.overrideWithValue(platform),
          keepAliveSupportedProvider.overrideWithValue(true),
          keepAliveCountsProvider.overrideWith(
            (ref) => ref.watch(fakeCountsProvider),
          ),
          keepAliveDisconnectAllProvider.overrideWithValue(
            () async => disconnects++,
          ),
        ],
      );
      addTearDown(container.dispose);
      // Listened, as the app root does: Riverpod 3 pauses an unlistened
      // provider's own subscriptions.
      container.listen(keepAliveControllerProvider, (_, _) {});
    });

    test('follows the counts: start, update, stop', () async {
      container.read(fakeCountsProvider.notifier).set(1, 0);
      await settle();
      container.read(fakeCountsProvider.notifier).set(1, 1);
      await settle();
      container.read(fakeCountsProvider.notifier).set(0, 0);
      await settle();

      expect(platform.calls, ['start', 'update', 'stop']);
      expect(platform.notices.last.text, '1 session, 1 tunnel active');
    });

    test('turning the setting off stops the service', () async {
      container.read(fakeCountsProvider.notifier).set(1, 0);
      await settle();
      container
          .read(settingsControllerProvider.notifier)
          .setKeepAliveInBackground(false);
      await settle();

      expect(platform.calls, ['start', 'stop']);
      expect(container.read(keepAliveControllerProvider).isRunning, isFalse);
    });

    test('Disconnect all runs the disconnect action', () async {
      await platform.handler!();
      expect(disconnects, 1);
    });
  });

  group('MethodChannelKeepAlivePlatform', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(MethodChannelKeepAlivePlatform.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('sends each call by name, with the notice', () async {
      final received = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        received.add(call);
        return null;
      });

      final platform = MethodChannelKeepAlivePlatform();
      final notice = keepAliveNoticeFor(l10n, counts(1, 0));
      await platform.requestNotificationPermission();
      await platform.start(notice);
      await platform.update(notice);
      await platform.stop();

      expect(received.map((c) => c.method), [
        'requestNotificationPermission',
        'start',
        'update',
        'stop',
      ]);
      expect(received[1].arguments, notice.toMap());
    });

    test('a disconnectAll from Android reaches the handler', () async {
      var called = 0;
      MethodChannelKeepAlivePlatform().onDisconnectAll = () async => called++;

      await messenger.handlePlatformMessage(
        MethodChannelKeepAlivePlatform.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('disconnectAll'),
        ),
        (_) {},
      );
      expect(called, 1);

      MethodChannelKeepAlivePlatform().onDisconnectAll = null;
    });
  });
}
