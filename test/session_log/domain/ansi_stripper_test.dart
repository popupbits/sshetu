import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/session_log/domain/ansi_stripper.dart';

/// Terminal output in, readable lines out — whole, and split at every byte.
void main() {
  /// Strips [input] in one go, flushing the unfinished line at the end.
  String strip(String input) {
    final s = AnsiStripper();
    return s.add(input) + s.flush();
  }

  /// The same, fed one code point at a time: every escape sequence and every
  /// line is split across chunks somewhere.
  String stripByRune(String input) {
    final s = AnsiStripper();
    final out = StringBuffer();
    for (final rune in input.runes) {
      out.write(s.add(String.fromCharCode(rune)));
    }
    out.write(s.flush());
    return out.toString();
  }

  void expectStrips(String input, String expected) {
    expect(strip(input), expected, reason: 'whole');
    expect(stripByRune(input), expected, reason: 'rune by rune');
  }

  test('SGR colours go, text stays', () {
    expectStrips(
      '\x1b[1;31mred\x1b[0m and \x1b[38;5;208morange\x1b[m\r\n',
      'red and orange\n',
    );
    expectStrips('\x1b[38;2;10;20;30mtrue colour\x1b[0m\n', 'true colour\n');
  });

  test('ls --color output reads as names', () {
    expectStrips(
      '\x1b[0m\x1b[01;34mbin\x1b[0m  \x1b[01;32mrun.sh\x1b[0m\r\n',
      'bin  run.sh\n',
    );
  });

  test('cursor moves between lines are dropped', () {
    expectStrips('a\x1b[2Ab\x1b[10;5Hc\x1b[Bd\r\n', 'abcd\n');
  });

  test('private modes and queries are not text', () {
    expectStrips(
      '\x1b[?25l\x1b[?1049h\x1b[?2004hprompt\x1b[>c\x1b[?25h\n',
      'prompt\n',
    );
  });

  test('OSC 8 links keep their text and lose their target', () {
    expectStrips(
      'see \x1b]8;;https://example.com/a?b=c\x1b\\the docs\x1b]8;;\x1b\\ now\n',
      'see the docs now\n',
    );
    // BEL-terminated, as many programs send it.
    expectStrips('\x1b]8;id=1;https://x.test\x07link\x1b]8;;\x07\n', 'link\n');
  });

  test('OSC titles vanish, whichever terminator', () {
    expectStrips('\x1b]0;user@host: ~\x07\$ ls\n', '\$ ls\n');
    expectStrips('\x1b]2;title\x1b\\\$ \n', '\$ \n');
    expectStrips('\x1b]133;A\x07\$ ok\n', '\$ ok\n');
  });

  test('DCS, APC, PM and SOS strings vanish', () {
    expectStrips('a\x1bP1\$r0m\x1b\\b\n', 'ab\n');
    expectStrips('a\x1bPtmux;\x1b\x1b]0;x\x07\x1b\\b\n', 'ab\n');
    expectStrips(
      'a\x1b_Gf=100;AAAA\x1b\\b\x1b^pm\x1b\\c\x1bXsos\x1b\\d\n',
      'abcd\n',
    );
  });

  test('charset switches take their designator with them', () {
    // The DEC line-drawing set on and off, as `tmux` and `mc` send it.
    expectStrips('\x1b(0lqqk\x1b(B box\n', 'lqqk box\n');
    expectStrips('\x1b)0\x1b*B\x1b+Atext\x1b#8\x1b%G\n', 'text\n');
  });

  test('single-character escapes vanish', () {
    expectStrips(
      '\x1b7save\x1b8\x1b=\x1b>\x1bM\x1bD\x1bE\x1bcok\n',
      'saveok\n',
    );
  });

  test('8-bit C1 forms are recognised too', () {
    String c1(int code) => String.fromCharCode(code);
    final csi = c1(0x9b), osc = c1(0x9d), st = c1(0x9c), dcs = c1(0x90);
    expectStrips(
      '${csi}31mred${csi}m ${osc}0;t${st}ok${dcs}x$st\n',
      'red ok\n',
    );
  });

  test('C0 controls go, except line feed and tab', () {
    expectStrips('a\x07b\x00c\x0ed\x0fe\tf\x7fg\n', 'abcde\tfg\n');
  });

  test('CRLF is one line end, a lone LF another', () {
    expectStrips('one\r\ntwo\nthree\r\n', 'one\ntwo\nthree\n');
    expectStrips('\r\n\r\n', '\n\n');
  });

  test('a progress bar keeps only its final state', () {
    expectStrips(
      '  0% [          ]\r 50% [=====     ]\r100% [==========]\r\ndone\r\n',
      '100% [==========]\ndone\n',
    );
  });

  test('erase-in-line after a carriage return clears the tail', () {
    expectStrips('Downloading file 3 of 10\r\x1b[KDone\r\n', 'Done\n');
    expectStrips('Downloading\r\x1b[2KOK\n', 'OK\n');
    // Without erasing, what was not overwritten remains, as on screen.
    expectStrips('abcdef\rXY\n', 'XYcdef\n');
  });

  test('a spinner drawn with backspaces ends as its last frame', () {
    expectStrips('working |\b/\b-\b\\\bdone\n', 'working done\n');
  });

  test('horizontal cursor moves are applied', () {
    expectStrips('a\x1b[3Cb\n', 'a   b\n');
    expectStrips('abcdef\x1b[3Dxy\n', 'abcxyf\n');
    expectStrips('abcdef\x1b[2GZ\n', 'aZcdef\n');
  });

  test('Devanagari and emoji pass through intact', () {
    expectStrips(
      '\x1b[32mनमस्ते संसार\x1b[0m 👋🏽 👨‍👩‍👧\r\n',
      'नमस्ते संसार 👋🏽 👨‍👩‍👧\n',
    );
  });

  test('lines are emitted only when finished', () {
    final s = AnsiStripper();
    expect(s.add('\$ ech'), '');
    expect(s.add('o hi\r\nhi\r\n\$ '), '\$ echo hi\nhi\n');
    expect(s.flush(), '\$ ');
    expect(s.flush(), '');
  });

  test('an escape split across a flush is still recognised', () {
    final s = AnsiStripper();
    expect(s.add('x\x1b[3'), '');
    expect(s.flush(), 'x');
    expect(s.add('1mred\n'), 'red\n');
  });

  test('a line with no end is cut at the limit rather than growing', () {
    final s = AnsiStripper(maxLineLength: 8);
    expect(s.add('abcdefghij'), 'abcdefgh\n');
    expect(s.flush(), 'ij');
  });

  test('ESC inside a sequence abandons it and starts another', () {
    expectStrips('a\x1b[12\x1b[31mb\n', 'ab\n');
    expectStrips('a\x1b]0;tit\x1b[1mb\n', 'ab\n');
  });
}
