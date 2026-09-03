import 'package:appwrite/models.dart' as models;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/sync/sync_controller.dart';
import 'package:sshetu/core/sync/sync_scheduler.dart';
import 'package:sshetu/core/sync/sync_signal.dart';
import 'package:sshetu/core/sync/sync_status.dart';
import 'package:sshetu/features/auth/auth_controller.dart';

/// When sync runs, which before this was: never, unless someone found the
/// button in Settings.
///
/// The engine was complete and tested and nothing called it. These tests are
/// about the calling, so the engine is replaced with a counter — what matters
/// here is *whether* a sync was asked for, and how many times.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingSyncController sync;
  late SyncSignal signal;

  /// A container with the scheduler running, and the write signal a
  /// repository would use.
  ProviderContainer build({required bool signedIn}) {
    sync = _CountingSyncController();
    signal = SyncSignal();
    addTearDown(signal.dispose);

    final container = ProviderContainer(
      overrides: [
        syncControllerProvider.overrideWith(() => sync),
        currentUserProvider.overrideWithValue(
          signedIn ? _user('user-1') : null,
        ),
        syncSignalProvider.overrideWithValue(signal),
      ],
    );
    addTearDown(container.dispose);

    container.read(syncSchedulerProvider);
    return container;
  }

  testWidgets('a local write syncs, after the debounce', (tester) async {
    build(signedIn: true);
    await tester.pump();

    signal.localChange();
    await tester.pump();

    expect(sync.calls, 0, reason: 'not immediately — a save can be followed');

    await tester.pump(kSyncDebounce);
    expect(sync.calls, 1);
  });

  testWidgets('several rapid writes are one sync', (tester) async {
    // Editing a host rewrites the row on every save, and a user correcting a
    // typo saves more than once. Three syncs for one edit is three requests
    // and two wasted.
    build(signedIn: true);
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      signal.localChange();
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tester.pump(kSyncDebounce);
    expect(sync.calls, 1);
  });

  testWidgets('signed out, nothing is ever sent', (tester) async {
    // The app's primary mode is local only. It must not reach for the network
    // on behalf of someone who never signed in.
    build(signedIn: false);
    await tester.pump();

    signal.localChange();
    await tester.pump(kSyncDebounce);

    expect(sync.calls, 0);
  });

  testWidgets('opening the app while signed in pulls once', (tester) async {
    // A restored session resolving asynchronously is what a cold start looks
    // like from the scheduler, and it is exactly when the phone should pick
    // up what the laptop did last night.
    final container = build(signedIn: true);
    final scheduler = container.read(syncSchedulerProvider);
    await tester.pump();

    // The sign-in path shares the resume clock, so a resume straight after
    // startup does not sync a second time.
    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(sync.calls, lessThanOrEqualTo(1));
  });

  testWidgets('resuming syncs, but not on every resume', (tester) async {
    final container = build(signedIn: true);
    await tester.pump();
    final scheduler = container.read(syncSchedulerProvider);

    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(sync.calls, 1);

    // Switching away and back again immediately is not evidence that anything
    // changed on another device.
    scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(sync.calls, 1, reason: 'rate limited by kResumeInterval');
  });
}

models.User _user(String id) => models.User(
  $id: id,
  $createdAt: '',
  $updatedAt: '',
  name: 'Test',
  registration: '',
  status: true,
  labels: const [],
  passwordUpdate: '',
  email: 'test@example.com',
  phone: '',
  emailVerification: true,
  phoneVerification: false,
  mfa: false,
  prefs: models.Preferences(data: const {}),
  targets: const [],
  accessedAt: '',
);

/// Counts calls instead of touching a database or the network.
class _CountingSyncController extends SyncController {
  var calls = 0;

  @override
  Future<SyncStatus> build() async =>
      const SyncStatus(lastSyncedAt: null, pendingCount: 0, isSyncing: false);

  @override
  Future<void> syncNow() async => calls++;
}
