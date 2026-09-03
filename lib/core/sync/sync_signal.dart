import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Announces that something synced was written locally.
///
/// Deliberately *not* the list providers, which was the first attempt and is
/// the wrong signal twice over. Those rebuild on reads as well as writes, so
/// pulling to refresh a list that has not changed would push nothing to the
/// server and still cost a round trip; and subscribing to all three at startup
/// forces every table to load before anything asks for it.
///
/// A write is a fact the repository already knows. This is that fact, and
/// nothing else.
class SyncSignal {
  final _controller = StreamController<void>.broadcast();

  /// Called by a repository after committing a change to a synced table.
  void localChange() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }

  Stream<void> get changes => _controller.stream;

  void dispose() => unawaited(_controller.close());
}

final syncSignalProvider = Provider<SyncSignal>((ref) {
  final signal = SyncSignal();
  ref.onDispose(signal.dispose);
  return signal;
});
