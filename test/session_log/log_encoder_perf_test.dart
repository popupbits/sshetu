@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/session_log/domain/log_encoders.dart';

import '../terminal/terminal_workloads.dart';

/// What logging a session costs on top of showing it.
///
/// Every output chunk passes through the log's encoder on the UI isolate while
/// a log is running, so an encoder slower than the terminal's own ingest is
/// what a `cat` is held to. Measured on a developer machine: plain ~55–70
/// MB/s (a per-character ANSI stripper), asciicast ~50–240 MB/s, raw free.
/// The budget is an order of magnitude below that.
void main() {
  final workloads = terminalWorkloads(scale: 0.5);

  for (final make in <(String, SessionLogEncoder Function())>[
    ('plain', PlainLogEncoder.new),
    ('asciicast', AsciicastEncoder.new),
  ]) {
    test('the ${make.$1} encoder keeps up with busy output', () {
      for (final workload in workloads) {
        final total = workload.chunks.fold<int>(0, (s, c) => s + c.length);
        var best = const Duration(days: 1);
        for (var run = 0; run < 3; run++) {
          final encoder = make.$2();
          var elapsed = Duration.zero;
          final watch = Stopwatch()..start();
          for (final chunk in workload.chunks) {
            encoder.output(chunk, elapsed: elapsed, columns: 120, rows: 40);
            elapsed += const Duration(milliseconds: 1);
          }
          if (watch.elapsed < best) best = watch.elapsed;
        }
        final mbps = total / 1048576 / (best.inMicroseconds / 1e6);
        // ignore: avoid_print
        print(
          '${make.$1.padRight(9)} ${workload.name.padRight(22)} '
          '${mbps.toStringAsFixed(1)} MB/s',
        );
        expect(mbps, greaterThan(4), reason: workload.name);
      }
    });
  }
}
