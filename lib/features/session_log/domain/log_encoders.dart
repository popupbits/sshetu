import 'dart:convert';

import 'ansi_stripper.dart';
import 'log_format.dart';

/// Turns a session's output into the bytes of one log format.
///
/// Every method returns what should be appended to the file, possibly
/// nothing. Encoders are pure — no clock, no file — so the formats can be
/// tested byte for byte; the logger supplies the times.
abstract class SessionLogEncoder {
  /// The encoder for [format].
  factory SessionLogEncoder.forFormat(SessionLogFormat format) =>
      switch (format) {
        SessionLogFormat.plain => PlainLogEncoder(),
        SessionLogFormat.raw => RawLogEncoder(),
        SessionLogFormat.asciicast => AsciicastEncoder(),
      };

  /// What opens the file.
  List<int> header(SessionLogHeader header);

  /// Output from the server, as received. [elapsed] is since [header];
  /// [columns] and [rows] are the terminal's size now.
  List<int> output(
    List<int> bytes, {
    required Duration elapsed,
    required int columns,
    required int rows,
  });

  /// A line the app adds — logging started, the connection dropped, it came
  /// back. [wallClock] is the local time, for the formats that print it.
  List<int> marker(
    String text, {
    required Duration elapsed,
    required DateTime wallClock,
  });

  /// What closes the file: anything still held back.
  List<int> finish();
}

/// What the header of a log records.
class SessionLogHeader {
  const SessionLogHeader({
    required this.title,
    required this.started,
    required this.columns,
    required this.rows,
  });

  /// `user@host`, or the host's label.
  final String title;
  final DateTime started;
  final int columns;
  final int rows;
}

String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Readable text. See [AnsiStripper] for what is removed and why.
class PlainLogEncoder implements SessionLogEncoder {
  final _stripper = AnsiStripper();

  /// Output is decoded here rather than taken from the terminal's decoder:
  /// one tap on the raw bytes serves every format, and the terminal's path is
  /// not touched. A character split across two reads survives, because this
  /// decoder is chunked and lives as long as the log.
  late final _decoder = const Utf8Decoder(allowMalformed: true)
      .startChunkedConversion(_StringCollector(_decoded));
  final _decoded = StringBuffer();

  @override
  List<int> header(SessionLogHeader header) =>
      utf8.encode('# ${header.title} — ${_stamp(header.started)}\n');

  @override
  List<int> output(
    List<int> bytes, {
    required Duration elapsed,
    required int columns,
    required int rows,
  }) {
    _decoder.add(bytes);
    final text = _decoded.toString();
    _decoded.clear();
    if (text.isEmpty) return const [];
    final lines = _stripper.add(text);
    return lines.isEmpty ? const [] : utf8.encode(lines);
  }

  @override
  List<int> marker(
    String text, {
    required Duration elapsed,
    required DateTime wallClock,
  }) {
    // The half-written line goes first, on a line of its own: a marker in
    // the middle of a prompt would read as something the server printed.
    final pending = _stripper.flush();
    return utf8.encode(
      '${pending.isEmpty ? '' : '$pending\n'}'
      '# $text — ${_stamp(wallClock)}\n',
    );
  }

  @override
  List<int> finish() {
    final pending = _stripper.flush();
    return pending.isEmpty ? const [] : utf8.encode('$pending\n');
  }
}

/// The bytes as received. Markers are written as dim lines between two line
/// breaks, so replaying the file with `cat` shows them in place without
/// disturbing the colours around them.
class RawLogEncoder implements SessionLogEncoder {
  @override
  List<int> header(SessionLogHeader header) => const [];

  @override
  List<int> output(
    List<int> bytes, {
    required Duration elapsed,
    required int columns,
    required int rows,
  }) => bytes;

  @override
  List<int> marker(
    String text, {
    required Duration elapsed,
    required DateTime wallClock,
  }) => utf8.encode(
    '\x1b[0m\r\n\x1b[2m[$text — ${_stamp(wallClock)}]\x1b[0m\r\n',
  );

  @override
  List<int> finish() => const [];
}

/// asciicast v2 — <https://docs.asciinema.org/manual/asciicast/v2/>.
///
/// A JSON header line, then one `[seconds, code, data]` line per event:
/// `"o"` for output, `"r"` when the terminal was resized (`"80x24"`), `"m"`
/// for a marker, which players show on the timeline. Each line is valid JSON
/// on its own, so a log cut short by a crash still plays up to where it
/// stopped.
///
/// Timestamps never go backwards: a player takes them as delays, and a
/// negative one is an error.
class AsciicastEncoder implements SessionLogEncoder {
  late final _decoder = const Utf8Decoder(allowMalformed: true)
      .startChunkedConversion(_StringCollector(_decoded));
  final _decoded = StringBuffer();

  var _last = 0.0;
  int? _columns;
  int? _rows;

  @override
  List<int> header(SessionLogHeader header) {
    _columns = header.columns;
    _rows = header.rows;
    return _line({
      'version': 2,
      'width': header.columns,
      'height': header.rows,
      'timestamp': header.started.millisecondsSinceEpoch ~/ 1000,
      'title': header.title,
      'env': {'TERM': 'xterm-256color'},
    });
  }

  @override
  List<int> output(
    List<int> bytes, {
    required Duration elapsed,
    required int columns,
    required int rows,
  }) {
    final out = <int>[];
    final time = _time(elapsed);
    if (columns != _columns || rows != _rows) {
      _columns = columns;
      _rows = rows;
      out.addAll(_line([time, 'r', '${columns}x$rows']));
    }
    _decoder.add(bytes);
    final text = _decoded.toString();
    _decoded.clear();
    if (text.isNotEmpty) out.addAll(_line([time, 'o', text]));
    return out;
  }

  @override
  List<int> marker(
    String text, {
    required Duration elapsed,
    required DateTime wallClock,
  }) => _line([_time(elapsed), 'm', text]);

  @override
  List<int> finish() => const [];

  /// Seconds, to the microsecond asciinema itself records, never less than
  /// the previous event's.
  double _time(Duration elapsed) {
    var t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (t < _last) t = _last;
    _last = t;
    return double.parse(t.toStringAsFixed(6));
  }

  static List<int> _line(Object json) => utf8.encode('${jsonEncode(json)}\n');
}

class _StringCollector implements Sink<String> {
  _StringCollector(this._buffer);

  final StringBuffer _buffer;

  @override
  void add(String data) => _buffer.write(data);

  @override
  void close() {}
}
