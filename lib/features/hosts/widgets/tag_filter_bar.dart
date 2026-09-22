import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../hosts_controller.dart';

/// One row of tag chips under the search field; tapping narrows the list.
///
/// A single horizontally-scrolling row rather than a wrap: thirty tags must
/// not push the hosts off a phone screen. Absent entirely when no host has a
/// tag, so the feature costs nothing to someone who does not use it.
class TagFilterBar extends ConsumerWidget {
  const TagFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(hostTagsProvider);
    final selected = ref.watch(hostTagFilterProvider);
    final selectedLower = {for (final t in selected) t.toLowerCase()};

    // A selected tag nobody carries any more (its last host was edited) stays
    // visible, or the list would be filtered by a chip the user cannot see
    // and so cannot turn off.
    final tags = [
      ...available,
      ...selected.where(
        (s) => !available.any((a) => a.toLowerCase() == s.toLowerCase()),
      ),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        children: [
          if (selected.isNotEmpty) ...[
            Center(
              child: IconButton(
                tooltip: l10n.hostsTagFilterClear,
                icon: const Icon(PiconsRegular.funnelSimpleX, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    ref.read(hostTagFilterProvider.notifier).clear(),
              ),
            ),
            const SizedBox(width: Spacing.xs),
          ],
          for (final tag in tags) ...[
            Center(
              child: FilterChip(
                label: Text(tag),
                selected: selectedLower.contains(tag.toLowerCase()),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) =>
                    ref.read(hostTagFilterProvider.notifier).toggle(tag),
              ),
            ),
            const SizedBox(width: Spacing.sm),
          ],
        ],
      ),
    );
  }
}
