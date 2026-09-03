import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';

/// Most bytes decoded and handed to the terminal in one flush.
///
/// Anything beyond this is carried to the next flush, so `cat hugefile` cannot
/// stall a frame.
const int kMaxFlushBytes = 256 * 1024;

/// Most bytes held undecoded before the oldest are dropped.
///
/// A session producing faster than frames arrive would otherwise queue without
/// bound, which turns a throttle into a memory leak. Dropping the oldest is the
/// same contract scrollback already has — output old enough falls off the top —
/// applied before the parse rather than after it.
const int kMaxPendingBytes = 512 * 1024;

/// How long the coalescer must have been quiet before the next bytes are
/// treated as interactive and written straight through.
///
/// One frame. Below this, output is arriving faster than the screen refreshes
/// and there is nothing to gain by writing twice into the same frame; above it,
/// the terminal was idle, which at a shell prompt means the bytes are the echo
/// of a key the user just pressed.
const Duration kIdleThreshold = Duration(milliseconds: 16);

typedef FrameCallbackScheduler = void Function(VoidCallback callback);
typedef WatchdogScheduler = Object Function(Duration d, VoidCallback callback);
typedef WatchdogCanceller = void Function(Object handle);
typedef MonotonicClock = Duration Function();

/// Buffers raw bytes from a session and hands them to the terminal at most
/// once per frame.
///
/// An SSH channel delivers small chunks — often a few hundred bytes — so a
/// busy remote command produces hundreds of stream events a second, each one
/// its own UTF-8 decode, `Terminal.write` and repaint request. Flutter
/// coalesces the resulting *repaints*, but the parsing and allocation still
/// land on the UI isolate and show up as jank.
///
/// **Bytes are buffered, not strings.** A multi-byte character split across two
/// network reads has to survive, so one long-lived chunked decoder carries
/// partial sequences across flush boundaries. Decoding each chunk on its own
/// would put a replacement character in the middle of anyone's UTF-8 output.
///
/// ## Why the first bytes after a quiet moment skip the queue
///
/// Deferring everything to a frame is what a coalescer is for under load, and
/// exactly wrong for an echo. `addPostFrameCallback` does not *schedule* a
/// frame, and a terminal sitting at a prompt animates nothing — so when a
/// keystroke's echo arrives, no frame is pending, nothing runs the flush until
/// the watchdog fires, and only then does `Terminal.write` mark the render
/// object dirty and ask for a frame. Every echoed character would pay a timer
/// plus a frame it had just missed, which reads as a laggy connection even on
/// a fast one.
///
/// So bytes arriving after [idleThreshold] of quiet are written through
/// immediately. Under sustained output the threshold is never met — chunks
/// arrive microseconds apart — and the per-frame batching is exactly as it was.
class OutputCoalescer {
  OutputCoalescer({
    required this.onData,
    FrameCallbackScheduler? scheduleFrameCallback,
    WatchdogScheduler? scheduleWatchdog,
    WatchdogCanceller? cancelWatchdog,
    MonotonicClock? clock,
    this.maxFlushBytes = kMaxFlushBytes,
    this.maxPendingBytes = kMaxPendingBytes,
    this.watchdogDelay = kIdleThreshold,
    this.idleThreshold = kIdleThreshold,
  }) : _scheduleFrameCallback =
           scheduleFrameCallback ?? _defaultScheduleFrameCallback,
       _scheduleWatchdog = scheduleWatchdog ?? _defaultScheduleWatchdog,
       _cancelWatchdog = cancelWatchdog ?? _defaultCancelWatchdog,
       _clock = clock ?? _defaultClock {
    _decoderSink = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(_CallbackSink(_decoded.write));
    // The clock starts here: a session's first output is a login banner, not
    // an echo of anything, so there is nothing to gain by rushing it.
    _lastFlushAt = _clock();
  }

  /// Receives each flush's decoded text — in production, `Terminal.write`.
  final void Function(String data) onData;

  final int maxFlushBytes;
  final int maxPendingBytes;
  final Duration watchdogDelay;
  final Duration idleThreshold;

  final FrameCallbackScheduler _scheduleFrameCallback;
  final WatchdogScheduler _scheduleWatchdog;
  final WatchdogCanceller _cancelWatchdog;
  final MonotonicClock _clock;

  final List<int> _pending = [];
  final StringBuffer _decoded = StringBuffer();
  late final Sink<List<int>> _decoderSink;

  Object? _watchdog;
  bool _scheduled = false;
  bool _disposed = false;
  Duration _lastFlushAt = Duration.zero;

  /// Bytes waiting to be decoded. For tests and diagnostics.
  int get pendingBytes => _pending.length;

  /// How many bytes have been dropped because the buffer was full.
  ///
  /// Surfaced rather than silent: dropped bytes can cut an escape sequence and
  /// leave a full-screen program drawing against a state the parser no longer
  /// agrees with, and that is worth being able to see when someone reports a
  /// garbled screen.
  int droppedBytes = 0;

  /// Takes [bytes] from the session.
  void add(List<int> bytes) {
    if (_disposed || bytes.isEmpty) return;

    final now = _clock();
    final wasIdle = now - _lastFlushAt >= idleThreshold;

    _pending.addAll(bytes);

    if (_pending.length > maxPendingBytes) {
      final excess = _pending.length - maxPendingBytes;
      _pending.removeRange(0, excess);
      droppedBytes += excess;
    }

    if (wasIdle && !_scheduled) {
      // Interactive: mark the terminal dirty now so the very next frame paints
      // the echo, instead of waiting for a frame that nothing has asked for.
      flush();
      return;
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    _scheduleFrameCallback(() {
      _scheduled = false;
      flush();
    });
    // The watchdog is the safety net for exactly the case above: when no frame
    // is pending, a post-frame callback can wait indefinitely.
    _watchdog ??= _scheduleWatchdog(watchdogDelay, () {
      _watchdog = null;
      if (!_disposed) flush();
    });
  }

  /// Decodes and delivers what is buffered, up to [maxFlushBytes].
  void flush() {
    if (_disposed || _pending.isEmpty) return;

    final take = _pending.length > maxFlushBytes
        ? maxFlushBytes
        : _pending.length;
    final chunk = _pending.sublist(0, take);
    _pending.removeRange(0, take);

    _decoderSink.add(chunk);
    final text = _decoded.toString();
    _decoded.clear();

    _lastFlushAt = _clock();
    if (text.isNotEmpty) onData(text);

    // Carried remainder: come back for it next frame rather than blowing the
    // budget now.
    if (_pending.isNotEmpty) _schedule();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final handle = _watchdog;
    if (handle != null) _cancelWatchdog(handle);
    _watchdog = null;
    _pending.clear();
    // Not closed: closing a chunked UTF-8 decoder mid-sequence throws, and a
    // session torn down between two bytes of a character is ordinary.
  }

  static void _defaultScheduleFrameCallback(VoidCallback callback) {
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) => callback());
    } on Object {
      // No binding — a headless context, such as a test driving a real
      // connection without a widget tree. Throwing here would escape from
      // inside a stream listener and silently stop all further output, which
      // is a spectacular failure for a missing frame scheduler. The watchdog
      // timer is the fallback clock, and is exactly what it is for.
    }
  }

  static Object _defaultScheduleWatchdog(Duration d, VoidCallback callback) =>
      Timer(d, callback);

  static void _defaultCancelWatchdog(Object handle) {
    (handle as Timer).cancel();
  }

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static Duration _defaultClock() => _stopwatch.elapsed;
}

/// Adapts the chunked decoder's output to a callback.
class _CallbackSink implements Sink<String> {
  _CallbackSink(this._write);

  final void Function(String) _write;

  @override
  void add(String data) => _write(data);

  @override
  void close() {}
}
