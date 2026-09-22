import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/server_info/server_stats_monitor.dart';

import 'fake_server_exec.dart';
import 'fixtures.dart';

void main() {
  test('one exec per poll, the script on stdin to sh', () async {
    final exec = FakeServerExec(
      (_, _) => const ExecResult(stdout: ubuntuStats, exitCode: 0),
    );
    final monitor = ServerStatsMonitor(exec);
    addTearDown(monitor.dispose);
    await monitor.poll();
    expect(exec.calls, hasLength(1));
    expect(exec.calls.single.command, 'sh -s');
    expect(exec.calls.single.stdin, contains('/proc/stat'));
    expect(monitor.status, MonitorStatus.ready);
    expect(monitor.stats!.sample.identity.hostname, 'web-1');
    expect(monitor.stats!.cpuPercent, isNull);
    expect(monitor.cpuHistory, isEmpty);
  });

  test('second poll yields CPU % and rates, and history grows', () async {
    final outputs = [ubuntuStats, ubuntuStatsLater];
    final exec = FakeServerExec(
      (_, _) => ExecResult(stdout: outputs.removeAt(0), exitCode: 0),
    );
    final monitor = ServerStatsMonitor(exec);
    addTearDown(monitor.dispose);
    await monitor.poll();
    await monitor.poll();
    expect(monitor.stats!.cpuPercent, closeTo(40, 0.001));
    expect(monitor.stats!.rxBytesPerSecond, closeTo(100000, 0.01));
    expect(monitor.cpuHistory, [closeTo(40, 0.001)]);
  });

  test('history is capped', () async {
    var tick = 0;
    final exec = FakeServerExec((_, _) {
      tick++;
      // Each poll: 100 more jiffies, 50 of them idle -> 50%.
      return ExecResult(
        stdout:
            '@@sshetu:stat\ncpu ${tick * 50} 0 0 ${tick * 50}\n@@sshetu:end\n',
      );
    });
    final monitor = ServerStatsMonitor(exec, historyLength: 5);
    addTearDown(monitor.dispose);
    for (var i = 0; i < 9; i++) {
      await monitor.poll();
    }
    expect(monitor.cpuHistory, hasLength(5));
    expect(monitor.cpuHistory.every((v) => v == 50), isTrue);
  });

  test('offline: no exec, figures kept, status says so', () async {
    final exec = FakeServerExec(
      (_, _) => const ExecResult(stdout: ubuntuStats, exitCode: 0),
    );
    final monitor = ServerStatsMonitor(exec);
    addTearDown(monitor.dispose);
    await monitor.poll();
    exec.connected = false;
    await monitor.poll();
    expect(exec.calls, hasLength(1));
    expect(monitor.status, MonitorStatus.offline);
    expect(monitor.stats, isNotNull);
  });

  test('a failing poll is an error with the last figures kept', () async {
    var fail = false;
    final exec = FakeServerExec((_, _) {
      if (fail) throw StateError('channel refused');
      return const ExecResult(stdout: ubuntuStats, exitCode: 0);
    });
    final monitor = ServerStatsMonitor(exec);
    addTearDown(monitor.dispose);
    await monitor.poll();
    fail = true;
    await monitor.poll();
    expect(monitor.status, MonitorStatus.error);
    expect(monitor.error, isA<StateError>());
    expect(monitor.stats, isNotNull);
  });

  testWidgets('polls every interval while started, not after stop', (
    tester,
  ) async {
    final exec = FakeServerExec(
      (_, _) => const ExecResult(stdout: ubuntuStats, exitCode: 0),
    );
    final monitor = ServerStatsMonitor(exec);
    monitor.start();
    await tester.pump();
    expect(exec.calls, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(exec.calls, hasLength(3));
    monitor.stop();
    await tester.pump(const Duration(seconds: 30));
    expect(exec.calls, hasLength(3));
    monitor.dispose();
  });
}
