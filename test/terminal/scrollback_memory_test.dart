@Tags(['perf'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:xterm2/xterm.dart';

/// What a tab's scrollback costs in memory.
///
/// xterm2 stores a line as a `Uint32List` of four words per cell, sized to a
/// capacity rather than to the width: 64 cells for anything up to 64 columns,
/// then powers of two to 256, then steps of 32. So an 80-column line holds
/// 128 cells (2 KiB) and a 200-column one 256 (4 KiB), whatever is printed on
/// it — a blank line costs the same as a full one.
///
/// Two measurements: the exact bytes of cell storage the buffer holds, and
/// the process's resident-set growth while tabs fill, which also counts
/// object headers and whatever the collector has not yet returned. The first
/// is the one to trust; the second says the first is not missing anything
/// large. Budgets are loose: they exist to notice the per-line cost doubling,
/// not to police a few percent.
void main() {
  /// A terminal whose scrollback is full, of [columns] × 40.
  Terminal fullTab(int columns, int maxLines) {
    final terminal = Terminal(maxLines: maxLines)..resize(columns, 40);
    final line = 'x' * (columns - 1);
    final text = StringBuffer();
    for (var i = 0; i < maxLines + 40; i++) {
      text
        ..write(line)
        ..write('\r\n');
    }
    terminal.write(text.toString());
    return terminal;
  }

  int cellBytes(Terminal terminal) {
    final lines = terminal.buffer.lines;
    var bytes = 0;
    for (var i = 0; i < lines.length; i++) {
      bytes += lines[i].data.lengthInBytes;
    }
    return bytes;
  }

  const maxLines = AppSettings.defaultScrollbackLines;

  for (final columns in [80, 120, 200]) {
    test('a full $maxLines-line scrollback at $columns columns', () {
      final terminal = fullTab(columns, maxLines);
      final lines = terminal.buffer.lines.length;
      final bytes = cellBytes(terminal);
      final perLine = bytes / lines;
      // ignore: avoid_print
      print(
        '$columns cols: $lines lines, ${(bytes / 1048576).toStringAsFixed(1)} '
        'MiB of cells, ${perLine.round()} B/line '
        '(${(perLine / columns).toStringAsFixed(1)} B per visible column)',
      );
      // 16 bytes a cell, at most twice the width in capacity.
      expect(perLine, lessThanOrEqualTo(columns * 16 * 2));
      expect(lines, maxLines);
    });
  }

  test('ten tabs of full scrollback, resident-set growth', () {
    // Filled one after another with the RSS read between, so the growth per
    // tab is visible, not only the total. The collector runs when it likes;
    // the readings are an upper bound on live memory, not a precise count.
    final tabs = <Terminal>[];
    final before = ProcessInfo.currentRss;
    final growth = <int>[];
    var last = before;
    for (var i = 0; i < 10; i++) {
      tabs.add(fullTab(80, maxLines));
      final now = ProcessInfo.currentRss;
      growth.add(now - last);
      last = now;
    }
    final total = last - before;
    final cells = tabs.fold<int>(0, (sum, t) => sum + cellBytes(t));
    // ignore: avoid_print
    print(
      '10 tabs × $maxLines lines × 80 cols: cells '
      '${(cells / 1048576).toStringAsFixed(1)} MiB, RSS grew '
      '${(total / 1048576).toStringAsFixed(1)} MiB '
      '(per tab: ${growth.map((g) => (g / 1048576).toStringAsFixed(1)).join(', ')})',
    );
    expect(tabs, hasLength(10));
  });
}
