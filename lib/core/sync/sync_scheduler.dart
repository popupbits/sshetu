import 'dart:async';

// `widgets`, not `material`: this needs WidgetsBinding and the lifecycle
// enum, and nothing Material — see test/no_frozen_material_test.dart.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../error/error_logger.dart';
import 'sync_controller.dart';
import 'sync_signal.dart';

/// How long to wait after a local change before pushing it.
///
/// Long enough that editing a host — which rewrites the row on every save,
/// and often twice as the user corrects something — is one sync rather than
/// three. Short enough that closing the app straight after a change still
/// leaves time for it to leave the device.
const kSyncDebounce = Duration(seconds: 4);

/// The shortest gap between two syncs triggered by coming back to the app.
///
/// Resuming is not evidence that anything changed; it is a guess that
/// something *might* have, on another device. Guessing every few seconds
/// would spend the user's battery and Appwrite's quota on nothing.
const kResumeInterval = Duration(minutes: 2);

/// Decides when sync runs, so that nothing in the UI has to.
///
/// Without this the engine was complete, tested, and never called: sync
/// happened only if the user found the button in Settings and pressed it. A
/// sync you have to remember to run is a sync that has already failed at the
/// one thing it promised — that a host added on a laptop is on the phone.
///
/// Three triggers, each answering a different question:
///
///  * **Signing in** — "what is already up there?" The first pull is the
///    entire point of signing in on a second device. A session restored at
///    startup counts: opening the app is exactly when you want the phone to
///    have what the laptop did last night.
///  * **A local change** — "this is new, take it." Debounced by
///    [kSyncDebounce], and reported by the repository that made it (see
///    [SyncSignal]) rather than inferred from a list rebuilding, which also
///    happens on a plain refresh.
///  * **Coming back to the app** — "did anything change elsewhere?" Rate
///    limited by [kResumeInterval].
///
/// Signed out, every trigger is a no-op: this app's primary mode is local
/// only, and it must not reach for the network on behalf of someone who never
/// asked it to.
class SyncScheduler with WidgetsBindingObserver {
  SyncScheduler(this._ref) {
    WidgetsBinding.instance.addObserver(this);

    // Signing in — including the asynchronous resolution of a session that
    // was already there, which is what a cold start looks like from here.
    // Rate limited with the same clock as resuming, so opening and closing
    // the app repeatedly is one sync rather than five.
    _ref.listen(currentUserProvider, (previous, next) {
      if (next != null && previous?.$id != next.$id) {
        _syncSoon();
      }
    });

    // Any local write to a synced table, reported by the repository that
    // made it.
    _changes = _ref
        .read(syncSignalProvider)
        .changes
        .listen((_) => _requestSync());
  }

  final Ref _ref;

  late final StreamSubscription<void> _changes;
  Timer? _debounce;
  DateTime? _lastResumeSync;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _syncSoon();
  }

  /// Syncs because the app came into view or a session appeared — a guess
  /// that something *might* have changed elsewhere, rather than knowledge
  /// that something did. Rate limited by [kResumeInterval]; guessing every
  /// few seconds would spend battery and quota on nothing.
  void _syncSoon() {
    final last = _lastResumeSync;
    final now = DateTime.now();
    if (last != null && now.difference(last) < kResumeInterval) return;
    _lastResumeSync = now;
    _syncNow();
  }

  void _requestSync() {
    _debounce?.cancel();
    _debounce = Timer(kSyncDebounce, _syncNow);
  }

  void _syncNow() {
    // Checked here rather than at each call site so that every trigger gets
    // the same answer, and so a sign-out mid-debounce cancels the push.
    if (_ref.read(currentUserProvider) == null) return;

    // Nothing awaits a scheduled sync, so an error here has nowhere to go but
    // the zone — where it would surface as a crash in whatever happened to be
    // running. `SyncController.syncNow` already reports engine failures in
    // its own state; this catches the rest, such as a database that is not
    // there at all.
    unawaited(
      _ref
          .read(syncControllerProvider.notifier)
          .syncNow()
          .catchError(
            (Object error, StackTrace stackTrace) => ErrorLogger.instance
                .record(error, stackTrace, source: 'sync-scheduler'),
          ),
    );
  }

  void dispose() {
    unawaited(_changes.cancel());
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Kept alive for the life of the app by `SshNavigatorApp`.
///
/// A `Provider` rather than something started in `runBootstrap`, because it
/// needs a `Ref` to listen with — and because bootstrap runs before the first
/// frame, where `WidgetsBinding.instance.addObserver` has nothing to observe
/// yet.
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
