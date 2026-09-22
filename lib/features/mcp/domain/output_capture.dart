import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xterm2/core.dart';

/// The session's screen just before something was typed into it: its size,
/// the rows from the top of the screen down to the cursor's row, and where
/// on that row the cursor stood.
///
/// [OutputCapture] replays what the session prints on top of this, so a
/// shell's line editor redrawing the typed line — a carriage return and the
/// prompt again, a cursor move back over the echo, an erase to the end of
/// the line — lands on the same cells it did on the real screen.
class CaptureSeed {
  const CaptureSeed({
    this.columns = 80,
    this.rows = 24,
    this.lines = const [],
    this.cursorX = 0,
  });

  final int columns;
  final int rows;

  /// Screen rows from the top down to the cursor's row. `continues` is true
  /// for a row that carries on the line above it, which the terminal wrapped.
  /// The last is the cursor's row.
  final List<({String text, bool continues})> lines;

  /// The cursor's column on the last row.
  final int cursorX;
}

/// Collects what a session prints after a command was typed, as plain text,
/// and decides when it has stopped printing.
///
/// Screen output, not a command's result: there is no exit status. The
/// bytes are replayed on a private terminal the size of the session's,
/// seeded with its screen ([CaptureSeed]), and the text is read back from
/// the cursor's line down. So the result is what a person would see there:
/// the typed line once — the terminal's echo and the line editor's redraw of
/// it collapse into one — without its prompt, then the output, and without
/// the fresh prompt at the end when it is the one the command was typed at.
class OutputCapture {
  OutputCapture({
    this.maxChars = 64 * 1024,
    this.maxLines = 5000,
    CaptureSeed seed = const CaptureSeed(),
  }) {
    _decoder = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(_DecodedSink(_terminal.write));
    _terminal.resize(math.max(seed.columns, 1), math.max(seed.rows, 1));
    _plant(seed);
  }

  /// The most text returned. A command that prints more keeps its tail — the
  /// end of the output, where any error is.
  final int maxChars;

  /// The most lines the private terminal keeps.
  final int maxLines;

  late final Terminal _terminal = Terminal(
    maxLines: maxLines,
    reflowEnabled: false,
  );
  late final ByteConversionSink _decoder;

  /// Where the line the command was typed on starts in the buffer.
  var _startRow = 0;

  /// That line's text left of the cursor, before anything was typed.
  var _prompt = '';

  bool _received = false;
  bool _truncated = false;
  void Function()? _onData;

  /// Whether anything arrived.
  bool get receivedAny => _received;

  /// Whether output was dropped to stay within [maxChars] or [maxLines].
  bool get truncated => _truncated;

  void _plant(CaptureSeed seed) {
    final width = _terminal.viewWidth;
    final all = seed.lines;
    final lines = all.skip(math.max(all.length - _terminal.viewHeight, 0));
    final list = lines.toList();
    for (var i = 0; i < list.length; i++) {
      var text = _printable(list[i].text);
      final wrapsOn = i + 1 < list.length && list[i + 1].continues;
      if (wrapsOn) {
        // Fill the row so the next character wraps, as it did on screen.
        text = text.padRight(width);
      } else if (i + 1 < list.length) {
        text = '$text\r\n';
      }
      _terminal.write(text);
    }
    final buffer = _terminal.buffer;
    if (list.isNotEmpty) buffer.setCursorX(seed.cursorX);
    var row = buffer.absoluteCursorY;
    while (row > 0 && buffer.lines[row].isWrapped) {
      row--;
    }
    _startRow = row;
    final line = _logicalLine(row).text;
    final left = (buffer.absoluteCursorY - row) * width + buffer.cursorX;
    _prompt = line.length > left
        ? line.substring(0, left)
        : line.padRight(left);
  }

  /// Seed text reaches the terminal as characters only: a control character
  /// in it would be obeyed rather than shown.
  static String _printable(String text) =>
      text.replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), '');

  /// Feed it every chunk the session receives.
  void add(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _received = true;
    _decoder.add(bytes);
    _onData?.call();
  }

  /// Waits until the output has been quiet for [quiet] after the first byte,
  /// or [max] has passed, whichever is first; then returns the text.
  Future<String> settle({
    required Duration max,
    Duration quiet = const Duration(milliseconds: 600),
  }) async {
    if (max > Duration.zero) {
      final done = Completer<void>();
      void finish() {
        if (!done.isCompleted) done.complete();
      }

      Timer? quietTimer;
      void restartQuiet() {
        quietTimer?.cancel();
        quietTimer = Timer(quiet, finish);
      }

      final maxTimer = Timer(max, finish);
      _onData = restartQuiet;
      if (_received) restartQuiet();
      await done.future;
      _onData = null;
      maxTimer.cancel();
      quietTimer?.cancel();
    }
    return text;
  }

  /// What the screen shows from the command's line down, as described on
  /// [OutputCapture]. Each line loses its trailing spaces.
  String get text {
    final buffer = _terminal.buffer;
    var start = _terminal.isUsingAltBuffer ? 0 : _startRow;
    if (buffer.height >= maxLines) {
      // The buffer is full and has been dropping its oldest lines, so the
      // command's line may be gone: read what is left.
      _truncated = true;
      start = 0;
    }
    var end = buffer.height - 1;
    while (end >= start && buffer.lines[end].getText().trim().isEmpty) {
      end--;
    }
    final out = <String>[];
    var row = start;
    while (row <= end) {
      final line = _logicalLine(row);
      out.add(line.text.trimRight());
      row = line.next;
    }
    if (out.isEmpty) return '';

    final prompt = _prompt.trimRight();
    if (prompt.isNotEmpty && start == _startRow) {
      if (out.first.startsWith(_prompt)) {
        out[0] = out.first.substring(_prompt.length);
      } else if (out.first.startsWith(prompt)) {
        out[0] = out.first.substring(prompt.length).trimLeft();
      }
      if (out.length > 1 && out.last == prompt) {
        out.removeLast();
      } else if (out.length > 1 && out.last.endsWith(' $prompt')) {
        // zsh's PROMPT_SP pads a line left without a newline to the edge,
        // so the prompt after it sits on a row the terminal counts as that
        // line wrapping on.
        final rest = out.last.substring(0, out.last.length - prompt.length);
        out.last = rest.trimRight();
      }
    }
    if (out.length > 1 && out.first.trim().isEmpty) out.removeAt(0);

    var result = out.join('\n');
    if (result.length > maxChars) {
      _truncated = true;
      result = result.substring(result.length - maxChars);
    }
    return result;
  }

  /// The line starting at [row], joined across the rows it wrapped onto,
  /// and the row after it.
  ({String text, int next}) _logicalLine(int row) {
    final lines = _terminal.buffer.lines;
    final text = StringBuffer(lines[row].getText());
    var i = row + 1;
    while (i < lines.length && lines[i].isWrapped) {
      text.write(lines[i].getText());
      i++;
    }
    return (text: text.toString(), next: i);
  }
}

class _DecodedSink implements Sink<String> {
  _DecodedSink(this.onText);

  final void Function(String text) onText;

  @override
  void add(String data) => onText(data);

  @override
  void close() {}
}
