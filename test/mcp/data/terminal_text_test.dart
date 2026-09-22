import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/data/terminal_text.dart';
import 'package:sshetu/features/mcp/domain/output_capture.dart';
import 'package:xterm2/xterm.dart';

void main() {
  seedTests();

  Terminal terminal({int width = 20}) =>
      Terminal(maxLines: 1000)..resize(width, 5);

  test('the last lines, without trailing blank rows or spaces', () {
    final t = terminal()..write('one\r\ntwo   \r\nthree\r\n\$ ');
    expect(terminalTail(t, 100), 'one\ntwo\nthree\n\$');
    expect(terminalTail(t, 2), 'three\n\$');
  });

  test('a wrapped line reads as the line that was printed', () {
    final t = terminal(width: 10)..write('0123456789abcdefghij-end\r\nnext');
    expect(terminalTail(t, 10), '0123456789abcdefghij-end\nnext');
    expect(terminalTail(t, 1), 'next');
  });

  test('reaches into the scrollback', () {
    final t = terminal();
    for (var i = 0; i < 50; i++) {
      t.write('row $i\r\n');
    }
    final tail = terminalTail(t, 30).split('\n');
    expect(tail, hasLength(30));
    expect(tail.first, 'row 20');
    expect(tail.last, 'row 49');
  });

  test('an empty terminal is empty text', () {
    expect(terminalTail(terminal(), 10), '');
  });
}

void seedTests() {
  Terminal terminal({int width = 20}) =>
      Terminal(maxLines: 1000)..resize(width, 5);

  test('a capture seed is the screen down to the cursor, cut at it', () {
    final t = terminal(width: 10)
      ..write('old output\r\n0123456789ab\r\n% ')
      // A right-hand prompt drawn past the cursor, and the cursor put back.
      ..write('\x1b[8G[~]\x1b[3G');
    final seed = captureSeed(t);
    expect(seed.columns, 10);
    expect(seed.rows, 5);
    expect(seed.cursorX, 2);
    expect(seed.lines.last.text, '% ');
    expect(seed.lines.map((l) => l.continues), [false, false, true, false]);
  });

  test('a command typed at the seeded prompt reads back once', () {
    final t = terminal(width: 40)..write('dl@box ~ % ');
    final capture = OutputCapture(seed: captureSeed(t))
      ..add(utf8.encode('echo hi'))
      ..add(utf8.encode('\r\x1b[11Cecho hi\r\nhi\r\ndl@box ~ % '));
    expect(capture.text, 'echo hi\nhi');
  });
}
