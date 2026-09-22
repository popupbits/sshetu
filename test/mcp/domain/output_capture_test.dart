import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/domain/output_capture.dart';

void main() {
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  const zshPrompt = 'dl@box ~ % ';
  const bashPrompt = 'dl@box:~\$ ';
  const command = r'echo mcp-answer-$((6*7))';

  /// A screen with some earlier output and [prompt] on the cursor's row.
  CaptureSeed seedAt(String prompt, {int columns = 80}) => CaptureSeed(
    columns: columns,
    rows: 24,
    lines: [
      (text: 'Last login: Tue Sep 22 09:00:01 2026', continues: false),
      (text: prompt.trimRight(), continues: false),
    ],
    cursorX: prompt.length,
  );

  String replay(CaptureSeed seed, List<String> chunks) {
    final capture = OutputCapture(seed: seed);
    for (final chunk in chunks) {
      capture.add(bytes(chunk));
    }
    return capture.text;
  }

  group('a typed command reads back once, then its output', () {
    const clean = '$command\nmcp-answer-42';

    test('bash: readline echoes the line as typed', () {
      expect(
        replay(seedAt(bashPrompt), [
          command,
          '\r\n',
          'mcp-answer-42\r\n',
          '\x1b]0;dl@box:~\x07$bashPrompt',
        ]),
        clean,
      );
    });

    test('zsh: incremental echo, then a redraw moving back with CSI D', () {
      // What produced the doubled line live: zle echoes as it reads, and on
      // the closing parenthesis (syntax highlighting, bracket matching)
      // moves back over the line and prints all of it again, coloured.
      final partial = command.substring(0, command.length - 1);
      expect(
        replay(seedAt(zshPrompt), [
          partial,
          '\x1b[${partial.length}D',
          '\x1b[32mecho\x1b[39m mcp-answer-\$((6*7))',
          '\x1b[K',
          '\r\r\n',
          'mcp-answer-42\r\n',
          '\x1b[7m%\x1b[27m${' ' * 79}\r \r',
          '\r$zshPrompt\x1b[K',
        ]),
        clean,
      );
    });

    test('zsh: a redraw from the start of the row, prompt and all', () {
      final partial = command.substring(0, command.length - 1);
      expect(
        replay(seedAt(zshPrompt), [
          partial,
          '\r\x1b[1m$zshPrompt\x1b[0m$command\x1b[K',
          '\r\n',
          'mcp-answer-42\r\n',
          zshPrompt,
        ]),
        clean,
      );
    });

    test('zsh: carriage return, cursor forward past the prompt, reprint', () {
      expect(
        replay(seedAt(zshPrompt), [
          'echo mcp',
          '\r\x1b[${zshPrompt.length}C',
          command,
          '\r\n',
          'mcp-answer-42\r\n',
          zshPrompt,
        ]),
        clean,
      );
    });

    test('backspaces over the echo, then the line again', () {
      expect(
        replay(seedAt(bashPrompt), [
          'echo mcp-',
          '\b' * 'echo mcp-'.length,
          command,
          '\r\n',
          'mcp-answer-42\r\n',
          bashPrompt,
        ]),
        clean,
      );
    });

    test('an erase to the end of the line leaves no stale echo', () {
      expect(
        replay(seedAt(bashPrompt), [
          '$command # a long trailing comment',
          '\r\x1b[${bashPrompt.length}C\x1b[K$command',
          '\r\n',
          'mcp-answer-42\r\n',
          bashPrompt,
        ]),
        clean,
      );
    });
  });

  test('a command longer than the row, redrawn by moving up a line', () {
    const width = 40;
    final long = 'echo ${'x' * 45}';
    final seed = seedAt(zshPrompt, columns: width);
    expect(
      replay(seed, [
        long.substring(0, 40),
        // Back to the start of the typed text: up one row, then to its column.
        '\x1b[1A\r\x1b[${zshPrompt.length}C',
        long,
        '\r\n',
        '${'x' * 45}\r\n',
        zshPrompt,
      ]),
      '$long\n${'x' * 45}',
    );
  });

  test('output with no final newline survives the PROMPT_SP mark', () {
    // zsh prints its mark and a row of spaces so that dangling output is
    // pushed onto a line of its own rather than overwritten by the prompt.
    expect(
      replay(seedAt(zshPrompt), [
        'printf foo\r\n',
        'foo',
        '\x1b[7m%\x1b[27m${' ' * 79}\r \r',
        '\r$zshPrompt\x1b[K',
      ]),
      'printf foo\nfoo%',
    );
  });

  test('a different prompt at the end is kept: it may be the answer', () {
    expect(
      replay(seedAt(bashPrompt), [
        'sudo -k ls\r\n',
        '[sudo] password for dl: ',
      ]),
      'sudo -k ls\n[sudo] password for dl:',
    );
  });

  test('no seed: plain text, escapes removed', () async {
    final capture = OutputCapture()
      ..add(bytes('\x1b[1;32mok\x1b[0m\r\n'))
      ..add(bytes('user@web:~\$ '));
    expect(await capture.settle(max: Duration.zero), 'ok\nuser@web:~\$');
  });

  test('a multi-byte character split across chunks survives', () async {
    final all = utf8.encode('नमस्ते\n');
    final capture = OutputCapture()
      ..add(Uint8List.fromList(all.sublist(0, 4)))
      ..add(Uint8List.fromList(all.sublist(4)));
    expect(capture.text, contains('नमस्'));
  });

  test('settles once output goes quiet, before the maximum', () async {
    final capture = OutputCapture();
    final watch = Stopwatch()..start();
    Timer(const Duration(milliseconds: 20), () => capture.add(bytes('a\r\n')));
    Timer(const Duration(milliseconds: 60), () => capture.add(bytes('b\r\n')));
    final text = await capture.settle(
      max: const Duration(seconds: 5),
      quiet: const Duration(milliseconds: 150),
    );
    expect(text, 'a\nb');
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
      capture.add(bytes('line $i\r\n'));
    }
    final text = capture.text;
    expect(text.length, lessThanOrEqualTo(100));
    expect(text, endsWith('line 99'));
    expect(capture.truncated, isTrue);
  });

  test('keeps reading when the private scrollback overflows', () {
    final capture = OutputCapture(maxLines: 50);
    for (var i = 0; i < 200; i++) {
      capture.add(bytes('line $i\r\n'));
    }
    expect(capture.text, endsWith('line 199'));
    expect(capture.truncated, isTrue);
  });
}
