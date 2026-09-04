import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// The terminal grid's own size.
///
/// Separate from the interface text size because the two answer different
/// questions: a dense display can need a bigger grid while the chrome around
/// it is already the right size.
class TerminalFontSizeTile extends ConsumerWidget {
  const TerminalFontSizeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(
      settingsControllerProvider.select((s) => s.terminalFontSize),
    );
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(settingsControllerProvider.notifier);

    return ListTile(
      leading: const Icon(PiconsRegular.terminalWindow),
      title: Text(l10n.settingsTerminalTextSize),
      subtitle: Text(l10n.terminalTextSizePoints(size.round())),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(PiconsRegular.magnifyingGlassMinus),
            tooltip: l10n.terminalTextSizeSmaller,
            onPressed: size <= AppSettings.minTerminalFontSize
                ? null
                : () => controller.adjustTerminalFontSize(-1),
          ),
          IconButton(
            icon: const Icon(PiconsRegular.magnifyingGlassPlus),
            tooltip: l10n.terminalTextSizeLarger,
            onPressed: size >= AppSettings.maxTerminalFontSize
                ? null
                : () => controller.adjustTerminalFontSize(1),
          ),
        ],
      ),
    );
  }
}
