import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sessions/session_manager.dart';
import '../../features/tunnels/tunnels_controller.dart';
import '../../l10n/app_localizations.dart';
import '../error/error_logger.dart';
import '../secrets/app_lock.dart' show appLocalizationsFor;
import '../settings/settings_controller.dart';
import 'keep_alive_platform.dart';

/// What is open right now: terminal tabs and running forwards.
@immutable
class KeepAliveCounts {
  const KeepAliveCounts({required this.sessions, required this.tunnels});

  final int sessions;
  final int tunnels;

  int get total => sessions + tunnels;

  @override
  bool operator ==(Object other) =>
      other is KeepAliveCounts &&
      other.sessions == sessions &&
      other.tunnels == tunnels;

  @override
  int get hashCode => Object.hash(sessions, tunnels);
}

/// Keeps the Android process alive while anything is connected.
///
/// Android freezes or kills a backgrounded app within minutes, and every SSH
/// socket goes with it. A foreground service — a notification the user can
/// see — is the sanctioned way to say "this app is doing something you asked
/// for". It starts with the first connection, follows the counts, and stops
/// at zero, so it is never on screen with nothing behind it.
///
/// Every call is serialized: a burst of changes (connect, then a tunnel
/// starting over it) must reach the platform in order, or a late `start`
/// could land after the `stop` that should have replaced it.
class KeepAliveController {
  KeepAliveController({
    required this._platform,
    required this.supported,
    required this._noticeFor,
    required Future<void> Function() onDisconnectAll,
  }) {
    if (supported) _platform.onDisconnectAll = onDisconnectAll;
  }

  final KeepAlivePlatform _platform;
  final KeepAliveNotice Function(KeepAliveCounts counts) _noticeFor;

  /// False everywhere but Android, where every call is a no-op.
  final bool supported;

  var _running = false;
  KeepAliveNotice? _shown;
  var _askedPermission = false;
  Future<void> _pending = Future.value();

  /// Whether the service has been started and not since stopped.
  bool get isRunning => _running;

  /// Brings the service in line with [counts]. Completes once applied.
  Future<void> sync(KeepAliveCounts counts, {required bool enabled}) {
    if (!supported) return Future.value();
    final next = _pending.then((_) => _apply(counts, enabled));
    _pending = next;
    return next;
  }

  Future<void> _apply(KeepAliveCounts counts, bool enabled) async {
    try {
      if (!enabled || counts.total == 0) {
        if (!_running) return;
        _running = false;
        _shown = null;
        await _platform.stop();
        return;
      }

      final notice = _noticeFor(counts);
      if (!_running) {
        await _platform.start(notice);
        _running = true;
        _shown = notice;
        return;
      }

      if (notice != _shown) {
        await _platform.update(notice);
        _shown = notice;
      }
    } catch (error, stackTrace) {
      // Android 12+ refuses to start a foreground service from the
      // background. The connections still work until Android reclaims the
      // process; the next change retries, because [_running] is still false.
      ErrorLogger.instance.record(error, stackTrace, source: 'keep-alive');
    }
  }

  /// Asks for permission to post the notification, once per run.
  ///
  /// Called when a connection has *succeeded*, not when a tab opens: a tab
  /// opens before the handshake, and a system prompt raised then lands on
  /// top of the host-key dialog — where a tap meant for one answers the
  /// other. If it is denied the service still runs and still keeps the
  /// process alive; Android only hides the notification (it stays in the
  /// task manager), so there is nothing to handle here. A notification
  /// posted before the answer is re-posted on grant by the native side.
  Future<void> askForNotificationsOnce() async {
    if (!supported || _askedPermission) return;
    _askedPermission = true;
    try {
      await _platform.requestNotificationPermission();
    } catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'keep-alive');
    }
  }

  /// Stops the service if it is running. The controller is unusable after.
  Future<void> dispose() {
    if (!supported) return Future.value();
    _platform.onDisconnectAll = null;
    return sync(const KeepAliveCounts(sessions: 0, tunnels: 0), enabled: false);
  }
}

/// The native service. Overridden in tests.
final keepAlivePlatformProvider = Provider<KeepAlivePlatform>(
  (ref) => MethodChannelKeepAlivePlatform(),
);

/// Whether this platform has a keep-alive service. Overridden in tests.
final keepAliveSupportedProvider = Provider<bool>((ref) => keepAliveSupported);

/// Open tabs and running forwards.
final keepAliveCountsProvider = Provider<KeepAliveCounts>(
  (ref) => KeepAliveCounts(
    sessions: ref.watch(sessionManagerProvider).length,
    tunnels: ref
        .watch(tunnelRunnersProvider)
        .values
        .where((status) => status.isRunning)
        .length,
  ),
);

/// What the notification's "Disconnect all" does: stop every running forward,
/// then close every tab — through the same calls the screens use.
final keepAliveDisconnectAllProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final runners = ref.read(tunnelRunnersProvider.notifier);
    final running = {
      for (final entry in ref.read(tunnelRunnersProvider).entries)
        if (entry.value.isRunning) entry.key,
    };
    if (running.isNotEmpty) {
      final tunnels = await ref.read(tunnelsProvider.future);
      for (final tunnel in tunnels) {
        if (running.contains(tunnel.id)) await runners.stop(tunnel);
      }
    }

    final sessions = ref.read(sessionManagerProvider.notifier);
    for (final session in [...ref.read(sessionManagerProvider)]) {
      sessions.close(session.id);
    }
  },
);

/// The live controller, following the counts and the setting.
///
/// Watched once from the app root so it exists for the whole run; it listens
/// rather than watches, so it is built once and never torn down mid-session.
final keepAliveControllerProvider = Provider<KeepAliveController>((ref) {
  final controller = KeepAliveController(
    platform: ref.watch(keepAlivePlatformProvider),
    supported: ref.watch(keepAliveSupportedProvider),
    noticeFor: (counts) => keepAliveNoticeFor(
      appLocalizationsFor(ref.read(settingsControllerProvider).localeCode),
      counts,
    ),
    onDisconnectAll: () => ref.read(keepAliveDisconnectAllProvider)(),
  );

  void sync() => unawaited(
    controller.sync(
      ref.read(keepAliveCountsProvider),
      enabled: ref.read(settingsControllerProvider).keepAliveInBackground,
    ),
  );

  ref.listen(keepAliveCountsProvider, (_, _) => sync());
  ref.listen(
    settingsControllerProvider.select(
      (s) => (s.keepAliveInBackground, s.localeCode),
    ),
    (_, _) => sync(),
  );
  sync();

  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

/// The notification text for [counts], e.g. "2 sessions, 1 tunnel active".
KeepAliveNotice keepAliveNoticeFor(
  AppLocalizations l10n,
  KeepAliveCounts counts,
) {
  final parts = [
    if (counts.sessions > 0) l10n.keepAliveSessions(counts.sessions),
    if (counts.tunnels > 0) l10n.keepAliveTunnels(counts.tunnels),
  ];
  return KeepAliveNotice(
    title: l10n.keepAliveTitle,
    text: parts.length == 2
        ? l10n.keepAliveSummaryBoth(parts[0], parts[1])
        : l10n.keepAliveSummaryOne(parts.firstOrNull ?? ''),
    disconnectAllLabel: l10n.keepAliveDisconnectAll,
    channelName: l10n.keepAliveChannelName,
  );
}
