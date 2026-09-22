import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:sshetu/core/terminal/output_coalescer.dart';
import 'package:xterm2/xterm.dart';

/// A shape of remote output, as the bytes an SSH channel delivers.
class TerminalWorkload {
  TerminalWorkload({
    required this.name,
    required this.chunks,
    this.columns = 120,
    this.rows = 40,
    this.maxLines = 10000,
  });

  final String name;
  final List<Uint8List> chunks;
  final int columns;
  final int rows;
  final int maxLines;

  Terminal newTerminal() => Terminal(maxLines: maxLines)..resize(columns, rows);
}

/// The chunk size an SSH channel hands over under load: one channel-data
/// packet's worth. Real sessions vary; this is the busy case.
const int kSshChunk = 16 * 1024;

List<Uint8List> _chunk(List<int> bytes, [int size = kSshChunk]) => [
  for (var i = 0; i < bytes.length; i += size)
    Uint8List.fromList(bytes.sublist(i, min(i + size, bytes.length))),
];

/// Repeats [block] until [targetBytes] are reached, then chunks it.
List<Uint8List> _repeat(String block, int targetBytes, [int size = kSshChunk]) {
  final encoded = utf8.encode(block);
  final out = BytesBuilder(copy: false);
  while (out.length < targetBytes) {
    out.add(encoded);
  }
  return _chunk(out.takeBytes(), size);
}

/// `seq 1 N` through a pty: short lines, nothing but digits and CRLF.
List<Uint8List> seqFlood(int lines) {
  final b = StringBuffer();
  for (var i = 1; i <= lines; i++) {
    b
      ..write(i)
      ..write('\r\n');
  }
  return _chunk(utf8.encode(b.toString()));
}

/// `cat` of a large plain log: mixed line lengths, ASCII words.
List<Uint8List> catMixed(int targetBytes) {
  final random = Random(11);
  const words = [
    'the',
    'request',
    'completed',
    'in',
    'ms',
    'user',
    'session',
    'error',
    'INFO',
    'WARN',
    'GET',
    '/api/v1/items',
    'status=200',
    'bytes',
    'cache',
    'miss',
    'connection',
    'from',
    '10.0.0.12',
    'port',
    'worker',
    'queue',
  ];
  final b = StringBuffer();
  for (var i = 0; i < 12000; i++) {
    final n = 2 + random.nextInt(18);
    b.write('2026-09-22T10:${(i % 60).toString().padLeft(2, '0')}:00Z ');
    for (var w = 0; w < n; w++) {
      b
        ..write(words[random.nextInt(words.length)])
        ..write(' ');
    }
    b.write('\r\n');
  }
  return _repeat(b.toString(), targetBytes);
}

/// `ls -la --color`: colour escapes around every name.
List<Uint8List> lsColor(int targetBytes) {
  final random = Random(3);
  const colours = ['01;34', '01;32', '01;36', '00', '01;31', '40;33;01'];
  final b = StringBuffer();
  for (var i = 0; i < 4000; i++) {
    final c = colours[random.nextInt(colours.length)];
    b.write(
      '${i.isEven ? 'drwxr-xr-x' : '-rw-r--r--'}  2 user user '
      '${random.nextInt(999999).toString().padLeft(8)} Sep 22 10:00 '
      '\x1b[${c}m'
      'name_${random.nextInt(1 << 20).toRadixString(16)}'
      '\x1b[0m\r\n',
    );
  }
  return _repeat(b.toString(), targetBytes);
}

/// An htop-like full-screen redraw, over and over: cursor addressing, colour
/// runs, meter bars and erase-to-end-of-line on every row.
List<Uint8List> htopRedraw(
  int targetBytes, {
  int columns = 120,
  int rows = 40,
}) {
  final random = Random(5);
  final b = StringBuffer('\x1b[?1049h\x1b[?25l');
  for (var frame = 0; frame < 60; frame++) {
    b.write('\x1b[?2026h\x1b[H');
    for (var r = 1; r <= rows; r++) {
      b.write('\x1b[$r;1H');
      if (r <= 4) {
        final fill = random.nextInt(40);
        b.write(
          '\x1b[1;36m${r.toString().padLeft(3)}\x1b[0m\x1b[1m[\x1b[0m'
          '\x1b[32m${'|' * fill}\x1b[31m${'|' * (fill ~/ 3)}'
          '\x1b[0m${' ' * (50 - fill - fill ~/ 3)}'
          '\x1b[1m${(random.nextDouble() * 100).toStringAsFixed(1)}%]\x1b[0m',
        );
      } else if (r == 6) {
        b.write(
          '\x1b[30;42m  PID USER      PRI  NI  VIRT   RES   SHR S CPU% MEM%   '
          'TIME+  Command${' ' * (columns - 78)}\x1b[0m',
        );
      } else {
        b.write(
          '\x1b[${r == 8 ? '30;46' : '0'}m'
          '${(1000 + random.nextInt(90000)).toString().padLeft(5)} '
          'user       20   0 '
          '\x1b[36m${random.nextInt(9999)}M\x1b[0m '
          '${random.nextInt(999)}M  ${random.nextInt(99)}M S '
          '\x1b[1m${(random.nextDouble() * 100).toStringAsFixed(1)}\x1b[0m '
          '${(random.nextDouble() * 10).toStringAsFixed(1)}  '
          '0:${random.nextInt(59).toString().padLeft(2, '0')}.00 '
          '\x1b[32m/usr/bin/process_${random.nextInt(99)}\x1b[0m',
        );
      }
      b.write('\x1b[K');
    }
    b.write('\x1b[?2026l');
  }
  return _repeat(b.toString(), targetBytes, 4096);
}

/// Lines far wider than the terminal, so every one soft-wraps many times.
List<Uint8List> longLines(int targetBytes) {
  final random = Random(9);
  final b = StringBuffer();
  for (var i = 0; i < 400; i++) {
    final len = 500 + random.nextInt(3000);
    for (var j = 0; j < len; j++) {
      b.writeCharCode(0x61 + random.nextInt(26));
    }
    b.write('\r\n');
  }
  return _repeat(b.toString(), targetBytes);
}

/// Devanagari (with combining marks) and emoji: wide cells, multi-byte UTF-8,
/// surrogate pairs.
List<Uint8List> devanagariEmoji(int targetBytes) {
  const parts = [
    'नमस्ते संसार',
    'क्षत्रिय',
    'श्रीमान्',
    '😀',
    '🚀 deploy ok',
    '👍🏽',
    'ascii text',
    '✓',
    '日本語',
  ];
  final random = Random(13);
  final b = StringBuffer();
  for (var i = 0; i < 3000; i++) {
    final n = 3 + random.nextInt(8);
    for (var w = 0; w < n; w++) {
      b
        ..write(parts[random.nextInt(parts.length)])
        ..write(' ');
    }
    b.write('\r\n');
  }
  // Odd chunking on purpose, so characters split across reads.
  return _repeat(b.toString(), targetBytes, kSshChunk - 1);
}

/// Every workload, at [scale] × a default-run size (a few MB each).
List<TerminalWorkload> terminalWorkloads({required double scale}) {
  int mb(double n) => (n * scale * 1024 * 1024).round();
  return [
    TerminalWorkload(
      name: 'seq newline flood',
      chunks: seqFlood((200000 * scale).round()),
    ),
    TerminalWorkload(name: 'cat mixed text', chunks: catMixed(mb(8))),
    TerminalWorkload(name: 'ls -la --color', chunks: lsColor(mb(4))),
    TerminalWorkload(name: 'htop redraws', chunks: htopRedraw(mb(4))),
    TerminalWorkload(
      name: 'long wrapping lines',
      chunks: longLines(mb(4)),
      columns: 80,
      rows: 24,
    ),
    TerminalWorkload(
      name: 'devanagari + emoji',
      chunks: devanagariEmoji(mb(2)),
    ),
  ];
}

const _runs = 5;

/// What one workload measured. Every duration is a median of [_runs].
class WorkloadResult {
  WorkloadResult({
    required this.name,
    required this.bytes,
    required this.coalescerOnly,
    required this.decodeOnly,
    required this.parseOnly,
    required this.endToEnd,
    required this.flushes,
    required this.dropped,
  });

  final String name;
  final int bytes;
  final Duration coalescerOnly;
  final Duration decodeOnly;
  final Duration parseOnly;
  final Duration endToEnd;
  final int flushes;
  final int dropped;

  static double _mbps(int bytes, Duration d) =>
      bytes / (1024 * 1024) / (max(d.inMicroseconds, 1) / 1e6);

  double get coalescerOverheadMBps => _mbps(bytes, coalescerOnly);
  double get endToEndMBps => _mbps(bytes, endToEnd);

  String describe() {
    String f(Duration d) =>
        '${(d.inMicroseconds / 1000).toStringAsFixed(1).padLeft(7)} ms '
        '(${_mbps(bytes, d).toStringAsFixed(1).padLeft(7)} MB/s)';
    return '${name.padRight(22)} ${(bytes / 1048576).toStringAsFixed(1)} MB | '
        'coalescer+decode ${f(coalescerOnly)} | decode ${f(decodeOnly)} | '
        'parse ${f(parseOnly)} | end-to-end ${f(endToEnd)} | '
        '$flushes flushes, $dropped dropped';
  }
}

Duration _median(Duration Function() body) {
  body(); // warm-up
  final samples = [for (var i = 0; i < _runs; i++) body()]..sort();
  return samples[samples.length ~/ 2];
}

/// Runs [workload] through each stage and the whole path.
WorkloadResult measureWorkload(TerminalWorkload workload) {
  final chunks = workload.chunks;
  final total = chunks.fold<int>(0, (sum, c) => sum + c.length);

  // 1. The coalescer and its decode, with a terminal that does nothing.
  //    Frames run whenever a flush's worth is waiting, so nothing is dropped:
  //    this is the cost of moving bytes, not of the cap.
  final coalescerOnly = _median(() => _drive(chunks, (_) {}).elapsed);

  // 2. The decode alone, the way the coalescer does it: one long-lived
  //    chunked decoder.
  final decodeOnly = _median(() {
    final watch = Stopwatch()..start();
    final out = StringBuffer();
    final sink = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(_StringSink(out));
    for (final c in chunks) {
      sink.add(c);
      if (out.length > kMaxFlushBytes) out.clear();
    }
    final elapsed = watch.elapsed;
    sink.close();
    return elapsed;
  });

  // 3. The parser alone, on text already decoded into flush-sized pieces.
  final text = utf8.decode(
    Uint8List.fromList([for (final c in chunks) ...c]),
    allowMalformed: true,
  );
  final pieces = <String>[
    for (var i = 0; i < text.length; i += kMaxFlushBytes)
      text.substring(i, min(i + kMaxFlushBytes, text.length)),
  ];
  final parseOnly = _median(() {
    final terminal = workload.newTerminal();
    final watch = Stopwatch()..start();
    for (final p in pieces) {
      terminal.write(p);
    }
    return watch.elapsed;
  });

  // 4. The whole path.
  var flushes = 0;
  var dropped = 0;
  final endToEnd = _median(() {
    final terminal = workload.newTerminal();
    flushes = 0;
    final run = _drive(chunks, (data) {
      flushes++;
      terminal.write(data);
    });
    dropped = run.dropped;
    return run.elapsed;
  });

  return WorkloadResult(
    name: workload.name,
    bytes: total,
    coalescerOnly: coalescerOnly,
    decodeOnly: decodeOnly,
    parseOnly: parseOnly,
    endToEnd: endToEnd,
    flushes: flushes,
    dropped: dropped,
  );
}

/// Feeds [chunks] to a coalescer as a busy session would, running a "frame"
/// whenever a full flush is waiting, and returns the time taken.
({Duration elapsed, int dropped}) _drive(
  List<Uint8List> chunks,
  void Function(String data) onData,
) {
  final frames = <void Function()>[];
  final coalescer = OutputCoalescer(
    onData: onData,
    scheduleFrameCallback: frames.add,
    scheduleWatchdog: (_, _) => Object(),
    cancelWatchdog: (_) {},
    // Never idle: sustained output, the case the coalescer batches.
    clock: () => Duration.zero,
  );
  void runFrames() {
    while (frames.isNotEmpty) {
      final pending = List.of(frames);
      frames.clear();
      for (final f in pending) {
        f();
      }
    }
  }

  final watch = Stopwatch()..start();
  for (final c in chunks) {
    coalescer.add(c);
    if (coalescer.pendingBytes >= kMaxFlushBytes) runFrames();
  }
  while (coalescer.pendingBytes > 0) {
    coalescer.flush();
  }
  runFrames();
  watch.stop();
  final dropped = coalescer.droppedBytes;
  coalescer.dispose();
  return (elapsed: watch.elapsed, dropped: dropped);
}

class _StringSink implements Sink<String> {
  _StringSink(this._out);
  final StringBuffer _out;
  @override
  void add(String data) => _out.write(data);
  @override
  void close() {}
}
