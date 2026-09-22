import 'package:xterm2/xterm.dart';

import '../domain/output_capture.dart';

/// The bottom [lines] lines of [terminal]'s buffer — scrollback and screen —
/// as plain text, one per line.
///
/// A line the terminal wrapped because it was wider than the window is one
/// line here, as it was printed. Trailing blank rows under the cursor are
/// left out, and each line loses its trailing spaces; nothing else is
/// changed. It reads whichever buffer is showing, so under a full-screen
/// program it is that program's screen.
String terminalTail(Terminal terminal, int lines) {
  final rows = terminal.buffer.lines;
  var i = rows.length - 1;
  while (i >= 0 && !rows[i].isWrapped && rows[i].getText().trim().isEmpty) {
    i--;
  }
  final out = <String>[];
  while (i >= 0 && out.length < lines) {
    final parts = [rows[i].getText()];
    while (rows[i].isWrapped && i > 0) {
      i--;
      parts.insert(0, rows[i].getText());
    }
    out.add(parts.join().trimRight());
    i--;
  }
  return out.reversed.join('\n');
}

/// [terminal]'s screen as an [OutputCapture] starts from: its size, the rows
/// from the top of the screen down to the cursor's, and the cursor's column.
/// The cursor's row is cut at the cursor, so a right-hand prompt past it is
/// not taken for part of the line.
CaptureSeed captureSeed(Terminal terminal) {
  final buffer = terminal.buffer;
  final top = buffer.scrollBack.clamp(0, buffer.height);
  final cursorRow = buffer.absoluteCursorY.clamp(0, buffer.height - 1);
  return CaptureSeed(
    columns: terminal.viewWidth,
    rows: terminal.viewHeight,
    cursorX: buffer.cursorX,
    lines: [
      for (var i = top; i <= cursorRow; i++)
        (
          text: i == cursorRow
              ? buffer.lines[i].getText(0, buffer.cursorX)
              : buffer.lines[i].getText(),
          continues: buffer.lines[i].isWrapped,
        ),
    ],
  );
}
