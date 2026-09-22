import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/error/error_logger.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/ssh/tunnel_runner.dart';
import '../sessions/widgets/workspace_restore_listener.dart';
import 'domain/tunnel.dart';
import 'tunnel_connect.dart';
import 'tunnels_controller.dart';

const _keyStartAtLaunch = 'settings.startTunnelsAtLaunch';

/// Settings → Tunnels → "Start auto-start tunnels when SSHetu opens".
///
/// **Off by default.** With it on, opening the app dials every server that
/// has an auto-start tunnel — before the user has said what they came for,
/// possibly on a metered network, possibly raising a host-key or password
/// prompt for a server they were not thinking about. That is a reasonable
/// thing to choose (a desktop that always needs its database tunnel up) and
/// an unreasonable thing to do to someone who never asked. Without it,
/// auto-start keeps its original meaning: start when a terminal to that
/// host connects, over the connection that just succeeded.
///
/// Kept in preferences beside, not inside, `AppSettings`: it is read once
/// per launch by this feature alone, and nothing else in the app needs it
/// in the settings value every screen watches.
class LaunchAutoStartSetting extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.watch(sharedPreferencesProvider).getBool(_keyStartAtLaunch) ??
          false;
    } on Object {
      // No preferences (a test that never installed them), or a value of
      // another type: off, the safe reading.
      return false;
    }
  }

  void set(bool enabled) {
    state = enabled;
    try {
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setBool(_keyStartAtLaunch, enabled)
            .catchError((Object _) => false),
      );
    } on Object {
      // Not persisted; it holds for this run.
    }
  }
}

final launchAutoStartSettingProvider =
    NotifierProvider<LaunchAutoStartSetting, bool>(LaunchAutoStartSetting.new);

/// Starts the auto-start tunnels, one at a time: each [start] finishes —
/// every dialog it raised answered — before the next begins, so two
/// servers' password prompts never stack on top of each other.
///
/// Skips a tunnel [isActive] says is already starting or running (a
/// restored tab's own auto-start may have got there first) and stops early
/// when [cancelled] turns true. Returns how many it started.
Future<int> runLaunchAutoStart({
  required bool enabled,
  required Future<List<Tunnel>> Function() load,
  required bool Function(Tunnel tunnel) isActive,
  required Future<void> Function(Tunnel tunnel) start,
  required bool Function() cancelled,
}) async {
  if (!enabled) return 0;
  final tunnels = await load();
  var started = 0;
  for (final tunnel in tunnels.where((t) => t.autoStart)) {
    if (cancelled()) break;
    if (isActive(tunnel)) continue;
    try {
      await start(tunnel);
      started++;
    } on Object catch (error, stackTrace) {
      // One server being down must not keep the rest from starting.
      ErrorLogger.instance.record(error, stackTrace, source: 'tunnel');
    }
  }
  return started;
}

/// How one tunnel is started at launch: [startTunnel], with its standard
/// dialogs. A seam for tests.
typedef LaunchTunnelStarter = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
  Tunnel tunnel,
);

final launchTunnelStarterProvider = Provider<LaunchTunnelStarter>(
  (ref) => startTunnel,
);

/// Whether this run has already started tunnels at launch. Once per
/// process, however often the shell is rebuilt.
class LaunchAutoStartGate {
  bool attempted = false;
}

final launchAutoStartGateProvider = Provider<LaunchAutoStartGate>(
  (ref) => LaunchAutoStartGate(),
);

/// Starts auto-start tunnels when the app opens, if the setting says so —
/// after bootstrap (it lives in the shell) and after the workspace restore
/// has finished, so its dialogs follow the restore's instead of racing them.
///
/// Sits under the router, like the restore listener, because
/// [startTunnel]'s host-key and password dialogs need a navigator.
class LaunchAutoStartListener extends ConsumerStatefulWidget {
  const LaunchAutoStartListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LaunchAutoStartListener> createState() =>
      _LaunchAutoStartListenerState();
}

class _LaunchAutoStartListenerState
    extends ConsumerState<LaunchAutoStartListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    final gate = ref.read(launchAutoStartGateProvider);
    if (gate.attempted || !mounted) return;
    gate.attempted = true;
    if (!ref.read(launchAutoStartSettingProvider)) return;

    await ref.read(workspaceRestoreGateProvider).finished;
    if (!mounted) return;
    try {
      await runLaunchAutoStart(
        enabled: ref.read(launchAutoStartSettingProvider),
        load: () => ref.read(tunnelsProvider.future),
        isActive: (tunnel) {
          final state = ref.read(tunnelRunnersProvider)[tunnel.id]?.state;
          return state == TunnelRunState.running ||
              state == TunnelRunState.starting;
        },
        start: (tunnel) =>
            ref.read(launchTunnelStarterProvider)(context, ref, tunnel),
        cancelled: () => !mounted,
      );
    } on Object catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'tunnel');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
