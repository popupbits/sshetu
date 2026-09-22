import 'dart:async';

/// A clock and timers that move only when told to.
///
/// For code that takes a timer factory and a clock, so a schedule measured
/// in minutes can be tested in microseconds and exactly.
class FakeTimers {
  FakeTimers({DateTime? start}) : start = start ?? DateTime.utc(2026, 1, 1) {
    _now = this.start;
  }

  final DateTime start;
  late DateTime _now;
  final List<_FakeTimer> _timers = [];

  DateTime now() => _now;

  /// How many timers are still waiting to fire.
  int get pending => _timers.where((t) => t.isActive).length;

  Timer create(Duration delay, void Function() callback) {
    final timer = _FakeTimer(_now.add(delay), callback, _timers.remove);
    _timers.add(timer);
    return timer;
  }

  /// Moves the clock forward, firing every timer that comes due on the way,
  /// in order.
  void elapse(Duration by) {
    final end = _now.add(by);
    while (true) {
      final due =
          _timers.where((t) => t.isActive && !t.at.isAfter(end)).toList()
            ..sort((a, b) => a.at.compareTo(b.at));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.at;
      next.fire();
    }
    _now = end;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.at, this._callback, this._remove);

  final DateTime at;
  final void Function() _callback;
  final void Function(_FakeTimer) _remove;
  bool _active = true;

  void fire() {
    _active = false;
    _remove(this);
    _callback();
  }

  @override
  void cancel() {
    _active = false;
    _remove(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
