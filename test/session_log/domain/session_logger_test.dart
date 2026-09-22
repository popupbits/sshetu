import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/session_log/domain/log_encoders.dart';
import 'package:sshetu/features/session_log/domain/session_logger.dart';

import '../fake_log_sink.dart';

void main() {
  late FakeLogSink sink;
  late void Function(Timer) tick;
  late Timer timer;
  var elapsed = Duration.zero;

  SessionLogger build({
    int warnBytes = kSessionLogWarnBytes,
    int flushBytes = kSessionLogFlushBytes,
    void Function()? onWarn,
    void Function(Object)? onError,
  }) => SessionLogger(
    encoder: RawLogEncoder(),
    sink: sink,
    warnBytes: warnBytes,
    flushBytes: flushBytes,
    timer: (interval, callback) {
      tick = callback;
      return timer = _ManualTimer();
    },
    elapsed: () => elapsed,
    now: () => DateTime(2026, 9, 22, 12),
    onWarn: onWarn,
    onError: onError,
  );

  final header = SessionLogHeader(
    title: 'me@host',
    started: DateTime(2026, 9, 22),
    columns: 80,
    rows: 24,
  );

  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

  setUp(() {
    sink = FakeLogSink();
    elapsed = Duration.zero;
  });

  test('output is buffered, then written on the tick', () async {
    final logger = build()..start(header);
    logger.output(bytes('one '), columns: 80, rows: 24);
    logger.output(bytes('two'), columns: 80, rows: 24);
    await pumpEventQueue();
    expect(sink.writes, isEmpty, reason: 'nothing written before the tick');

    tick(timer);
    await pumpEventQueue();
    expect(sink.writes, hasLength(1), reason: 'one write for the batch');
    expect(sink.text, 'one two');
    await logger.close();
  });

  test('a burst past the threshold is written without waiting', () async {
    final logger = build(flushBytes: 8)..start(header);
    logger.output(bytes('0123456789'), columns: 80, rows: 24);
    await pumpEventQueue();
    expect(sink.text, '0123456789');
    await logger.close();
  });

  test('writes never overlap, and land in order', () async {
    sink.delay = const Duration(milliseconds: 5);
    final logger = build(flushBytes: 1)..start(header);
    for (final word in ['a', 'b', 'c', 'd']) {
      logger.output(bytes(word), columns: 80, rows: 24);
    }
    await logger.close();
    expect(sink.maxConcurrent, 1);
    expect(sink.text, 'abcd');
  });

  test('close writes the final marker, flushes, closes, and stops the '
      'timer', () async {
    final logger = build()..start(header);
    logger.output(bytes('last words'), columns: 80, rows: 24);
    await logger.close(finalMarker: 'logging stopped');
    expect(sink.closed, isTrue);
    expect(timer.isActive, isFalse);
    expect(sink.text, startsWith('last words'));
    expect(sink.text, contains('logging stopped'));

    // Closed is closed: later output is dropped, a second close is harmless.
    logger.output(bytes('ghost'), columns: 80, rows: 24);
    await logger.close();
    expect(sink.text, isNot(contains('ghost')));
    expect(sink.closeCount, 1);
  });

  test('passing the size warning calls back once, and keeps logging', () async {
    var warned = 0;
    final logger = build(warnBytes: 10, onWarn: () => warned++)..start(header);
    logger.output(bytes('12345'), columns: 80, rows: 24);
    expect(warned, 0);
    logger.output(bytes('67890'), columns: 80, rows: 24);
    expect(warned, 1);
    expect(logger.oversized, isTrue);
    logger.output(bytes('more'), columns: 80, rows: 24);
    expect(warned, 1);
    await logger.close();
    expect(sink.text, '1234567890more');
  });

  test('a failed write stops the log and reports once', () async {
    final errors = <Object>[];
    sink.failWith = const FileSystemFailure();
    final logger = build(flushBytes: 1, onError: errors.add)..start(header);
    logger.output(bytes('x'), columns: 80, rows: 24);
    await pumpEventQueue();
    expect(errors, hasLength(1));
    expect(logger.isClosed, isTrue);
    expect(sink.closed, isTrue, reason: 'the file is released');

    logger.output(bytes('y'), columns: 80, rows: 24);
    await logger.close();
    expect(errors, hasLength(1));
  });
}

class _ManualTimer implements Timer {
  var _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class FileSystemFailure implements Exception {
  const FileSystemFailure();
}
