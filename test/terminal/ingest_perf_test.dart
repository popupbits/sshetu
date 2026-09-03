@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/terminal/output_coalescer.dart';
import 'package:xterm2/xterm.dart';

/// How fast output can be taken in and parsed.
///
/// This is the app's hot path: a `tail -f`, a build log or a `find /` is a
/// remote process producing faster than anyone reads, and every byte is
/// decoded and parsed on the UI isolate. If ingest is slow the whole app is,
/// and no amount of careful widget work compensates.
///
/// The budgets are deliberately loose — several times the measured cost on a
/// developer machine. They are here to catch a *regression*, something that
/// makes ingest an order of magnitude worse, not to police a few milliseconds
/// on whatever hardware happens to run CI. Timing assertions that fail on a
/// slow runner get deleted, and then they catch nothing at all.
void main() {
  /// Output shaped like a real build log: mixed lengths, colour escapes, and
  /// the occasional wide character. Uniform ASCII would flatter the parser.
  String buildLog(int lines) {
    final random = Random(7);
    final buffer = StringBuffer();
    for (var i = 0; i < lines; i++) {
      switch (random.nextInt(5)) {
        case 0:
          buffer.write('\x1b[32m  ✓\x1b[0m compiled module_$i.dart\r\n');
        case 1:
          buffer.write(
            '\x1b[1;33mwarning\x1b[0m: unused import at line ${random.nextInt(900)}\r\n',
          );
        case 2:
          buffer.write(
            '-rw-r--r--  1 user  staff  ${random.nextInt(99999)} '
            'file_$i.txt\r\n',
          );
        case 3:
          buffer.write('${'=' * (20 + random.nextInt(60))}\r\n');
        default:
          buffer.write('[$i] ordinary output line with some words in it\r\n');
      }
    }
    return buffer.toString();
  }

  Duration measure(void Function() body) {
    final watch = Stopwatch()..start();
    body();
    return watch.elapsed;
  }

  test('the parser keeps up with a fast build log', () {
    final terminal = Terminal(maxLines: 5000);
    terminal.resize(120, 40);
    final payload = buildLog(20000);

    final elapsed = measure(() => terminal.write(payload));

    // ignore: avoid_print
    print(
      'parse: ${payload.length ~/ 1024} KiB in '
      '${elapsed.inMilliseconds} ms',
    );

    expect(
      elapsed,
      lessThan(const Duration(seconds: 5)),
      reason:
          'parsing a large log must not take seconds — this is the path '
          'every byte from every session travels',
    );
  });

  test('the coalescer batches rather than writing per chunk', () {
    // The property that matters: an SSH channel delivers small chunks, and
    // without batching each one becomes its own decode, write and repaint
    // request. Under sustained output the coalescer should hand the terminal
    // far fewer writes than it received chunks.
    var writes = 0;
    final scheduled = <void Function()>[];

    final coalescer = OutputCoalescer(
      onData: (_) => writes++,
      // A frame never actually runs here; the point is to show that chunks
      // arriving inside one frame do not each become a write.
      scheduleFrameCallback: scheduled.add,
      scheduleWatchdog: (_, _) => Object(),
      cancelWatchdog: (_) {},
      // A clock that never advances, so nothing is ever treated as idle —
      // exactly the sustained-output case.
      clock: () => Duration.zero,
    );

    final chunk = utf8.encode('some output from a busy remote process\r\n');
    for (var i = 0; i < 500; i++) {
      coalescer.add(chunk);
    }

    expect(
      writes,
      lessThan(5),
      reason:
          '500 chunks inside one frame must not become 500 terminal '
          'writes — that is the jank the coalescer exists to remove',
    );

    // And nothing is lost: the pending bytes are still there to be flushed.
    expect(coalescer.pendingBytes, chunk.length * 500);

    coalescer.flush();
    expect(writes, greaterThan(0));
    coalescer.dispose();
  });

  test('a slow reader drops the oldest rather than growing without bound', () {
    // A hidden or wedged pane producing faster than it drains would otherwise
    // turn a throttle into a memory leak.
    final coalescer = OutputCoalescer(
      onData: (_) {},
      scheduleFrameCallback: (_) {},
      scheduleWatchdog: (_, _) => Object(),
      cancelWatchdog: (_) {},
      clock: () => Duration.zero,
      maxPendingBytes: 4096,
    );

    final chunk = utf8.encode('x' * 1024);
    for (var i = 0; i < 100; i++) {
      coalescer.add(chunk);
    }

    expect(coalescer.pendingBytes, lessThanOrEqualTo(4096));
    expect(
      coalescer.droppedBytes,
      greaterThan(0),
      reason:
          'dropping must be visible, not silent — dropped bytes can cut '
          'an escape sequence and garble a full-screen program',
    );
    coalescer.dispose();
  });

  test('a multi-byte character split across chunks survives', () {
    // The reason bytes are buffered rather than strings. Decoding each chunk
    // on its own would put a replacement character in the middle of anyone's
    // UTF-8 output.
    final written = StringBuffer();
    final coalescer = OutputCoalescer(
      onData: written.write,
      scheduleFrameCallback: (_) {},
      scheduleWatchdog: (_, _) => Object(),
      cancelWatchdog: (_) {},
      clock: () => Duration.zero,
    );

    final bytes = utf8.encode('नमस्ते');
    for (final byte in bytes) {
      coalescer.add([byte]);
      coalescer.flush();
    }

    expect(written.toString(), 'नमस्ते');
    coalescer.dispose();
  });
}
