import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something happened that makes a dead link likely, or a retry worthwhile.
enum ReconnectTrigger {
  /// The app came back after being hidden — backgrounded on a phone,
  /// minimised on a desktop. Mobile sockets die silently while suspended.
  resumed,

  /// A network became available, or changed. A socket bound to the old one
  /// is dead even if nothing has said so yet.
  networkAvailable,
}

/// The two outside events that should cut a reconnect's wait short, in one
/// place: the app lifecycle and network connectivity.
///
/// Listens only while someone listens to [events] — the session list
/// subscribes while it has tabs open — so an app with no sessions registers
/// no platform listeners at all.
class ReconnectTriggers {
  late final StreamController<ReconnectTrigger> _events =
      StreamController<ReconnectTrigger>.broadcast(
        onListen: _start,
        onCancel: _stop,
      );

  AppLifecycleListener? _lifecycle;
  StreamSubscription<List<ConnectivityResult>>? _network;

  /// Set when the app is hidden, so coming back to the foreground is told
  /// apart from a desktop window merely regaining focus — which also
  /// "resumes", and is no reason to ping every server.
  bool _wasHidden = false;

  Stream<ReconnectTrigger> get events => _events.stream;

  void _start() {
    _lifecycle = AppLifecycleListener(
      onHide: () => _wasHidden = true,
      onResume: () {
        if (!_wasHidden) return;
        _wasHidden = false;
        _emit(ReconnectTrigger.resumed);
      },
    );
    try {
      _network = Connectivity().onConnectivityChanged.listen(
        (results) {
          if (results.any((r) => r != ConnectivityResult.none)) {
            _emit(ReconnectTrigger.networkAvailable);
          }
        },
        // A platform without a connectivity service still gets the lifecycle
        // trigger and the countdown; this one is an optimisation.
        onError: (Object _) {},
      );
    } on Object {
      _network = null;
    }
  }

  void _stop() {
    _lifecycle?.dispose();
    _lifecycle = null;
    unawaited(_network?.cancel());
    _network = null;
  }

  void _emit(ReconnectTrigger trigger) {
    if (!_events.isClosed) _events.add(trigger);
  }

  void dispose() {
    _stop();
    unawaited(_events.close());
  }
}

final reconnectTriggersProvider = Provider<ReconnectTriggers>((ref) {
  final triggers = ReconnectTriggers();
  ref.onDispose(triggers.dispose);
  return triggers;
});
