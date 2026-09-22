/// Cleaning clipboard text before it is typed into a remote shell.
///
/// A paste is keystrokes someone else chose. Text copied from a web page can
/// carry characters nobody sees — terminal control bytes, an escape sequence
/// that ends bracketed paste early (`ESC [ 201 ~`) so the rest of the payload
/// runs as typed commands, or bidirectional overrides that make
/// `rm -rf ~/ #safe` display as something harmless ("Trojan Source"). This
/// module removes all of those and reports how many it removed, so the UI can
/// say so rather than silently rewriting what the user copied.
///
/// Pure on purpose: no Flutter, no terminal. Every rule here is pinned by
/// `test/core/terminal/paste_sanitizer_test.dart`.
library;

/// The result of [sanitizePaste].
class SanitizedPaste {
  const SanitizedPaste({required this.text, required this.removedCount});

  /// What is safe to send. Line endings are `\r` or `\n`; `\r\n` has already
  /// been folded into `\r`.
  final String text;

  /// How many code points were removed. Folding `\r\n` into `\r` is not
  /// counted: nothing hidden was dropped there, only a line ending rewritten.
  final int removedCount;

  /// Whether pasting this would press Enter at least once — i.e. run a
  /// command at a plain shell prompt.
  bool get executes => text.contains('\n') || text.contains('\r');

  /// The pasted text split into lines. A single trailing line ending does not
  /// add an empty last line: `ls\n` is one line (that runs), not two.
  List<String> get lines {
    final parts = text.split(_lineBreak);
    if (parts.length > 1 && parts.last.isEmpty) parts.removeLast();
    return parts;
  }

  static final _lineBreak = RegExp('\r|\n');
}

/// Removes everything from [raw] that should never reach a shell from a paste.
///
/// - C0 controls other than tab, line feed and carriage return; DEL; and the
///   C1 controls U+0080–U+009F.
/// - Whole escape sequences — CSI, OSC, DCS, SOS, PM and APC strings, and the
///   short `ESC x` forms — not just their ESC, so no half-sequence survives
///   as literal text. The 8-bit C1 introducers are treated the same way.
/// - Bidirectional overrides and isolates (U+202A–U+202E, U+2066–U+2069),
///   the LRM/RLM/ALM marks (U+200E, U+200F, U+061C), and the invisible
///   U+200B, U+2060 and U+FEFF.
///
/// **ZWJ (U+200D) and ZWNJ (U+200C) are kept.** They are invisible too, but
/// they carry meaning: emoji sequences are joined with ZWJ, and Devanagari
/// (Nepali, Hindi) uses both to choose between a conjunct and a half form.
/// Stripping them would corrupt ordinary text in the scripts this app's users
/// write.
///
/// Finally `\r\n` becomes `\r`, the single Enter a terminal sends.
SanitizedPaste sanitizePaste(String raw) {
  final runes = raw.runes.toList(growable: false);
  final out = StringBuffer();
  var removed = 0;
  var i = 0;

  while (i < runes.length) {
    final c = runes[i];

    if (c == _esc) {
      final end = _escapeSequenceEnd(runes, i + 1);
      removed += end - i;
      i = end;
      continue;
    }
    // 8-bit introducers: the same sequences as their ESC forms.
    if (c == _c1Csi) {
      final end = _csiEnd(runes, i + 1);
      removed += end - i;
      i = end;
      continue;
    }
    if (_c1StringIntroducers.contains(c)) {
      final end = _stringEnd(runes, i + 1);
      removed += end - i;
      i = end;
      continue;
    }

    if (c == _cr && i + 1 < runes.length && runes[i + 1] == _lf) {
      out.writeCharCode(_cr);
      i += 2;
      continue;
    }

    if (_isStripped(c)) {
      removed++;
    } else {
      out.writeCharCode(c);
    }
    i++;
  }

  return SanitizedPaste(text: out.toString(), removedCount: removed);
}

const _esc = 0x1b;
const _bel = 0x07;
const _cr = 0x0d;
const _lf = 0x0a;
const _tab = 0x09;
const _c1Csi = 0x9b;
const _c1St = 0x9c;

/// DCS, SOS, OSC, PM, APC in their 8-bit form.
const _c1StringIntroducers = {0x90, 0x98, 0x9d, 0x9e, 0x9f};

/// `P`, `X`, `]`, `^`, `_` after ESC: the sequences that run to a terminator.
const _stringIntroducers = {0x50, 0x58, 0x5d, 0x5e, 0x5f};

bool _isStripped(int c) {
  if (c < 0x20) return c != _tab && c != _lf && c != _cr;
  if (c == 0x7f) return true;
  if (c >= 0x80 && c <= 0x9f) return true;
  if (c >= 0x202a && c <= 0x202e) return true;
  if (c >= 0x2066 && c <= 0x2069) return true;
  return c == 0x200e ||
      c == 0x200f ||
      c == 0x061c ||
      c == 0x200b ||
      c == 0x2060 ||
      c == 0xfeff;
}

/// Index just past the escape sequence whose ESC sits before [start].
int _escapeSequenceEnd(List<int> runes, int start) {
  if (start >= runes.length) return start;
  final next = runes[start];
  if (next == 0x5b) return _csiEnd(runes, start + 1); // [
  if (_stringIntroducers.contains(next)) return _stringEnd(runes, start + 1);

  // nF: intermediates, then one final byte (`ESC ( B`, `ESC # 8`).
  var i = start;
  while (i < runes.length && runes[i] >= 0x20 && runes[i] <= 0x2f) {
    i++;
  }
  if (i < runes.length && runes[i] >= 0x30 && runes[i] <= 0x7e) return i + 1;
  // A lone ESC, or ESC followed by something that is not part of a sequence:
  // drop the ESC and whatever intermediates it had, keep the rest.
  return i;
}

/// Index just past a CSI whose introducer ends before [start]: parameter
/// bytes, intermediate bytes, then a final byte. An unterminated CSI is
/// removed as far as it got.
int _csiEnd(List<int> runes, int start) {
  var i = start;
  while (i < runes.length && runes[i] >= 0x30 && runes[i] <= 0x3f) {
    i++;
  }
  while (i < runes.length && runes[i] >= 0x20 && runes[i] <= 0x2f) {
    i++;
  }
  if (i < runes.length && runes[i] >= 0x40 && runes[i] <= 0x7e) return i + 1;
  return i;
}

/// Index just past a control string's terminator — BEL, ST (`ESC \`) or the
/// 8-bit ST. An unterminated string runs to the end of the paste: whatever
/// follows it is the string's payload, and none of it was meant to be seen.
int _stringEnd(List<int> runes, int start) {
  var i = start;
  while (i < runes.length) {
    final c = runes[i];
    if (c == _bel || c == _c1St) return i + 1;
    if (c == _esc) {
      if (i + 1 < runes.length && runes[i + 1] == 0x5c) return i + 2;
      return i + 1;
    }
    i++;
  }
  return i;
}
