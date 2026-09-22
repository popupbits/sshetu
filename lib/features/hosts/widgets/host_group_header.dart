import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/host_sections.dart';
import '../hosts_controller.dart';
import 'group_actions.dart';

/// The header above one group's hosts: tap to fold, menu to rename or delete.
///
/// Quiet on purpose — small caps-weight label, no fill — so the host rows stay
/// the loudest thing on the screen. It is a divider you can act on, not a
/// card competing with the servers it holds.
class HostGroupHeader extends ConsumerWidget {
  const HostGroupHeader({
    required this.section,
    required this.collapsed,
    super.key,
  });

  final HostSection section;
  final bool collapsed;

  /// Tall enough to be a comfortable touch target on a phone, short enough
  /// that ten folders do not read as ten more rows.
  static const double height = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final group = section.group;
    final name = group?.name ?? l10n.hostGroupUngrouped;

    return Semantics(
      button: true,
      expanded: !collapsed,
      label: collapsed
          ? l10n.hostGroupExpand(name)
          : l10n.hostGroupCollapse(name),
      excludeSemantics: false,
      child: InkWell(
        onTap: () =>
            ref.read(collapsedHostGroupsProvider.notifier).toggle(section.key),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.only(left: Spacing.lg, right: Spacing.xs),
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? PiconsRegular.caretRight
                      : PiconsRegular.caretDown,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),
                Icon(
                  group == null
                      ? PiconsRegular.folderSimpleDashed
                      : PiconsRegular.folderSimple,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  '${section.hosts.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (group != null)
                  MenuAnchor(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(PiconsRegular.pencilSimple),
                        onPressed: () => renameGroupFlow(context, ref, group),
                        child: Text(l10n.hostGroupRename),
                      ),
                      MenuItemButton(
                        leadingIcon: Icon(
                          PiconsRegular.trash,
                          color: scheme.error,
                        ),
                        onPressed: () => deleteGroupFlow(context, ref, group),
                        child: Text(l10n.hostGroupDelete),
                      ),
                    ],
                    builder: (context, controller, _) => IconButton(
                      icon: const Icon(PiconsRegular.dotsThree, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
