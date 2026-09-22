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
                label: _OneLine(l10n.settingsReopenTabsAsk),
              ),
              ButtonSegment(
                value: ReopenTabs.always,
                label: _OneLine(l10n.settingsReopenTabsAlways),
              ),
              ButtonSegment(
                value: ReopenTabs.never,
                label: _OneLine(l10n.settingsReopenTabsNever),
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

/// A segment label that stays on one line.
///
/// The desktop settings panel is 320 wide, which leaves each of three
/// segments under a hundred pixels, and a label that wrapped ("कहिल्यै होइन"
/// did, in Nepali) made one segment twice as tall as its neighbours. Labels
/// are kept short; this is the backstop for a language or a text scale that
/// still does not fit — it shrinks rather than breaking the row.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}
