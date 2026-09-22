import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/reconnect_loop.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';

import '../support/fake_shell.dart';
import '../support/fake_timers.dart';

/// The app returning to the foreground, or the network coming back, reaches
/// every open tab through the session list.
void main() {
  late FakeTriggers triggers;
  late ProviderContainer container;
  late FakeTimers timers;

  setUp(() {
    triggers = FakeTriggers();
    timers = FakeTimers();
    container = ProviderContainer(
      overrides: [reconnectTriggersProvider.overrideWithValue(triggers)],
    );
    addTearDown(container.dispose);
    addTearDown(triggers.dispose);
  });

  TerminalSession tab(FakeLauncher launcher, {Future<bool> Function()? probe}) {
    return TerminalSession(
      id: 'host-${launcher.hashCode}',
      title: 'test',
      hostId: 'host',
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
      launcher: launcher,
      probe: probe ?? () async => true,
      reconnectTimer: timers.create,
      clock: timers.now,
    );
  }

  test('listens only while a tab is open', () async {
    final manager = container.read(sessionManagerProvider.notifier);
    expect(triggers.hasListener, isFalse);

    final session = tab(FakeLauncher());
    manager.adopt(session);
    expect(triggers.hasListener, isTrue);

    manager.close(session.id);
    await pumpEventQueue();
    expect(triggers.hasListener, isFalse);
  });

  for (final trigger in ReconnectTrigger.values) {
    test('$trigger retries a waiting tab now and probes a live one', () async {
      final manager = container.read(sessionManagerProvider.notifier);

      final droppedLauncher = FakeLauncher();
      final dropped = tab(droppedLauncher);
      var probes = 0;
      final live = tab(
        FakeLauncher(),
        probe: () async {
          probes++;
          return true;
        },
      );
      manager
        ..adopt(dropped)
        ..adopt(live);
      await dropped.start();
      await live.start();

      droppedLauncher.shells.single.drop();
      await pumpEventQueue();
      expect(dropped.reconnect.phase, ReconnectPhase.waiting);

      triggers.fire(trigger);
      await pumpEventQueue();

      expect(droppedLauncher.opens, 2, reason: 'no waiting out the timer');
      expect(dropped.status, TerminalSessionStatus.running);
      expect(probes, 1);
    });
  }
}

class FakeTriggers extends ReconnectTriggers {
  final _controller = StreamController<ReconnectTrigger>.broadcast();

  bool get hasListener => _controller.hasListener;

  void fire(ReconnectTrigger trigger) => _controller.add(trigger);

  @override
  Stream<ReconnectTrigger> get events => _controller.stream;

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }
}
