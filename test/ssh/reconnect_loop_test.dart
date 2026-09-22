import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/reconnect_loop.dart';
import 'package:sshetu/core/ssh/reconnect_policy.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';

import '../support/fake_timers.dart';

/// The retry loop, driven by a hand-cranked clock.
void main() {
  late FakeTimers timers;
  late List<Completer<void>> attempts;
  late List<Object> gaveUp;
  late ReconnectLoop loop;

  setUp(() {
    timers = FakeTimers();
    attempts = [];
    gaveUp = [];
    loop = ReconnectLoop(
      attempt: () {
        final attempt = Completer<void>();
        attempts.add(attempt);
        return attempt.future;
      },
      clock: timers.now,
      timer: timers.create,
      onGaveUp: gaveUp.add,
    );
  });

  final networkError = SshConnectionException(
    'Cannot reach host:22',
    cause: const SocketException('unreachable'),
    retryable: true,
  );

  test('a network drop waits 1.5 s, then tries', () async {
    expect(loop.dropped(DisconnectReason.network), isTrue);
    expect(loop.phase, ReconnectPhase.waiting);
    expect(
      loop.nextAttemptAt,
      timers.now().add(const Duration(milliseconds: 1500)),
    );

    timers.elapse(const Duration(milliseconds: 1499));
    expect(attempts, isEmpty);
    timers.elapse(const Duration(milliseconds: 1));
    expect(attempts, hasLength(1));
    expect(loop.phase, ReconnectPhase.connecting);

    attempts.single.complete();
    await pumpEventQueue();
    expect(loop.phase, ReconnectPhase.idle);
    expect(loop.attemptsMade, 0);
  });

  test('each failure backs off along the schedule', () async {
    loop.dropped(DisconnectReason.network);
    final waits = <Duration>[];
    for (var i = 0; i < 5; i++) {
      final wait = loop.nextAttemptAt!.difference(timers.now());
      waits.add(wait);
      timers.elapse(wait);
      attempts.last.completeError(networkError);
      await pumpEventQueue();
      expect(loop.phase, ReconnectPhase.waiting);
      expect(loop.attemptsMade, i + 1);
    }
    expect(waits, const [
      Duration(milliseconds: 1500),
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 8),
      Duration(seconds: 10),
    ]);
  });

  test('retryNow skips the rest of the wait', () async {
    loop.dropped(DisconnectReason.network);
    loop.retryNow();
    expect(attempts, hasLength(1));
    // The cancelled timer must not start a second attempt.
    timers.elapse(const Duration(seconds: 5));
    expect(attempts, hasLength(1));
  });

  test('retryNow does nothing while connected or already trying', () {
    loop.retryNow();
    expect(attempts, isEmpty);
    loop.dropped(DisconnectReason.network);
    loop.retryNow();
    loop.retryNow();
    expect(attempts, hasLength(1));
  });

  test(
    'stop cancels the countdown and a later failure schedules nothing',
    () async {
      loop.dropped(DisconnectReason.network);
      loop.stop();
      expect(loop.phase, ReconnectPhase.idle);
      timers.elapse(const Duration(minutes: 1));
      expect(attempts, isEmpty);

      loop.dropped(DisconnectReason.network);
      loop.retryNow();
      loop.stop();
      attempts.single.completeError(networkError);
      await pumpEventQueue();
      expect(loop.phase, ReconnectPhase.idle);
      expect(timers.pending, 0);
    },
  );

  test('an auth failure while reconnecting gives up and says why', () async {
    loop.dropped(DisconnectReason.network);
    loop.retryNow();
    final rejected = SshConnectionException(
      'Authentication was rejected.',
      cause: SSHAuthFailError('denied'),
    );
    attempts.single.completeError(rejected);
    await pumpEventQueue();
    expect(loop.phase, ReconnectPhase.idle);
    expect(gaveUp, [rejected]);
    expect(timers.pending, 0);
  });

  for (final reason in [
    DisconnectReason.userInitiated,
    DisconnectReason.remoteExited,
    DisconnectReason.authenticationFailed,
    DisconnectReason.hostKeyRejected,
  ]) {
    test('$reason does not start a reconnect', () {
      expect(loop.dropped(reason), isFalse);
      expect(loop.phase, ReconnectPhase.idle);
      expect(timers.pending, 0);
    });
  }

  test('after three minutes of trying it settles on every 30 s', () async {
    loop.dropped(DisconnectReason.network);
    while (timers.now().difference(timers.start) < const Duration(minutes: 3)) {
      timers.elapse(loop.nextAttemptAt!.difference(timers.now()));
      attempts.last.completeError(networkError);
      await pumpEventQueue();
    }
    expect(
      loop.nextAttemptAt!.difference(timers.now()),
      const Duration(seconds: 30),
    );
  });
}
