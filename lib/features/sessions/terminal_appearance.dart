import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm2/xterm.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/terminal_fonts.dart';
import '../../core/theme/terminal_theme_presets.dart';
import '../../core/theme/terminal_theme.dart';
import '../hosts/hosts_controller.dart';

/// The colour scheme the terminal for the host with this id draws with.
///
/// The host's own `terminal_theme` when it names a preset this build knows,
/// the app setting otherwise — so a host restored from a newer build's backup,
/// naming a preset that does not exist here, draws in the default rather than
/// failing. Watches only that host's column, like `terminalFontSizeProvider`,
/// so editing another host does not repaint every open terminal.
final terminalThemePresetProvider =
    Provider.family<TerminalThemePreset, String>((ref, hostId) {
      final appDefault = ref.watch(
        settingsControllerProvider.select((s) => s.terminalThemeId),
      );
      final hostOverride = ref.watch(
        hostsProvider.select(
          (hosts) => hosts.value
              ?.where((h) => h.id == hostId)
              .firstOrNull
              ?.terminalTheme,
        ),
      );
      return TerminalThemePresets.resolve(
        hostOverride: hostOverride,
        appDefault: appDefault,
      );
    });

/// The face every terminal draws in. App-wide: a per-host face is a setting
/// nobody has asked for, where a per-host colour scheme is how people tell
/// production from staging at a glance.
final terminalFontProvider = Provider<TerminalFont>(
  (ref) => TerminalFonts.byId(
    ref.watch(settingsControllerProvider.select((s) => s.terminalFontId)),
  ),
);

/// The xterm2 cursor type for a stored [TerminalCursorShape].
extension TerminalCursorShapeView on TerminalCursorShape {
  TerminalCursorType get cursorType => switch (this) {
    TerminalCursorShape.block => TerminalCursorType.block,
    TerminalCursorShape.underline => TerminalCursorType.underline,
    TerminalCursorShape.bar => TerminalCursorType.verticalBar,
  };
}
