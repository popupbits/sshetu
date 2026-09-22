@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/output_coalescer.dart'
    show OutputCoalescer;

import 'terminal_workloads.dart';

/// End-to-end output throughput, without a window: bytes as an SSH channel
/// hands them over → [OutputCoalescer] → UTF-8 decode → `Terminal.write` →
/// buffer.
///
/// Each workload is measured stage by stage, so a regression says *where* it
/// is: the coalescer's own bookkeeping, the decode, or xterm2's parser. Every
/// stage runs five times and the median is kept, after a warm-up, so the
/// JIT and the first scrollback fill do not land on whichever stage happens
/// to go first. The numbers are printed; the assertions are an order of
/// magnitude looser than what a developer machine measures, so they catch a
/// regression rather than a slow runner.
///
/// Sizes are a few MB per workload so this runs by default;
/// `flutter test --run-skipped --tags bench` runs
/// `throughput_full_bench_test.dart`, the same workloads at full size (a 50 MB
/// `cat`, a million-line `seq`).
void main() {
  for (final workload in terminalWorkloads(scale: 1)) {
    test('throughput: ${workload.name}', () {
      final result = measureWorkload(workload);
      // ignore: avoid_print
      print(result.describe());

      // Budgets: 1 MB/s end to end would mean a `cat` of a log freezes the
      // app for seconds. Measured on a developer machine every workload is
      // above 8 MB/s and most above 40.
      expect(
        result.endToEndMBps,
        greaterThan(1),
        reason: 'output ingest regressed by an order of magnitude',
      );
      expect(
        result.coalescerOverheadMBps,
        greaterThan(40),
        reason:
            'the coalescer only moves bytes; it must never be the '
            'bottleneck in front of the parser (it measured ~23 MB/s as one '
            'growable List<int>, 900+ MB/s as a queue of chunks)',
      );
    });
  }
}
