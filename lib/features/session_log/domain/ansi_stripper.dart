/// Turns terminal output into the text a person would read, one line at a
/// time.
///
/// **Streaming.** Output arrives in arbitrary chunks, and an escape sequence
/// — or a line — can be split across two of them, so the parser keeps its
/// state between [add] calls. Input is *decoded* text: splitting a multi-byte
/// UTF-8 character is the decoder's problem, and is solved before this sees
/// it.
///
/// **What is removed.** Every escape sequence: CSI (`ESC [` … final byte),
/// OSC (`ESC ]` … BEL or ST — titles, OSC 8 hyperlinks, clipboard), DCS, SOS,
/// PM and APC strings (`ESC P`/`X`/`^`/`_` … ST), charset designations
/// (`ESC (` B and friends, which take one more character), the single
/// character escapes (`ESC 7`, `ESC =`, `ESC M` …), their 8-bit C1 forms, and
/// every C0 control except line feed and tab. An OSC 8 link keeps its visible
/// text and loses its target, which is what reading it on screen gives you.
///
/// **Carriage returns.** A lone `\r` returns to the start of the line and
/// what follows *overwrites* it, exactly as on screen, so a progress bar that
/// redraws itself a thousand times is logged as the line it finished on
/// rather than a thousand fragments. `\r\n` is an ordinary line end. Erase in
/// line (`CSI K`), backspace and the horizontal cursor moves (`CSI C`/`D`/`G`)
/// are applied for the same reason — they are how progress bars and spinners
/// redraw. Everything that moves between lines (a full-screen program such as
/// `vim` or `htop`) cannot be flattened into a file of lines; it is dropped,
/// and the result is readable but not a picture of the screen. The raw and
/// asciicast formats exist for that.
///
/// A line is emitted when its line feed arrives — so a prompt waiting for
/// input is written once the command is entered — or by [flush].
class AnsiStripper {
  AnsiStripper({this.maxLineLength = 16 * 1024});

  /// A line longer than this is emitted as it stands and a new one begun, so
  /// a program that prints megabytes without a newline cannot grow the buffer
  /// without bound.
  final int maxLineLength;

  var _state = _State.ground;

  /// The line being built, one code point per cell.
  final List<int> _line = [];

  /// Where the next character lands in [_line].
  var _column = 0;

  /// The current CSI's parameter and intermediate characters.
  final StringBuffer _csi = StringBuffer();

  /// Takes the next chunk of decoded output and returns the complete lines it
  /// finished, each ending in `\n`. Often empty.
  String add(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      _consume(rune, out);
    }
    return out.toString();
  }

  /// Returns the unfinished line, if it has any text, and starts afresh.
  ///
  /// Called before a marker is written and when logging stops, so the last
  /// line — often a prompt — is not lost. Escape state is kept: a sequence
  /// split across the flush is still recognised when its tail arrives.
  String flush() {
    if (_line.isEmpty) return '';
    final text = String.fromCharCodes(_line);
    _line.clear();
    _column = 0;
    return text;
  }

  void _consume(int c, StringBuffer out) {
    switch (_state) {
      case _State.ground:
        _ground(c, out);
      case _State.escape:
        _escape(c, out);
      case _State.escapeIntermediate:
        // ESC ( B and the rest: exactly one more character designates the
        // set. Nothing about it is text.
        if (c == 0x1b) {
          _state = _State.escape;
        } else {
          _state = _State.ground;
        }
      case _State.csi:
        _csiByte(c, out);
      case _State.osc:
        if (c == 0x07 || c == 0x9c) {
          _state = _State.ground;
        } else if (c == 0x1b) {
          _state = _State.oscEscape;
        } else if (c == 0x18 || c == 0x1a) {
          _state = _State.ground;
        }
      case _State.oscEscape:
        // ESC \ is the string terminator. Anything else after ESC ends the
        // string too, and starts a new escape with that character.
        if (c == 0x5c) {
          _state = _State.ground;
        } else {
          _state = _State.escape;
          _escape(c, out);
        }
      case _State.string:
        if (c == 0x9c || c == 0x18 || c == 0x1a) {
          _state = _State.ground;
        } else if (c == 0x1b) {
          _state = _State.stringEscape;
        }
      case _State.stringEscape:
        if (c == 0x5c) {
          _state = _State.ground;
        } else {
          _state = _State.escape;
          _escape(c, out);
        }
    }
  }

  void _ground(int c, StringBuffer out) {
    switch (c) {
      case 0x0a: // LF
        _endLine(out);
      case 0x0d: // CR: back to the start; what follows overwrites.
        _column = 0;
      case 0x08: // BS
        if (_column > 0) _column--;
      case 0x09: // HT, kept: it is how columns line up in plenty of output.
        _put(c, out);
      case 0x1b:
        _state = _State.escape;
      case 0x9b: // 8-bit CSI
        _csi.clear();
        _state = _State.csi;
      case 0x9d: // 8-bit OSC
        _state = _State.osc;
      case 0x90 || 0x98 || 0x9e || 0x9f: // 8-bit DCS, SOS, PM, APC
        _state = _State.string;
      default:
        // The rest of C0, DEL and the rest of C1 are controls, not text.
        if (c < 0x20 || c == 0x7f || (c >= 0x80 && c < 0xa0)) return;
        _put(c, out);
    }
  }

  void _escape(int c, StringBuffer out) {
    switch (c) {
      case 0x5b: // [
        _csi.clear();
        _state = _State.csi;
      case 0x5d: // ]
        _state = _State.osc;
      case 0x50 || 0x58 || 0x5e || 0x5f: // P X ^ _
        _state = _State.string;
      case 0x1b:
        // ESC ESC: the first was abandoned; the second starts over.
        _state = _State.escape;
      case 0x18 || 0x1a: // CAN, SUB: abandon.
        _state = _State.ground;
      default:
        if (c >= 0x20 && c <= 0x2f) {
          // ( ) * + - . / designate a charset, # and % pick a line or
          // coding mode: one more character follows either way.
          _state = _State.escapeIntermediate;
        } else {
          // ESC 7, ESC 8, ESC =, ESC >, ESC M, ESC c, …: complete already.
          _state = _State.ground;
        }
    }
  }

  void _csiByte(int c, StringBuffer out) {
    if (c >= 0x40 && c <= 0x7e) {
      _state = _State.ground;
      _applyCsi(c);
      return;
    }
    if (c >= 0x20 && c <= 0x3f) {
      _csi.writeCharCode(c);
      return;
    }
    switch (c) {
      case 0x1b:
        _state = _State.escape;
      case 0x18 || 0x1a:
        _state = _State.ground;
      default:
        // A C0 control inside a CSI is carried out as if it came before it —
        // what a terminal does — and the sequence carries on.
        if (c < 0x20) _ground(c, out);
    }
  }

  /// The few CSI sequences that change what a *line* reads as.
  void _applyCsi(int finalByte) {
    final params = _csi.toString();
    // Private sequences (`?25l`, `>c`) and anything with intermediates are
    // modes and queries, never text.
    if (params.isNotEmpty && !_isDigitOrSemicolon(params.codeUnitAt(0))) {
      return;
    }
    final first = _firstParam(params);
    switch (finalByte) {
      case 0x4b: // K — erase in line
        switch (first ?? 0) {
          case 0:
            if (_column < _line.length) {
              _line.removeRange(_column, _line.length);
            }
          case 1:
            for (var i = 0; i < _column && i < _line.length; i++) {
              _line[i] = 0x20;
            }
          case 2:
            _line.clear();
        }
      case 0x43: // C — cursor forward
        _column += (first == null || first == 0) ? 1 : first;
      case 0x44: // D — cursor back
        _column -= (first == null || first == 0) ? 1 : first;
        if (_column < 0) _column = 0;
      case 0x47: // G — cursor to column (1-based)
        _column = ((first == null || first == 0) ? 1 : first) - 1;
    }
    if (_column > maxLineLength) _column = maxLineLength;
  }

  static bool _isDigitOrSemicolon(int c) =>
      (c >= 0x30 && c <= 0x39) || c == 0x3b;

  static int? _firstParam(String params) {
    if (params.isEmpty) return null;
    final end = params.indexOf(';');
    final head = end < 0 ? params : params.substring(0, end);
    return head.isEmpty ? null : int.tryParse(head);
  }

  void _put(int c, StringBuffer out) {
    if (_column < _line.length) {
      _line[_column] = c;
    } else {
      // A cursor moved past the end leaves blanks, as on screen.
      while (_line.length < _column) {
        _line.add(0x20);
      }
      _line.add(c);
    }
    _column++;
    if (_line.length >= maxLineLength) _endLine(out);
  }

  void _endLine(StringBuffer out) {
    out
      ..write(String.fromCharCodes(_line))
      ..write('\n');
    _line.clear();
    _column = 0;
  }
}

enum _State {
  ground,
  escape,
  escapeIntermediate,
  csi,
  osc,
  oscEscape,
  string,
  stringEscape,
}
