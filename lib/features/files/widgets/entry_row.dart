import 'package:material_ui/material_ui.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';

/// One file or directory, in either pane.
///
/// Takes primitive fields rather than a `RemoteEntry`/`LocalEntry`: the two
/// panes list different types, and a row that only needs a name, an icon, a
/// size and a modified time does not need to know which domain type it came
/// from. Density matches `HostTile` — a file listing is scanned the same way
/// a host list is, so the same compact density and a second line for
/// metadata (rather than a trailing cluster that would steal width from the
/// name) applies here too.
class EntryRow extends StatelessWidget {
  const EntryRow({
    required this.icon,
    required this.name,
    required this.isDirectory,
    required this.subtitle,
    this.permissions,
    this.selected,
    this.onTap,
    this.onSelectToggle,
    super.key,
  });

  final IconData icon;
  final String name;
  final bool isDirectory;

  /// Size and modified time, already formatted — this widget does no
  /// formatting of its own.
  final String subtitle;

  /// `drwxr-xr-x`, remote entries only — shown in the one monospace token so
  /// it lines up column-for-column down the pane the way `ls -l` does.
  final String? permissions;

  /// Non-null (true or false) while the pane is in multi-select mode: the
  /// leading icon becomes a checkbox showing this value instead. Null (the
  /// default, outside selection mode) shows the file-type icon as normal.
  final bool? selected;

  final VoidCallback? onTap;
  final VoidCallback? onSelectToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelecting = selected != null;

    return ListTile(
      onTap: isSelecting ? onSelectToggle : onTap,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: Spacing.sm,
      leading: isSelecting
          ? Checkbox(value: selected, onChanged: (_) => onSelectToggle?.call())
          : Icon(
              icon,
              size: 20,
              color: isDirectory ? scheme.primary : scheme.onSurfaceVariant,
            ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          if (permissions case final permissions?) ...[
            Text(
              permissions,
              style: Mono.apply(theme.textTheme.bodySmall)
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Spacing.sm),
          ],
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
