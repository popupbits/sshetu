import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// How many lines of history a terminal tab keeps.
///
/// Named steps rather than a free number: the useful values are orders of
/// magnitude apart, and each costs memory per tab — see
/// [AppSettings.defaultScrollbackLines]. The subtitle says the change applies
/// to new tabs, because xterm2 sizes the buffer when a tab opens and cannot
/// resize it after.
class ScrollbackTile extends ConsumerWidget {
  const ScrollbackTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lines = ref.watch(
      settingsControllerProvider.select((s) => s.scrollbackLines),
    );

    return ListTile(
      leading: const Icon(PiconsRegular.scroll),
      title: Text(l10n.settingsScrollback),
      subtitle: Text(l10n.settingsScrollbackValue(lines)),
      trailing: PopupMenuButton<int>(
        initialValue: lines,
        tooltip: l10n.settingsScrollback,
        onSelected: ref
            .read(settingsControllerProvider.notifier)
            .setScrollbackLines,
        itemBuilder: (context) => [
          for (final step in AppSettings.scrollbackSteps)
            PopupMenuItem(
              value: step,
              child: Text(l10n.scrollbackLinesOption(step)),
            ),
        ],
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}
