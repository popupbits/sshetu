import 'dart:async';

import 'reconnect_policy.dart';

/// Where an automatic reconnect is.
enum ReconnectPhase {
  /// Nothing to do: connected, never dropped, or the user ended it.
  idle,

  /// Dropped, and counting down to the next attempt.
  waiting,

  /// An attempt is in flight.
  connecting,
}

/// Starts a timer. Injected so tests can drive time by hand.
typedef ReconnectTimerFactory = Timer Function(
  Duration delay,
  void Function() callback,
);

/// The retry loop behind one dropped session.
///
/// Knows nothing about SSH or terminals: [attempt] either completes (we are
/// back) or throws, and [ReconnectPolicy] decides from the error whether to
/// keep going. That separation is what makes the state machine testable with
/// a function that fails on command and a timer that fires when told.
class ReconnectLoop {
  ReconnectLoop({
    required this.attempt,
    this.policy = const ReconnectPolicy(),
    this.onChanged,
    this.onGaveUp,
    DateTime Function()? clock,
    ReconnectTimerFactory? timer,
  }) : _clock = clock ?? DateTime.now,
       _timer = timer ?? Timer.new;

  /// One try at coming back. Throws when it did not work.
  final Future<void> Function() attempt;

  final ReconnectPolicy policy;

  /// Called on every phase or countdown change, so the UI can redraw.
  final void Function()? onChanged;

  /// Called when an attempt failed for a reason retrying cannot fix — the
  /// server now rejects the credential, the host key changed. The loop has
  /// already stopped by then.
  final void Function(Object error)? onGaveUp;

  final DateTime Function() _clock;
  final ReconnectTimerFactory _timer;

  ReconnectPhase _phase = ReconnectPhase.idle;
  ReconnectPhase get phase => _phase;

  /// Whether the loop is working on bringing the session back.
  bool get isActive => _phase != ReconnectPhase.idle;

  int _attempt = 0;

  /// How many attempts have been made since the drop.
  int get attemptsMade => _attempt;

  DateTime? _nextAt;

  /// When the next attempt will start, while [phase] is waiting.
  DateTime? get nextAttemptAt =>
      _phase == ReconnectPhase.waiting ? _nextAt : null;

  DateTime? _droppedAt;
  Timer? _pending;

  /// Bumped whenever the loop is stopped or restarted, so an attempt that was
  /// already in flight can tell its answer is no longer wanted.
  int _generation = 0;
  bool _disposed = false;

  /// Reports a drop. Starts counting down if [reason] is worth retrying.
  ///
  /// Returns whether it did, so the caller can tell a session that will come
  /// back from one that has ended.
  bool dropped(DisconnectReason reason) {
    if (_disposed) return false;
    if (!policy.shouldReconnect(reason)) {
      stop();
      return false;
    }
    if (_phase != ReconnectPhase.idle) return true;
    _generation++;
    _attempt = 0;
    _droppedAt = _clock();
    _schedule();
    return true;
  }

  /// Skips the rest of the wait and tries now. Does nothing unless waiting:
  /// an attempt already in flight is left to finish, and a session that is
  /// connected or was ended by the user has nothing to retry.
  void retryNow() {
    if (_disposed || _phase != ReconnectPhase.waiting) return;
    _pending?.cancel();
    _pending = null;
    unawaited(_run());
  }

  /// Gives up on reconnecting. An attempt in flight is allowed to finish —
  /// cancelling a handshake halfway helps no one — but its failure will not
  /// schedule another, and its success is still success.
  void stop() {
    _pending?.cancel();
    _pending = null;
    _generation++;
    final was = _phase;
    _phase = ReconnectPhase.idle;
    _nextAt = null;
    if (was != ReconnectPhase.idle) onChanged?.call();
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _pending = null;
    _generation++;
  }

  void _schedule() {
    final elapsed = _clock().difference(_droppedAt ?? _clock());
    final delay = policy.delayBefore(_attempt, elapsed: elapsed);
    _phase = ReconnectPhase.waiting;
    _nextAt = _clock().add(delay);
    final generation = _generation;
    _pending = _timer(delay, () {
      if (generation != _generation) return;
      _pending = null;
      unawaited(_run());
    });
    onChanged?.call();
  }

  Future<void> _run() async {
    final generation = _generation;
    _phase = ReconnectPhase.connecting;
    _nextAt = null;
    onChanged?.call();
    try {
      await attempt();
      if (_disposed) return;
      // Back, whether or not someone pressed Stop in the meantime.
      _phase = ReconnectPhase.idle;
      _attempt = 0;
      onChanged?.call();
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _attempt++;
      if (!policy.shouldReconnect(ReconnectPolicy.classify(error))) {
        _phase = ReconnectPhase.idle;
        onChanged?.call();
        onGaveUp?.call(error);
        return;
      }
      _schedule();
    }
  }
}
