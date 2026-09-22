import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Whether the terminal tabs open at the last exit come back at launch.
class ReopenTabsTile extends ConsumerWidget {
  const ReopenTabsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(
      settingsControllerProvider.select((s) => s.effectiveReopenTabs),
    );
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(PiconsRegular.clockCounterClockwise),
          title: Text(l10n.settingsReopenTabs),
          subtitle: Text(l10n.settingsReopenTabsBody),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          child: SegmentedButton<ReopenTabs>(
            segments: [
              ButtonSegment(
                value: ReopenTabs.ask,
                label: Text(l10n.settingsReopenTabsAsk),
              ),
              ButtonSegment(
                value: ReopenTabs.always,
                label: Text(l10n.settingsReopenTabsAlways),
              ),
              ButtonSegment(
                value: ReopenTabs.never,
                label: Text(l10n.settingsReopenTabsNever),
              ),
            ],
            selected: {choice},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => ref
                .read(settingsControllerProvider.notifier)
                .setReopenTabs(selection.first),
          ),
        ),
      ],
    );
  }
}
