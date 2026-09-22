import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/terminal_theme_presets.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'terminal_theme_picker.dart';
import 'terminal_theme_preview.dart';

/// The terminal colour scheme hosts use unless they choose their own.
///
/// The row shows a swatch of the current one; the picker behind it shows each
/// preset rendered, because a list of names is not how anyone chooses colours.
class TerminalThemeTile extends ConsumerWidget {
  const TerminalThemeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preset = TerminalThemePresets.byId(
      ref.watch(settingsControllerProvider.select((s) => s.terminalThemeId)),
    );

    return ListTile(
      leading: const Icon(PiconsRegular.palette),
      title: Text(l10n.settingsTerminalTheme),
      subtitle: Text(preset.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TerminalThemeSwatch(preset: preset),
          const SizedBox(width: Spacing.sm),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        final chosen = await showTerminalThemePicker(
          context,
          selectedId: preset.id,
        );
        if (chosen != null) {
          ref
              .read(settingsControllerProvider.notifier)
              .setTerminalTheme(chosen);
        }
      },
    );
  }
}
