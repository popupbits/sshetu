import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/paste_sanitizer.dart';

/// What reaches a remote shell from the clipboard.
///
/// Two failure directions, both pinned: letting something through that can
/// run or rewrite commands, and stripping something ordinary text needs — the
/// second is the one that would quietly corrupt Nepali and emoji for every
/// user who pastes them.
void main() {
  String clean(String raw) => sanitizePaste(raw).text;
  int removed(String raw) => sanitizePaste(raw).removedCount;

  group('ordinary text is untouched', () {
    for (final text in [
      'ls -la',
      'echo "hello, world" | grep -o world',
      "awk '{print \$1}' /etc/passwd",
      'tab\tseparated',
      'naïve café — “quotes” ½ ± ©',
      '日本語のテキスト',
      'Ελληνικά and Кириллица',
    ]) {
      test(text, () {
        expect(clean(text), text);
        expect(removed(text), 0);
      });
    }
  });

  group('scripts that depend on joiners keep them', () {
    test('Devanagari with ZWJ keeps the half form', () {
      // क्\u200dष — KA + VIRAMA + ZWJ + SSA: the explicit half-KA spelling.
      const text = 'क्\u200dष';
      expect(clean(text), text);
      expect(removed(text), 0);
    });

    test('Devanagari with ZWNJ keeps the non-conjunct form', () {
      // क्\u200cष — KA + VIRAMA + ZWNJ + SSA: visible virama, no conjunct.
      const text = 'क्\u200cष';
      expect(clean(text), text);
      expect(removed(text), 0);
    });

    test('a Nepali sentence survives whole', () {
      const text = 'नमस्ते, म ठिक छु। र्\u200dयाल र्\u200c';
      expect(clean(text), text);
      expect(removed(text), 0);
    });

    test('emoji ZWJ sequences stay joined', () {
      const family = '\u{1F468}\u200d\u{1F469}\u200d\u{1F467}\u200d\u{1F466}';
      const rainbowFlag = '\u{1F3F3}\ufe0f\u200d\u{1F308}';
      const technologist = '\u{1F9D1}\u{1F3FD}\u200d\u{1F4BB}';
      for (final text in [family, rainbowFlag, technologist]) {
        expect(clean('echo $text'), 'echo $text');
        expect(removed(text), 0);
      }
    });

    test('variation selectors and combining marks stay', () {
      const text = 'e\u0301 ❤\ufe0f';
      expect(clean(text), text);
    });
  });

  group('C0, DEL and C1 controls', () {
    test('keeps tab, line feed and carriage return', () {
      expect(clean('a\tb\nc\rd'), 'a\tb\nc\rd');
    });

    test('strips every other C0 control', () {
      for (var c = 0; c < 0x20; c++) {
        if (c == 0x09 || c == 0x0a || c == 0x0d || c == 0x1b) continue;
        final raw = 'a${String.fromCharCode(c)}b';
        expect(clean(raw), 'ab', reason: 'U+${c.toRadixString(16)}');
        expect(removed(raw), 1);
      }
    });

    test('strips the ones that act on a line at a prompt', () {
      // ^U kills the line, ^W a word, ^C interrupts, ^D ends the shell,
      // ^V makes the next byte literal.
      expect(clean('safe\x15rm -rf /\x03\x04\x17\x16'), 'saferm -rf /');
    });

    test('strips DEL', () {
      expect(clean('ab\x7fc'), 'abc');
      expect(removed('ab\x7fc'), 1);
    });

    test('strips C1 controls U+0080 to U+009F', () {
      for (var c = 0x80; c <= 0x9f; c++) {
        final raw = 'a${String.fromCharCode(c)}b';
        final result = sanitizePaste(raw);
        expect(
          result.text.runes.any((r) => r >= 0x80 && r <= 0x9f),
          isFalse,
          reason: 'U+${c.toRadixString(16)}',
        );
        expect(result.text.startsWith('a'), isTrue);
      }
    });

    test('keeps U+00A0 and above', () {
      expect(clean('a\u00a0b'), 'a\u00a0b');
    });
  });

  group('escape sequences are removed whole', () {
    test('the bracketed-paste terminator cannot end the paste early', () {
      const raw = 'echo hi\x1b[201~rm -rf ~\n';
      final result = sanitizePaste(raw);
      expect(result.text, 'echo hirm -rf ~\n');
      expect(result.text.contains('\x1b'), isFalse);
      expect(result.text.contains('[201~'), isFalse);
      expect(result.removedCount, 6);
    });

    test('the bracketed-paste opener too', () {
      expect(clean('\x1b[200~ls'), 'ls');
    });

    test('SGR colour sequences', () {
      expect(clean('\x1b[1;31mred\x1b[0m'), 'red');
    });

    test('CSI with private parameters and intermediates', () {
      expect(clean('a\x1b[?1049hb'), 'ab');
      expect(clean('a\x1b[2 qb'), 'ab');
    });

    test('an unterminated CSI at the end', () {
      expect(clean('ls\x1b[12;'), 'ls');
    });

    test('OSC terminated by BEL', () {
      expect(clean('\x1b]0;evil title\x07ok'), 'ok');
    });

    test('OSC terminated by ST', () {
      expect(clean('\x1b]52;c;cm0gLXJmIH4=\x1b\\ok'), 'ok');
    });

    test('an OSC 8 hyperlink keeps its visible text only', () {
      expect(
        clean('\x1b]8;;https://example.com\x1b\\click\x1b]8;;\x1b\\'),
        'click',
      );
    });

    test('an unterminated OSC swallows the rest', () {
      final result = sanitizePaste('ok\x1b]0;never ends\nrm -rf /');
      expect(result.text, 'ok');
    });

    test('DCS, SOS, PM and APC strings', () {
      expect(clean('a\x1bPq#0;2;0;0;0\x1b\\b'), 'ab');
      expect(clean('a\x1bXsos\x1b\\b'), 'ab');
      expect(clean('a\x1b^pm\x1b\\b'), 'ab');
      expect(clean('a\x1b_apc\x1b\\b'), 'ab');
    });

    test('two-character and nF escapes', () {
      expect(clean('a\x1bcb'), 'ab', reason: 'RIS, full reset');
      expect(clean('a\x1b7b\x1b8c'), 'abc', reason: 'save/restore cursor');
      expect(clean('a\x1b(Bb'), 'ab', reason: 'designate charset');
      expect(clean('a\x1b#8b'), 'ab', reason: 'DECALN');
    });

    test('a lone ESC at the end', () {
      expect(clean('ls\x1b'), 'ls');
      expect(removed('ls\x1b'), 1);
    });

    test('ESC followed by a line break keeps the line break', () {
      expect(clean('a\x1b\nb'), 'a\nb');
    });

    test('8-bit CSI and OSC introducers', () {
      expect(clean('a\u009b201~b'), 'ab');
      expect(clean('a\u009d0;title\u009cb'), 'ab');
      expect(clean('a\u009d0;title\x07b'), 'ab');
    });
  });

  group('bidi controls and invisible characters', () {
    test('strips the overrides and embeddings', () {
      for (var c = 0x202a; c <= 0x202e; c++) {
        final raw = 'a${String.fromCharCode(c)}b';
        expect(clean(raw), 'ab', reason: 'U+${c.toRadixString(16)}');
      }
    });

    test('strips the isolates', () {
      for (var c = 0x2066; c <= 0x2069; c++) {
        final raw = 'a${String.fromCharCode(c)}b';
        expect(clean(raw), 'ab', reason: 'U+${c.toRadixString(16)}');
      }
    });

    test('strips LRM, RLM and ALM', () {
      expect(clean('a\u200eb\u200fc\u061cd'), 'abcd');
    });

    test('strips zero-width space, word joiner and BOM', () {
      expect(clean('\ufeffr\u200bm \u2060-rf'), 'rm -rf');
      expect(removed('\ufeffr\u200bm \u2060-rf'), 3);
    });

    test('a Trojan Source line shows what it really does', () {
      // Displays as `ls #\u202e; rm -rf ~` reversed; runs `rm -rf ~`.
      const raw = 'ls #\u202e ~ fr- mr ;\u2066';
      expect(clean(raw), 'ls # ~ fr- mr ;');
      expect(removed(raw), 2);
    });

    test('keeps Arabic and Hebrew text itself', () {
      const text = 'echo مرحبا שלום';
      expect(clean(text), text);
    });
  });

  group('line endings', () {
    test('CRLF becomes CR', () {
      expect(clean('one\r\ntwo\r\n'), 'one\rtwo\r');
    });

    test('folding CRLF is not counted as a removal', () {
      expect(removed('one\r\ntwo\r\n'), 0);
    });

    test('lone LF and lone CR are kept', () {
      expect(clean('a\nb\rc'), 'a\nb\rc');
    });

    test('LF CR is not CRLF', () {
      expect(clean('a\n\rb'), 'a\n\rb');
    });
  });

  group('executes and lines', () {
    test('a single line does not execute', () {
      expect(sanitizePaste('ls -la').executes, isFalse);
    });

    test('a trailing newline executes', () {
      final result = sanitizePaste('ls -la\n');
      expect(result.executes, isTrue);
      expect(result.lines, ['ls -la']);
    });

    test('CRLF text executes and splits into its lines', () {
      final result = sanitizePaste('one\r\ntwo\r\nthree');
      expect(result.executes, isTrue);
      expect(result.lines, ['one', 'two', 'three']);
    });

    test('a newline hidden inside an escape sequence does not execute', () {
      final result = sanitizePaste('ls\x1b]0;x\ny\x07');
      expect(result.text, 'ls');
      expect(result.executes, isFalse);
    });

    test('empty lines in the middle are kept', () {
      expect(sanitizePaste('a\n\nb').lines, ['a', '', 'b']);
    });

    test('text made only of controls sanitises to nothing', () {
      final result = sanitizePaste('\x1b[201~\u202e\x00');
      expect(result.text, isEmpty);
      expect(result.removedCount, 8);
    });
  });
}
