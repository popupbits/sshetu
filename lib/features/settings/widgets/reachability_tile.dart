import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../hosts/domain/reachability.dart';
import '../../hosts/reachability_controller.dart';

/// How often the host list checks whether each server answers.
///
/// Named steps with a 30 s floor, not a free field — see
/// [ReachabilityInterval] for why the floor is the point.
class ReachabilityTile extends ConsumerWidget {
  const ReachabilityTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final interval = ref.watch(effectiveReachabilityIntervalProvider);

    String labelFor(ReachabilityInterval value) => switch (value) {
      ReachabilityInterval.off => l10n.settingsReachabilityOff,
      ReachabilityInterval.seconds30 => l10n.settingsReachability30s,
      ReachabilityInterval.minute1 => l10n.settingsReachability1m,
      ReachabilityInterval.minutes5 => l10n.settingsReachability5m,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(PiconsRegular.pulse),
          title: Text(l10n.settingsReachability),
          subtitle: Text(l10n.settingsReachabilityBody),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          child: SegmentedButton<ReachabilityInterval>(
            segments: [
              for (final value in ReachabilityInterval.values)
                ButtonSegment(value: value, label: Text(labelFor(value))),
            ],
            selected: {interval},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => ref
                .read(reachabilityIntervalSettingProvider.notifier)
                .set(selection.first),
          ),
        ),
      ],
    );
  }
}
