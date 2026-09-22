import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/data/terminal_text.dart';
import 'package:xterm2/xterm.dart';

void main() {
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
