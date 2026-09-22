import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/terminal/terminal_links.dart';
import 'package:xterm2/xterm.dart';

/// Which links a click in the terminal may open, and finding them.
///
/// The server decides what appears in the buffer, so a link is untrusted
/// input: the scheme policy is the part of this feature that matters most.
void main() {
  group('the scheme policy', () {
    for (final ok in [
      'http://example.com',
      'https://example.com/path?q=1#frag',
      'HTTPS://EXAMPLE.COM',
      'https://user@example.com:8443/x',
      'mailto:someone@example.com',
      'mailto:someone@example.com?subject=hi',
      '  https://example.com  ',
    ]) {
      test('opens $ok', () {
        expect(TerminalLinks.openable(ok), isNotNull);
      });
    }

    for (final refused in [
      'file:///etc/passwd',
      'file://C:/Windows/System32/cmd.exe',
      'javascript:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      'vbscript:msgbox',
      'ssh://host',
      'ftp://example.com',
      'smb://server/share',
      'x-custom-app://do-something',
      'ms-settings:privacy',
      'intent://scan/#Intent;scheme=zxing;end',
      'tel:+15551234',
      'about:blank',
      '/etc/passwd',
      'example.com',
      'https://',
      'http:///path-only',
      'mailto:',
      '',
      '   ',
      'https://exa mple.com',
      'https://example.com/\nrm',
      'https://example.com/\x1b[31m',
    ]) {
      test('refuses ${refused.replaceAll('\n', r'\n')}', () {
        expect(TerminalLinks.openable(refused), isNull);
      });
    }

    test('the allowed set is exactly http, https and mailto', () {
      expect(TerminalLinks.allowedSchemes, {'http', 'https', 'mailto'});
    });
  });

  group('finding a plain URL in text', () {
    const text = 'see https://example.com/a_(b). and http://x.io, done';

    test('finds the URL under an index inside it', () {
      expect(
        TerminalLinks.plainUrlAt(text, text.indexOf('example')),
        'https://example.com/a_(b)',
      );
      expect(
        TerminalLinks.plainUrlAt(text, text.indexOf('x.io')),
        'http://x.io',
      );
    });

    test('trailing punctuation is not part of the link', () {
      expect(
        TerminalLinks.plainUrlAt('go to https://example.com.', 10),
        'https://example.com',
      );
      expect(
        TerminalLinks.plainUrlAt('(https://example.com/x)', 3),
        'https://example.com/x',
      );
    });

    test('balanced brackets are kept', () {
      expect(
        TerminalLinks.plainUrlAt('https://en.wikipedia.org/wiki/A_(b)', 0),
        'https://en.wikipedia.org/wiki/A_(b)',
      );
    });

    test('nothing outside a URL', () {
      expect(TerminalLinks.plainUrlAt(text, 0), isNull);
      expect(TerminalLinks.plainUrlAt(text, text.indexOf('done')), isNull);
      // On the full stop that was trimmed off.
      expect(TerminalLinks.plainUrlAt(text, text.indexOf('. and')), isNull);
    });

    test('only http and https are detected in plain text', () {
      expect(TerminalLinks.plainUrlAt('file:///etc/passwd', 3), isNull);
      expect(TerminalLinks.plainUrlAt('javascript:alert(1)', 3), isNull);
    });
  });

  group('finding a link in the buffer', () {
    test('a plain URL under a cell', () {
      final terminal = Terminal()..write('curl https://example.com/api now');
      final url = TerminalLinks.linkAt(terminal, const CellOffset(10, 0));
      expect(url, 'https://example.com/api');
      expect(TerminalLinks.linkAt(terminal, const CellOffset(1, 0)), isNull);
    });

    test('a URL that wrapped at the window edge is found whole', () {
      final terminal = Terminal()..resize(20, 5);
      terminal.write('xx https://example.com/a/long/path end');
      // Row 1 is the continuation of row 0.
      expect(terminal.buffer.lines[1].isWrapped, isTrue);
      expect(
        TerminalLinks.plainUrlAtCell(terminal.buffer, const CellOffset(2, 1)),
        'https://example.com/a/long/path',
      );
      expect(
        TerminalLinks.plainUrlAtCell(terminal.buffer, const CellOffset(5, 0)),
        'https://example.com/a/long/path',
      );
    });

    test('an OSC 8 hyperlink wins over the visible text', () {
      final terminal = Terminal()
        ..write('\x1b]8;;https://example.com/real\x1b\\click me\x1b]8;;\x1b\\');
      expect(
        TerminalLinks.linkAt(terminal, const CellOffset(2, 0)),
        'https://example.com/real',
      );
    });

    test('an OSC 8 target with a refused scheme is found, then refused', () {
      final terminal = Terminal()
        ..write('\x1b]8;;file:///etc/shadow\x1b\\docs\x1b]8;;\x1b\\');
      final link = TerminalLinks.linkAt(terminal, const CellOffset(1, 0));
      expect(link, 'file:///etc/shadow');
      expect(TerminalLinks.openable(link!), isNull);
    });

    test('a cell past the buffer is not a link', () {
      final terminal = Terminal()..write('https://example.com');
      expect(TerminalLinks.linkAt(terminal, const CellOffset(0, 99)), isNull);
    });
  });
}
