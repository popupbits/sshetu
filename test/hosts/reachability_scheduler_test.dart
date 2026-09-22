import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/data/reachability_probe.dart';
import 'package:sshetu/features/hosts/data/reachability_scheduler.dart';
import 'package:sshetu/features/hosts/domain/reachability.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';

import '../support/fake_reachability.dart';
import '../support/fake_timers.dart';

void main() {
  late FakeTimers timers;
  late FakeProbe probe;
  late ReachabilityScheduler scheduler;
  late int changes;

  const up = ProbeOutcome.up(Duration(milliseconds: 23));

  ReachabilityScheduler build({Random? random, int maxConcurrent = 4}) {
    changes = 0;
    return ReachabilityScheduler(
      probe: probe,
      onChanged: () => changes++,
      timer: timers.create,
      now: timers.now,
      random: random ?? FixedRandom(0.5),
      maxConcurrent: maxConcurrent,
    );
  }

  List<ProbeAddress> addresses(int n) => [
    for (var i = 0; i < n; i++) ProbeAddress('10.0.0.$i', 22),
  ];

  setUp(() {
    timers = FakeTimers();
    probe = FakeProbe();
    scheduler = build();
  });

  tearDown(() => scheduler.dispose());

  group('deduplication', () {
    final now = DateTime.utc(2026);
    SshHost host(String id, String hostname, {int port = 22, String? jump}) =>
        SshHost(
          id: id,
          label: id,
          hostname: hostname,
          port: port,
          username: id,
          jumpHostId: jump,
          createdAt: now,
          updatedAt: now,
        );

    test('several hosts on one address are one probe', () async {
      final targets = probeTargets([
        host('a', 'box.example.com'),
        host('b', 'BOX.example.com'),
        host('c', 'box.example.com '),
        host('d', 'box.example.com', port: 2222),
      ]);
      expect(targets, hasLength(2));

      probe.autoReply = up;
      scheduler
        ..setTargets(targets)
        ..setInterval(const Duration(minutes: 1))
        ..setActive(true);
      timers.elapse(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(probe.calls.map((a) => a.key), [
        'box.example.com:22',
        'box.example.com:2222',
      ]);
    });

    test('hosts behind a jump host are never probed', () {
      final targets = probeTargets([
        host('bastion', 'bastion.example.com'),
        host('inner', '10.1.0.5', jump: 'bastion'),
      ]);
      expect(targets.map((t) => t.key), ['bastion.example.com:22']);
    });

    test('an address a live session proves is not probed', () {
      final targets = probeTargets(
        [host('a', 'box'), host('b', 'box'), host('c', 'other')],
        connectedHostIds: {'a'},
      );
      expect(targets.map((t) => t.key), ['other:22']);
    });
  });

  group('jitter', () {
    test('stays within ±20% at both extremes', () {
      final random = FixedRandom(0);
      final s = build(random: random);
      const period = Duration(minutes: 1);
      expect(s.jittered(period), const Duration(seconds: 48));
      random.value = 0.999999;
      expect(s.jittered(period).inMilliseconds, inInclusiveRange(71999, 72000));
      s.dispose();
    });

    test('a thousand real draws all land in bounds', () {
      final s = build(random: Random(7));
      const period = Duration(seconds: 60);
      final draws = [for (var i = 0; i < 1000; i++) s.jittered(period)];
      for (final d in draws) {
        expect(d.inMilliseconds, inInclusiveRange(48000, 72000));
      }
      // And it actually moves: not every draw the same.
      expect(draws.toSet().length, greaterThan(900));
      s.dispose();
    });

    test('the next probe comes within the jittered window', () async {
      final random = FixedRandom(0);
      scheduler.dispose();
      scheduler = build(random: random);
      probe.autoReply = up;
      scheduler
        ..setTargets(addresses(1))
        ..setInterval(const Duration(minutes: 1))
        ..setActive(true);
      timers.elapse(Duration.zero);
      await pumpEventQueue();
      expect(probe.calls, hasLength(1));

      // −20%: due at 48 s, not before.
      timers.elapse(const Duration(seconds: 47));
      await pumpEventQueue();
      expect(probe.calls, hasLength(1));
      timers.elapse(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(probe.calls, hasLength(2));
    });
  });

  test('never more than the cap in flight, and the rest follow', () async {
    scheduler
      ..setTargets(addresses(10))
      ..setInterval(const Duration(minutes: 1))
      ..setActive(true);
    timers.elapse(const Duration(seconds: 10));
    await pumpEventQueue();
    expect(probe.calls, hasLength(4));
    expect(scheduler.inFlight, 4);

    probe.settleNext(up);
    await pumpEventQueue();
    expect(probe.calls, hasLength(5));
    expect(scheduler.inFlight, 4);

    while (probe.pending > 0) {
      probe.settleNext(up);
      await pumpEventQueue();
      expect(scheduler.inFlight, lessThanOrEqualTo(4));
    }
    expect(probe.calls.map((a) => a.key).toSet(), hasLength(10));
    expect(scheduler.results, hasLength(10));
  });

  test('the first round is staggered, not a burst', () {
    scheduler.dispose();
    scheduler = build(maxConcurrent: 100);
    scheduler
      ..setTargets(addresses(4))
      ..setInterval(const Duration(minutes: 1))
      ..setActive(true);
    timers.elapse(Duration.zero);
    expect(probe.calls, hasLength(1));
    timers.elapse(const Duration(milliseconds: 250));
    expect(probe.calls, hasLength(2));
    timers.elapse(const Duration(milliseconds: 500));
    expect(probe.calls, hasLength(4));
  });

  test('an interval under 30 s is raised to 30 s', () async {
    probe.autoReply = up;
    scheduler.dispose();
    scheduler = build(random: FixedRandom(0));
    scheduler
      ..setTargets(addresses(1))
      ..setInterval(const Duration(seconds: 5))
      ..setActive(true);
    timers.elapse(Duration.zero);
    await pumpEventQueue();
    // 30 s − 20% = 24 s is the soonest a second probe may come.
    timers.elapse(const Duration(seconds: 23));
    await pumpEventQueue();
    expect(probe.calls, hasLength(1));
    timers.elapse(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(probe.calls, hasLength(2));
  });

  test('nothing is probed while inactive, and no timer waits', () async {
    probe.autoReply = up;
    scheduler
      ..setTargets(addresses(3))
      ..setInterval(const Duration(seconds: 30));
    timers.elapse(const Duration(minutes: 10));
    expect(probe.calls, isEmpty);
    expect(timers.pending, 0);
  });

  test('pausing stops probing; resuming probes only what is stale', () async {
    probe.autoReply = up;
    scheduler
      ..setTargets(addresses(2))
      ..setInterval(const Duration(minutes: 5))
      ..setActive(true);
    timers.elapse(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(probe.calls, hasLength(2));

    scheduler.setActive(false);
    expect(timers.pending, 0);
    timers.elapse(const Duration(minutes: 1));

    // Back within the interval: both results are fresh, so nothing runs.
    scheduler.setActive(true);
    timers.elapse(const Duration(seconds: 5));
    await pumpEventQueue();
    expect(probe.calls, hasLength(2));

    scheduler.setActive(false);
    timers.elapse(const Duration(minutes: 30));
    expect(probe.calls, hasLength(2));

    // Back after it: both are stale and probed straight away.
    scheduler.setActive(true);
    timers.elapse(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(probe.calls, hasLength(4));
  });

  test('off stops everything', () async {
    probe.autoReply = up;
    scheduler
      ..setTargets(addresses(2))
      ..setInterval(null)
      ..setActive(true);
    timers.elapse(const Duration(minutes: 10));
    expect(probe.calls, isEmpty);
    expect(timers.pending, 0);
  });

  test('a probe that throws is recorded as down', () async {
    final throwing = _ThrowingProbe();
    final s = ReachabilityScheduler(
      probe: throwing,
      onChanged: () {},
      timer: timers.create,
      now: timers.now,
    );
    s
      ..setTargets(addresses(1))
      ..setInterval(const Duration(minutes: 1))
      ..setActive(true);
    timers.elapse(Duration.zero);
    await pumpEventQueue();
    expect(
      s.results.values.single.outcome,
      const ProbeOutcome.down(ReachabilityFailure.unreachable),
    );
    s.dispose();
  });

  test('results are stamped with the clock and reported', () async {
    probe.autoReply = const ProbeOutcome.down(ReachabilityFailure.timedOut);
    scheduler
      ..setTargets(addresses(1))
      ..setInterval(const Duration(minutes: 1))
      ..setActive(true);
    timers.elapse(Duration.zero);
    await pumpEventQueue();
    final result = scheduler.results['10.0.0.0:22']!;
    expect(result.outcome.failure, ReachabilityFailure.timedOut);
    expect(result.checkedAt, timers.start);
    expect(changes, 1);
  });

  test('a removed address is forgotten', () async {
    probe.autoReply = up;
    scheduler
      ..setTargets(addresses(2))
      ..setInterval(const Duration(minutes: 1))
      ..setActive(true);
    timers.elapse(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(scheduler.results, hasLength(2));

    scheduler.setTargets(addresses(1));
    await pumpEventQueue();
    expect(scheduler.results.keys, ['10.0.0.0:22']);
  });
}

class _ThrowingProbe implements ReachabilityProbe {
  @override
  Future<ProbeOutcome> probe(ProbeAddress address) async =>
      throw StateError('boom');
}
