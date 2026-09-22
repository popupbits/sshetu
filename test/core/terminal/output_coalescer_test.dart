import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/output_coalescer.dart';

/// The coalescer keeps pending output as the chunks it arrived in, with an
/// offset into the oldest. These pin that a flush or a drop landing in the
/// middle of a chunk, or across several, never loses, repeats or reorders a
/// byte.
void main() {
  OutputCoalescer make(
    void Function(String) onData, {
    int maxFlushBytes = kMaxFlushBytes,
    int maxPendingBytes = kMaxPendingBytes,
  }) => OutputCoalescer(
    onData: onData,
    scheduleFrameCallback: (_) {},
    scheduleWatchdog: (_, _) => Object(),
    cancelWatchdog: (_) {},
    // Never idle, so nothing is written through: every flush is explicit.
    clock: () => Duration.zero,
    maxFlushBytes: maxFlushBytes,
    maxPendingBytes: maxPendingBytes,
  );

  test('a flush budget that ends mid-chunk carries the rest, in order', () {
    final out = StringBuffer();
    final coalescer = make(out.write, maxFlushBytes: 7);
    coalescer
      ..add(utf8.encode('abcde'))
      ..add(utf8.encode('fghij'))
      ..add(utf8.encode('klmno'));

    coalescer.flush();
    expect(out.toString(), 'abcdefg');
    expect(coalescer.pendingBytes, 8);
    coalescer.flush();
    expect(out.toString(), 'abcdefghijklmn');
    coalescer.flush();
    expect(out.toString(), 'abcdefghijklmno');
    expect(coalescer.pendingBytes, 0);
    coalescer.dispose();
  });

  test('dropping keeps exactly the newest bytes, across chunk edges', () {
    final out = StringBuffer();
    final coalescer = make(out.write, maxPendingBytes: 6);
    coalescer
      ..add(utf8.encode('0123'))
      ..add(utf8.encode('4567'))
      ..add(utf8.encode('89'));

    expect(coalescer.pendingBytes, 6);
    expect(coalescer.droppedBytes, 4);
    coalescer.flush();
    expect(out.toString(), '456789');
    coalescer.dispose();
  });

  test('a drop inside the chunk a flush already started on', () {
    final out = StringBuffer();
    final coalescer = make(out.write, maxFlushBytes: 3, maxPendingBytes: 8);
    coalescer.add(utf8.encode('abcdefgh'));
    coalescer.flush(); // abc; the head chunk is now half consumed
    coalescer.add(utf8.encode('ijklm')); // 10 pending > 8: drop 'de'
    expect(coalescer.droppedBytes, 2);
    while (coalescer.pendingBytes > 0) {
      coalescer.flush();
    }
    expect(out.toString(), 'abcfghijklm');
    coalescer.dispose();
  });

  test('the caller may reuse its buffer once add returns', () {
    final out = StringBuffer();
    final coalescer = make(out.write);
    final buffer = Uint8List.fromList(utf8.encode('first'));
    coalescer.add(buffer);
    buffer.setAll(0, utf8.encode('XXXXX'));
    coalescer.flush();
    expect(out.toString(), 'first');
    coalescer.dispose();
  });

  test('a character split across chunks and flushes decodes whole', () {
    final out = StringBuffer();
    final coalescer = make(out.write, maxFlushBytes: 5);
    final bytes = utf8.encode('नमस्ते 😀 ok');
    // Split into 3-byte chunks, which never line up with the characters.
    for (var i = 0; i < bytes.length; i += 3) {
      coalescer.add(bytes.sublist(i, (i + 3).clamp(0, bytes.length)));
    }
    while (coalescer.pendingBytes > 0) {
      coalescer.flush();
    }
    expect(out.toString(), 'नमस्ते 😀 ok');
    coalescer.dispose();
  });
}
