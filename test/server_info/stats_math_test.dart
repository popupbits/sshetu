import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/server_info/domain/server_sample.dart';
import 'package:sshetu/features/server_info/domain/stats_format.dart';
import 'package:sshetu/features/server_info/domain/stats_math.dart';
import 'package:sshetu/features/server_info/domain/stats_parser.dart';

import 'fixtures.dart';

void main() {
  group('cpuPercentBetween', () {
    test('busy share of the delta', () {
      expect(
        cpuPercentBetween(
          const CpuTimes(total: 1000, idle: 800),
          const CpuTimes(total: 1500, idle: 1100),
        ),
        closeTo(40, 0.0001),
      );
    });

    test('fully idle and fully busy', () {
      expect(
        cpuPercentBetween(
          const CpuTimes(total: 0, idle: 0),
          const CpuTimes(total: 100, idle: 100),
        ),
        0,
      );
      expect(
        cpuPercentBetween(
          const CpuTimes(total: 0, idle: 0),
          const CpuTimes(total: 100, idle: 0),
        ),
        100,
      );
    });

    test('null without a previous sample, with no time passed, or after a '
        'reset', () {
      const a = CpuTimes(total: 1000, idle: 800);
      expect(cpuPercentBetween(null, a), isNull);
      expect(cpuPercentBetween(a, a), isNull);
      expect(cpuPercentBetween(a, const CpuTimes(total: 10, idle: 5)), isNull);
      expect(
        cpuPercentBetween(a, const CpuTimes(total: 1100, idle: 700)),
        isNull,
        reason: 'idle went backwards',
      );
    });
  });

  group('ratePerSecond', () {
    test('delta over seconds', () {
      expect(ratePerSecond(1000, 4000, const Duration(seconds: 3)), 1000);
      expect(
        ratePerSecond(0, 1, const Duration(milliseconds: 500)),
        closeTo(2, 0.0001),
      );
    });

    test('a wrapped or reset counter is null, not negative or huge', () {
      expect(
        ratePerSecond(4294967000, 100, const Duration(seconds: 3)),
        isNull,
      );
    });

    test('no interval is null', () {
      expect(ratePerSecond(1, 2, Duration.zero), isNull);
      expect(ratePerSecond(1, 2, null), isNull);
      expect(ratePerSecond(null, 2, const Duration(seconds: 1)), isNull);
    });
  });

  group('deriveStats', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);

    test('first sample has no deltas', () {
      final stats = deriveStats(
        current: parseStatsOutput(ubuntuStats),
        currentAt: t0,
      );
      expect(stats.cpuPercent, isNull);
      expect(stats.rxBytesPerSecond, isNull);
    });

    test('Ubuntu, three seconds apart by the server uptime clock', () {
      // The local clock says ten seconds (a slow poll); the server's own
      // uptime says three, and it is the one that measured the counters.
      final stats = deriveStats(
        previous: parseStatsOutput(ubuntuStats),
        previousAt: t0,
        current: parseStatsOutput(ubuntuStatsLater),
        currentAt: t0.add(const Duration(seconds: 10)),
      );
      expect(stats.cpuPercent, closeTo(40, 0.0001));
      expect(stats.rxBytesPerSecond, closeTo(100000, 0.001));
      expect(stats.txBytesPerSecond, closeTo(10000, 0.001));
    });

    test('falls back to the local clock without uptime', () {
      const a = ServerSample(net: NetCounters(rxBytes: 0, txBytes: 0));
      const b = ServerSample(net: NetCounters(rxBytes: 2000, txBytes: 500));
      final stats = deriveStats(
        previous: a,
        previousAt: t0,
        current: b,
        currentAt: t0.add(const Duration(seconds: 2)),
      );
      expect(stats.rxBytesPerSecond, 1000);
      expect(stats.txBytesPerSecond, 250);
    });

    test('a reboot between polls (uptime went down) uses the local clock', () {
      final elapsed = elapsedBetween(
        previous: const ServerSample(uptime: Duration(hours: 5)),
        current: const ServerSample(uptime: Duration(seconds: 20)),
        previousAt: t0,
        currentAt: t0.add(const Duration(seconds: 3)),
      );
      expect(elapsed, const Duration(seconds: 3));
    });
  });

  group('format', () {
    test('rates', () {
      expect(formatRate(null), '—');
      expect(formatRate(0), '0 B/s');
      expect(formatRate(1536), '1.5 KB/s');
      expect(formatRate(100000), '98 KB/s');
    });

    test('uptime', () {
      expect(formatUptime(const Duration(minutes: 5)), '5m');
      expect(formatUptime(const Duration(hours: 3, minutes: 12)), '3h 12m');
      expect(formatUptime(const Duration(days: 12, hours: 4)), '12d 4h');
      expect(formatUptime(null), '—');
    });

    test('percent', () {
      expect(formatPercent(4.25), '4.3%');
      expect(formatPercent(42.4), '42%');
      expect(formatPercent(null), '—');
    });
  });
}
