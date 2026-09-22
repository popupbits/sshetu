import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'log_encoders.dart';

/// Where a log's bytes go. A file in the app; a list in tests.
abstract interface class SessionLogSink {
  /// Appends [bytes]. Calls are never overlapped: the logger waits for each
  /// to finish before starting the next.
  Future<void> write(List<int> bytes);

  Future<void> close();
}

/// Opens the sink for a log at [path].
typedef SessionLogSinkFactory = Future<SessionLogSink> Function(String path);

/// A [SessionLogSink] over a file, written with [RandomAccessFile] so every
/// write happens off the UI thread and completes before the next begins.
///
/// Not an `IOSink`: an `IOSink` refuses `add` while a `flush` is pending,
/// which a periodic flush racing a burst of output would hit, and its errors
/// surface somewhere other than the call that caused them.
class FileSessionLogSink implements SessionLogSink {
  FileSessionLogSink._(this._file);

  /// Creates [path], replacing whatever was there — the save dialog has
  /// already asked about that — and opens it for appending.
  static Future<SessionLogSink> open(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return FileSessionLogSink._(await file.open(mode: FileMode.write));
  }

  final RandomAccessFile _file;

  @override
  Future<void> write(List<int> bytes) async {
    await _file.writeFrom(bytes);
  }

  @override
  Future<void> close() async {
    try {
      await _file.flush();
    } finally {
      await _file.close();
    }
  }
}

/// Size at which a log is flagged as large.
///
/// A warning, not a cap: stopping a log on its own would lose exactly the
/// output someone was keeping it for, and silently. 100 MB is far past any
/// ordinary session — a day of `tail -f` on a busy service — so reaching it
/// usually means something is streaming that nobody meant to keep, and the
/// indicator turning red says so. Not a setting: one more number to
/// configure buys nothing the warning does not.
const int kSessionLogWarnBytes = 100 * 1024 * 1024;

/// How often buffered output is written out.
///
/// Output is gathered in memory and written at most this often, or sooner
/// when [kSessionLogFlushBytes] have piled up, so a busy session makes a few
/// large writes rather than thousands of small ones. It is also the most a
/// crash can lose.
const Duration kSessionLogFlushInterval = Duration(seconds: 1);

/// Buffered bytes that trigger a write before the interval is up.
const int kSessionLogFlushBytes = 64 * 1024;

/// Creates a periodic timer; replaced in tests.
typedef SessionLogTimerFactory = Timer Function(
  Duration interval,
  void Function(Timer timer) tick,
);

/// One running log: output in, bytes to a [SessionLogSink] out.
///
/// Knows nothing of sessions or Riverpod — the controller feeds it — so its
/// life-cycle is testable with a fake sink and a hand-cranked clock.
class SessionLogger {
  SessionLogger({
    required this.encoder,
    required this.sink,
    this.warnBytes = kSessionLogWarnBytes,
    this.flushBytes = kSessionLogFlushBytes,
    Duration flushInterval = kSessionLogFlushInterval,
    SessionLogTimerFactory? timer,
    Duration Function()? elapsed,
    DateTime Function()? now,
    this.onWarn,
    this.onError,
  }) : _now = now ?? DateTime.now {
    final watch = Stopwatch()..start();
    _elapsed = elapsed ?? () => watch.elapsed;
    _timer = (timer ?? Timer.periodic)(flushInterval, (_) {
      if (_buffer.isNotEmpty) unawaited(flush());
    });
  }

  final SessionLogEncoder encoder;
  final int warnBytes;
  final int flushBytes;

  /// Called once, when the log passes [warnBytes].
  final void Function()? onWarn;

  /// Called once, when a write fails. The log stops itself: a disk that is
  /// full or a folder that went away will not get better by retrying every
  /// second.
  final void Function(Object error)? onError;

  final SessionLogSink sink;
  final DateTime Function() _now;
  late final Duration Function() _elapsed;
  late final Timer _timer;

  final _buffer = BytesBuilder(copy: false);
  Future<void> _writing = Future.value();
  var _closed = false;
  var _failed = false;

  /// Bytes handed to the sink, or waiting to be.
  int get bytesLogged => _bytes;
  var _bytes = 0;

  /// Whether the log has passed [warnBytes].
  bool get oversized => _bytes >= warnBytes;

  bool get isClosed => _closed;

  /// Writes the header. Called once, first.
  void start(SessionLogHeader header) => _append(encoder.header(header));

  /// Output from the server.
  void output(Uint8List bytes, {required int columns, required int rows}) {
    if (_closed) return;
    _append(
      encoder.output(bytes, elapsed: _elapsed(), columns: columns, rows: rows),
    );
  }

  /// A line the app adds: the connection dropped, it came back.
  void marker(String text) {
    if (_closed) return;
    _append(encoder.marker(text, elapsed: _elapsed(), wallClock: _now()));
  }

  void _append(List<int> bytes) {
    if (bytes.isEmpty || _closed) return;
    final before = _bytes;
    _buffer.add(bytes);
    _bytes += bytes.length;
    if (before < warnBytes && _bytes >= warnBytes) onWarn?.call();
    if (_buffer.length >= flushBytes) unawaited(flush());
  }

  /// Hands everything buffered to the sink. Writes are chained, so two
  /// flushes never overlap and bytes land in the order they arrived.
  Future<void> flush() {
    if (_buffer.isEmpty || _failed) return _writing;
    final chunk = _buffer.takeBytes();
    return _writing = _writing.then((_) async {
      if (_failed) return;
      try {
        await sink.write(chunk);
      } on Object catch (e) {
        _failed = true;
        _closed = true;
        _timer.cancel();
        // Released rather than left open for a close that may never come.
        unawaited(sink.close().catchError((Object _) {}));
        onError?.call(e);
      }
    });
  }

  /// Writes [finalMarker], if any, and what the encoder held back, then
  /// closes the sink. Safe to call twice.
  Future<void> close({String? finalMarker}) async {
    if (_closed) {
      await _writing;
      return;
    }
    if (finalMarker != null) marker(finalMarker);
    _append(encoder.finish());
    _closed = true;
    _timer.cancel();
    await flush();
    try {
      await sink.close();
    } on Object catch (e) {
      if (!_failed) onError?.call(e);
    }
  }
}
