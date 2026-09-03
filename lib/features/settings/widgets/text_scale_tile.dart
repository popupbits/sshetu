import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Text-size picker.
///
/// Four named steps rather than a slider: a continuous control invites values
/// that break layouts, and nobody can tell 1.07 from 1.09 anyway.
class TextScaleTile extends ConsumerWidget {
  const TextScaleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(
      settingsControllerProvider.select((s) => s.textScale),
    );
    final l10n = AppLocalizations.of(context);

    String labelFor(double value) => switch (value) {
      < 1.0 => l10n.textSizeSmall,
      < 1.1 => l10n.textSizeDefault,
      < 1.2 => l10n.textSizeLarge,
      _ => l10n.textSizeLarger,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(PiconsRegular.textAa),
          title: Text(l10n.settingsTextSize),
          subtitle: Text(labelFor(scale)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          child: SegmentedButton<double>(
            segments: [
              for (final step in textScaleSteps)
                ButtonSegment(
                  value: step,
                  label: Text('A', style: TextStyle(fontSize: 13 * step)),
                  tooltip: labelFor(step),
                ),
            ],
            selected: {scale},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => ref
                .read(settingsControllerProvider.notifier)
                .setTextScale(selection.first),
          ),
        ),
      ],
    );
  }
}
