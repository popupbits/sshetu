@Tags(['bench'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'terminal_workloads.dart';

/// `throughput_bench_test.dart` at full size: a 50 MB `cat`, a
/// 1.25-million-line `seq`, 25 MB of colour `ls`, htop redraws and wrapping
/// lines. Too slow for every run, so it is skipped unless asked for:
///
/// ```sh
/// flutter test --run-skipped --tags bench test/terminal/throughput_full_bench_test.dart
/// ```
void main() {
  for (final workload in terminalWorkloads(scale: 6.25)) {
    test('full-size throughput: ${workload.name}', () {
      final result = measureWorkload(workload);
      // ignore: avoid_print
      print(result.describe());
      expect(result.endToEndMBps, greaterThan(1));
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
