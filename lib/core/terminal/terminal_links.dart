import 'package:xterm2/xterm.dart';

/// Links in terminal output: which ones may be opened, and finding one under a
/// cell.
///
/// The remote side decides what text — and which OSC 8 targets — appear in the
/// buffer, so a link is untrusted input. Only the schemes a browser or mail
/// client handles are opened. `file:` would open whatever a server named on
/// *this* machine, and a custom scheme hands an arbitrary string to whichever
/// app registered it; neither is something a click in a terminal should do.
abstract final class TerminalLinks {
  /// The schemes [openable] accepts.
  static const allowedSchemes = {'http', 'https', 'mailto'};

  /// [raw] as a [Uri] if it is safe to hand to the platform, else null.
  ///
  /// http and https need a host; mailto needs an address. A scheme outside
  /// [allowedSchemes] is refused however well-formed it is.
  static Uri? openable(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    // A control character or whitespace inside a URL is not something a
    // browser would accept from a user either.
    if (text.runes.any((c) => c <= 0x20 || c == 0x7f)) return null;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (!allowedSchemes.contains(scheme)) return null;
    if (scheme == 'mailto') return uri.path.isEmpty ? null : uri;
    return uri.host.isEmpty ? null : uri;
  }

  static final _plainUrl = RegExp(r'''https?://[^\s<>"'`]+''');

  /// The http(s) URL in [text] that covers index [index], if any.
  ///
  /// Trailing punctuation belongs to the sentence, not the link: in
  /// "see https://example.com." the full stop is not part of the address, and
  /// in "(https://example.com)" neither is the closing bracket.
  static String? plainUrlAt(String text, int index) {
    for (final match in _plainUrl.allMatches(text)) {
      if (match.start > index) break;
      final url = _trimTrailing(match.group(0)!);
      if (index < match.start + url.length) return url;
    }
    return null;
  }

  static String _trimTrailing(String url) {
    var end = url.length;
    while (end > 0) {
      final c = url[end - 1];
      if ('.,;:!?\'"'.contains(c)) {
        end--;
        continue;
      }
      final open = switch (c) {
        ')' => '(',
        ']' => '[',
        '}' => '{',
        _ => null,
      };
      if (open != null) {
        final body = url.substring(0, end);
        final opens = open.allMatches(body).length;
        final closes = c.allMatches(body).length;
        if (closes > opens) {
          end--;
          continue;
        }
      }
      break;
    }
    return url.substring(0, end);
  }

  /// The link at [cell]: the OSC 8 target the program attached to it, or else
  /// a plain http(s) URL printed across it.
  ///
  /// The plain-URL search spans soft-wrapped rows, so a long URL that wrapped
  /// at the window edge is still found whole. Nothing here decides whether the
  /// link may be opened — pass the result through [openable].
  static String? linkAt(Terminal terminal, CellOffset cell) {
    final hyperlink = terminal.hyperlinkAt(cell);
    if (hyperlink != null) return hyperlink;
    return plainUrlAtCell(terminal.buffer, cell);
  }

  /// The plain http(s) URL printed across [cell] in [buffer], if any.
  static String? plainUrlAtCell(Buffer buffer, CellOffset cell) {
    final lines = buffer.lines;
    if (cell.y < 0 || cell.y >= lines.length) return null;

    var first = cell.y;
    while (first > 0 && lines[first].isWrapped) {
      first--;
    }
    var last = cell.y;
    while (last + 1 < lines.length && lines[last + 1].isWrapped) {
      last++;
    }

    final text = StringBuffer();
    int? target;
    for (var y = first; y <= last; y++) {
      final line = lines[y];
      final end = y < last
          ? buffer.viewWidth
          : line.getTrimmedLength(buffer.viewWidth);
      for (var x = 0; x < end; x++) {
        final width = line.getWidth(x);
        final isWideSpacer = width == 0 && x > 0 && line.getWidth(x - 1) == 2;
        if (y == cell.y && x == cell.x) {
          target = isWideSpacer ? text.length - 1 : text.length;
        }
        if (isWideSpacer) continue;
        final codePoint = line.getCodePoint(x);
        text.writeCharCode(codePoint == 0 ? 0x20 : codePoint);
      }
    }
    if (target == null || target < 0) return null;
    return plainUrlAt(text.toString(), target);
  }
}
