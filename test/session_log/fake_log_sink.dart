import 'dart:convert';

import 'package:sshetu/features/session_log/domain/session_logger.dart';

/// A [SessionLogSink] that keeps what it is given, and can be told to be
/// slow or to fail.
class FakeLogSink implements SessionLogSink {
  FakeLogSink([this.path = 'fake.log']);

  final String path;
  final writes = <List<int>>[];
  var closeCount = 0;
  bool get closed => closeCount > 0;

  /// Each write waits this long, so overlapping writes would show.
  Duration? delay;

  /// Thrown from every write.
  Object? failWith;

  var _inFlight = 0;
  var maxConcurrent = 0;

  String get text => utf8.decode([for (final w in writes) ...w]);

  @override
  Future<void> write(List<int> bytes) async {
    _inFlight++;
    if (_inFlight > maxConcurrent) maxConcurrent = _inFlight;
    try {
      final wait = delay;
      if (wait != null) await Future<void>.delayed(wait);
      final failure = failWith;
      if (failure != null) throw failure;
      writes.add(List.of(bytes));
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<void> close() async => closeCount++;
}
