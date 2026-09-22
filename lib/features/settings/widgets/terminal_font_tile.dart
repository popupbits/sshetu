import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/terminal_fonts.dart';
import '../../../l10n/app_localizations.dart';

/// The face the terminal grid is drawn in.
///
/// Each option is shown in its own face, which is the whole of what
/// distinguishes them. Every one but the system face ships with the app, so
/// choosing one never depends on a network — see [TerminalFont].
class TerminalFontTile extends ConsumerWidget {
  const TerminalFontTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final font = TerminalFonts.byId(
      ref.watch(settingsControllerProvider.select((s) => s.terminalFontId)),
    );

    return ListTile(
      leading: const Icon(PiconsRegular.textAa),
      title: Text(l10n.settingsTerminalFont),
      subtitle: Text(terminalFontLabel(l10n, font)),
      trailing: PopupMenuButton<String>(
        initialValue: font.id,
        tooltip: l10n.settingsTerminalFont,
        onSelected: ref
            .read(settingsControllerProvider.notifier)
            .setTerminalFont,
        itemBuilder: (context) => [
          for (final option in TerminalFonts.all)
            PopupMenuItem(
              value: option.id,
              child: Text(
                terminalFontLabel(l10n, option),
                style: TextStyle(
                  fontFamily: option.resolvedFamily,
                  fontFamilyFallback: option.fallback,
                ),
              ),
            ),
        ],
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

/// What a face is called in the UI: its own name, or "System monospace".
String terminalFontLabel(AppLocalizations l10n, TerminalFont font) =>
    font.family ?? l10n.terminalFontSystem;
