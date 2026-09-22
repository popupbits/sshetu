import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/tunnel_runner.dart';
import 'package:sshetu/features/tunnels/domain/far_end.dart';
import 'package:sshetu/features/tunnels/far_end_monitor.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';

/// A channel that records being hung up on.
class _FakeChannel implements SSHSocket {
  bool destroyed = false;
  final _done = Completer<void>();

  @override
  Stream<Uint8List> get stream => const Stream.empty();

  @override
  StreamSink<List<int>> get sink => StreamController<List<int>>();

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async => destroy();

  @override
  void destroy() {
    destroyed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> flush() async {}
}

/// A manager whose forwards are "running" without any SSH underneath, and
/// whose far-end checks answer from a table.
class _FakeManager extends TunnelRunnerManager {
  _FakeManager(this.initial, this.answers);

  final Map<String, TunnelRunnerStatus> initial;
  final Map<String, FarEndStatus?> answers;
  final List<String> probed = [];

  @override
  Map<String, TunnelRunnerStatus> build() => initial;

  @override
  Future<FarEndStatus?> probeTarget(String tunnelId) async {
    probed.add(tunnelId);
    return answers[tunnelId];
  }

  void set(Map<String, TunnelRunnerStatus> next) => state = next;
}

const _running = TunnelRunnerStatus(
  state: TunnelRunState.running,
  connections: 2,
  boundPort: 8080,
);

void main() {
  group('probeFarEnd', () {
    test(
      'a channel that opens means listening, and is closed at once',
      () async {
        final channel = _FakeChannel();
        final result = await probeFarEnd(() async => channel);
        expect(result, FarEndStatus.listening);
        expect(channel.destroyed, isTrue);
      },
    );

    test('connect failed (2) means nothing is listening', () async {
      final result = await probeFarEnd(
        () async => throw SSHChannelOpenError(2, 'Connection refused'),
      );
      expect(result, FarEndStatus.notListening);
    });

    test('administratively prohibited (1) is not a verdict', () async {
      final result = await probeFarEnd(
        () async => throw SSHChannelOpenError(1, 'open failed'),
      );
      expect(result, FarEndStatus.unknown);
    });

    test('a timeout is unknown, and a late channel is still closed', () async {
      final late = Completer<SSHSocket>();
      final channel = _FakeChannel();
      final result = await probeFarEnd(
        () => late.future,
        timeout: const Duration(milliseconds: 10),
      );
      expect(result, FarEndStatus.unknown);
      late.complete(channel);
      await Future<void>.delayed(Duration.zero);
      expect(channel.destroyed, isTrue);
    });

    test('any other failure is unknown', () async {
      expect(
        await probeFarEnd(() async => throw StateError('closed')),
        FarEndStatus.unknown,
      );
    });
  });

  group('FarEndMonitor', () {
    ProviderContainer containerWith(_FakeManager manager) {
      final container = ProviderContainer(
        overrides: [tunnelRunnersProvider.overrideWith(() => manager)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('checks nothing until watched, then every running forward', () async {
      final manager = _FakeManager(
        {
          'up': _running,
          'down': _running,
          'stopped': const TunnelRunnerStatus.stopped(),
        },
        {'up': FarEndStatus.listening, 'down': FarEndStatus.notListening},
      );
      final container = containerWith(manager);
      final monitor = container.read(farEndMonitorProvider.notifier);
      expect(container.read(farEndMonitorProvider), isEmpty);
      expect(manager.probed, isEmpty);

      monitor.watch();
      await monitor.check();
      expect(container.read(farEndMonitorProvider), {
        'up': FarEndStatus.listening,
        'down': FarEndStatus.notListening,
      });
      expect(manager.probed, isNot(contains('stopped')));
      monitor.unwatch();
      expect(monitor.isWatching, isFalse);
    });

    test('a check never touches the forward\'s connection count', () async {
      final manager = _FakeManager(
        {'up': _running},
        {'up': FarEndStatus.listening},
      );
      final container = containerWith(manager);
      final monitor = container.read(farEndMonitorProvider.notifier)..watch();
      await monitor.check();
      expect(container.read(tunnelRunnersProvider)['up'], _running);
      expect(container.read(tunnelRunnersProvider)['up']!.connections, 2);
      monitor.unwatch();
    });

    test('a forward that stops loses its far-end status', () async {
      final manager = _FakeManager(
        {'up': _running},
        {'up': FarEndStatus.listening},
      );
      final container = containerWith(manager);
      final monitor = container.read(farEndMonitorProvider.notifier)..watch();
      await monitor.check();
      expect(container.read(farEndMonitorProvider), contains('up'));

      manager.set({'up': const TunnelRunnerStatus.stopped()});
      expect(container.read(farEndMonitorProvider), isEmpty);
      monitor.unwatch();
    });

    test('a forward that starts while watched is checked right away', () async {
      final manager = _FakeManager(
        {'new': const TunnelRunnerStatus.stopped()},
        {'new': FarEndStatus.listening},
      );
      final container = containerWith(manager);
      final monitor = container.read(farEndMonitorProvider.notifier)..watch();
      await monitor.check();
      manager.probed.clear();

      manager.set({'new': _running});
      await Future<void>.delayed(Duration.zero);
      expect(manager.probed, ['new']);
      expect(
        container.read(farEndMonitorProvider)['new'],
        FarEndStatus.listening,
      );
      monitor.unwatch();
    });

    test('visibleFarEnd shows only definite answers for running forwards', () {
      expect(
        visibleFarEnd(_running, FarEndStatus.listening),
        FarEndStatus.listening,
      );
      expect(visibleFarEnd(_running, FarEndStatus.unknown), isNull);
      expect(visibleFarEnd(_running, null), isNull);
      expect(
        visibleFarEnd(
          const TunnelRunnerStatus.stopped(),
          FarEndStatus.notListening,
        ),
        isNull,
      );
    });
  });
}
