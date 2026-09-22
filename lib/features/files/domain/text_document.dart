import 'dart:convert';
import 'dart:typed_data';

/// The largest file the editor will open: 2 MiB.
///
/// A text field lays out every line it holds, and a multi-megabyte log is
/// not something to edit in one anyway — it is something to `less`. The cap
/// is checked against the server's reported size before a byte is read, and
/// again while reading, since a file can grow in between.
const kMaxEditableBytes = 2 * 1024 * 1024;

/// How the lines of a loaded file end, kept so a save writes them back the
/// way they came.
enum LineEnding {
  /// `\n` throughout, or no line breaks at all.
  lf,

  /// `\r\n` throughout.
  crlf,

  /// Both. Edited as loaded, byte for byte, rather than normalised — turning
  /// a file's mixed endings into one kind is a change nobody asked for, and
  /// a diff of every line is how it would show up.
  mixed,
}

/// Why a file could not be opened as text.
enum TextDecodeFailure {
  /// Contains a NUL byte — the one thing no text file has and nearly every
  /// binary one does.
  binary,

  /// Not valid UTF-8. Could be Latin-1 text, but guessing an encoding and
  /// saving it back as UTF-8 would silently rewrite every non-ASCII byte.
  notUtf8,
}

/// A file decoded for editing, with what is needed to encode it back
/// exactly: its line endings and whether it began with a byte-order mark.
class TextDocument {
  const TextDocument({
    required this.text,
    required this.lineEnding,
    this.hasBom = false,
    this.marksLoneCr = false,
  });

  /// With `\r\n` turned into `\n` for [LineEnding.crlf]; verbatim otherwise,
  /// except for a lone `\r` (see [marksLoneCr]).
  final String text;
  final LineEnding lineEnding;
  final bool hasBom;

  /// Whether each lone `\r` in the file is shown in [text] as [loneCrMark].
  ///
  /// A text field lays a lone carriage return out as a line break, but the
  /// line-number gutter counts line feeds, so every number below one sat
  /// beside the wrong line — and the break itself was invisible, an edit
  /// waiting to go wrong. The mark shows it for what it is, and [encode]
  /// turns it back into `\r`, so an unedited file saves byte for byte. Only
  /// done when the file does not already contain the mark itself.
  final bool marksLoneCr;

  /// How a lone `\r` is shown: U+240D SYMBOL FOR CARRIAGE RETURN.
  static final loneCrMark = String.fromCharCode(0x240D);

  static final _loneCr = RegExp(r'\r(?!\n)');

  /// [edited] (as the editor holds it) back into bytes, with this document's
  /// line endings and byte-order mark restored.
  ///
  /// For [LineEnding.crlf] every `\n` becomes `\r\n` — a line typed into a
  /// CRLF file gets a CRLF like its neighbours. A `\r\n` already present
  /// (pasted in) is left alone rather than doubled.
  Uint8List encode(String edited) {
    final restored = marksLoneCr ? edited.replaceAll(loneCrMark, '\r') : edited;
    final body = switch (lineEnding) {
      LineEnding.crlf => restored.replaceAllMapped(
        RegExp(r'\r?\n'),
        (_) => '\r\n',
      ),
      LineEnding.lf || LineEnding.mixed => restored,
    };
    final bytes = utf8.encode(body);
    if (!hasBom) return bytes;
    return Uint8List.fromList([..._bom, ...bytes]);
  }

  static const _bom = [0xEF, 0xBB, 0xBF];

  /// Decodes [bytes] for editing, or says why it will not.
  static TextDecodeResult decode(Uint8List bytes) {
    if (bytes.contains(0)) {
      return const TextDecodeResult.failure(TextDecodeFailure.binary);
    }
    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == _bom[0] &&
        bytes[1] == _bom[1] &&
        bytes[2] == _bom[2];
    final String raw;
    try {
      raw = utf8.decode(hasBom ? bytes.sublist(3) : bytes);
    } on FormatException {
      return const TextDecodeResult.failure(TextDecodeFailure.notUtf8);
    }
    final ending = detectLineEnding(raw);
    final mark =
        ending == LineEnding.mixed &&
        _loneCr.hasMatch(raw) &&
        !raw.contains(loneCrMark);
    return TextDecodeResult.success(
      TextDocument(
        text: switch (ending) {
          LineEnding.crlf => raw.replaceAll('\r\n', '\n'),
          _ when mark => raw.replaceAll(_loneCr, loneCrMark),
          _ => raw,
        },
        lineEnding: ending,
        hasBom: hasBom,
        marksLoneCr: mark,
      ),
    );
  }
}

/// Which [LineEnding] [text] uses. A lone `\r` (classic Mac) counts as
/// mixed: it is rare enough that preserving it verbatim beats guessing.
LineEnding detectLineEnding(String text) {
  var crlf = 0;
  var lf = 0;
  var loneCr = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x0D) {
      if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) {
        crlf++;
        i++;
      } else {
        loneCr++;
      }
    } else if (unit == 0x0A) {
      lf++;
    }
  }
  if (loneCr > 0 || (crlf > 0 && lf > 0)) return LineEnding.mixed;
  return crlf > 0 ? LineEnding.crlf : LineEnding.lf;
}

/// Either a [TextDocument] or the reason there is not one.
class TextDecodeResult {
  const TextDecodeResult.success(TextDocument this.document) : failure = null;
  const TextDecodeResult.failure(TextDecodeFailure this.failure)
    : document = null;

  final TextDocument? document;
  final TextDecodeFailure? failure;
}
