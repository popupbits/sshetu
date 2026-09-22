import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/domain/output_capture.dart';

void main() {
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  test('strips escape sequences and keeps the prompt', () async {
    final capture = OutputCapture()
      ..add(bytes('\x1b[1;32mok\x1b[0m\r\n'))
      ..add(bytes('user@web:~\$ '));
    expect(await capture.settle(max: Duration.zero), 'ok\nuser@web:~\$ ');
  });

  test('a multi-byte character split across chunks survives', () async {
    final all = utf8.encode('नमस्ते\n');
    final capture = OutputCapture()
      ..add(Uint8List.fromList(all.sublist(0, 4)))
      ..add(Uint8List.fromList(all.sublist(4)));
    expect(capture.text, 'नमस्ते\n');
  });

  test('settles once output goes quiet, before the maximum', () async {
    final capture = OutputCapture();
    final watch = Stopwatch()..start();
    Timer(const Duration(milliseconds: 20), () => capture.add(bytes('a\n')));
    Timer(const Duration(milliseconds: 60), () => capture.add(bytes('b\n')));
    final text = await capture.settle(
      max: const Duration(seconds: 5),
      quiet: const Duration(milliseconds: 150),
    );
    expect(text, 'a\nb\n');
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('waits the whole maximum when nothing arrives', () async {
    final capture = OutputCapture();
    final watch = Stopwatch()..start();
    expect(
      await capture.settle(
        max: const Duration(milliseconds: 120),
        quiet: const Duration(milliseconds: 10),
      ),
      '',
    );
    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 100)),
    );
    expect(capture.receivedAny, isFalse);
  });

  test('keeps the tail of a flood', () {
    final capture = OutputCapture(maxChars: 100);
    for (var i = 0; i < 100; i++) {
      capture.add(bytes('line $i\n'));
    }
    final text = capture.text;
    expect(text.length, lessThanOrEqualTo(100));
    expect(text, endsWith('line 99\n'));
    expect(capture.truncated, isTrue);
  });
}
