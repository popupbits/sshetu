import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../hosts/hosts_controller.dart';

/// The font size a host's terminal draws at: its own override when it has
/// one, the app setting otherwise — clamped either way, because a row written
/// by hand or by a newer build may hold anything.
double resolveTerminalFontSize({
  required double? hostOverride,
  required double appDefault,
}) => (hostOverride ?? appDefault).clamp(
  AppSettings.minTerminalFontSize,
  AppSettings.maxTerminalFontSize,
);

/// The terminal font size for the host with this id.
///
/// Watches only that host's `fontSize`, so editing some other host does not
/// relayout every open terminal. A host list that has not loaded, or failed
/// to, reads as "no override" rather than holding the terminal up.
final terminalFontSizeProvider = Provider.family<double, String>((ref, hostId) {
  final appDefault = ref.watch(
    settingsControllerProvider.select((s) => s.terminalFontSize),
  );
  final hostOverride = ref.watch(
    hostsProvider.select(
      (hosts) =>
          hosts.value?.where((h) => h.id == hostId).firstOrNull?.fontSize,
    ),
  );
  return resolveTerminalFontSize(
    hostOverride: hostOverride,
    appDefault: appDefault,
  );
});
