import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/util/sort_entries.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/format.dart';

/// The header every pane shares: an icon and label naming which side this
/// is, a sort menu, a hidden-files toggle, a select-mode toggle, and a
/// refresh action — useful the moment someone uploads or downloads
/// something from the *other* pane and this one's listing goes stale.
class PaneHeader extends StatelessWidget {
  const PaneHeader({
    required this.icon,
    required this.label,
    required this.onRefresh,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
    required this.showHidden,
    required this.onToggleHidden,
    required this.selectionMode,
    required this.onToggleSelectionMode,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRefresh;
  final SortField sortField;
  final bool sortAscending;
  final ValueChanged<SortField> onSort;
  final bool showHidden;
  final VoidCallback onToggleHidden;
  final bool selectionMode;
  final VoidCallback onToggleSelectionMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.sm, 0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
          ),
          IconButton(
            tooltip: showHidden ? l10n.filesHideHidden : l10n.filesShowHidden,
            icon: Icon(
              showHidden ? PiconsRegular.eye : PiconsRegular.eyeSlash,
              size: 16,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: onToggleHidden,
          ),
          PopupMenuButton<SortField>(
            tooltip: l10n.filesSortBy,
            icon: Icon(
              sortAscending
                  ? PiconsRegular.sortAscending
                  : PiconsRegular.sortDescending,
              size: 16,
            ),
            onSelected: onSort,
            itemBuilder: (context) => [
              _sortItem(SortField.name, l10n.filesSortName),
              _sortItem(SortField.size, l10n.filesSortSize),
              _sortItem(SortField.modified, l10n.filesSortModified),
            ],
          ),
          IconButton(
            tooltip: selectionMode ? l10n.actionCancel : l10n.filesSelect,
            icon: Icon(
              selectionMode ? PiconsRegular.xCircle : PiconsRegular.checkSquare,
              size: 16,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: onToggleSelectionMode,
          ),
          IconButton(
            tooltip: l10n.actionRetry,
            icon: const Icon(PiconsRegular.arrowClockwise, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SortField> _sortItem(SortField field, String label) =>
      PopupMenuItem(
        value: field,
        child: Row(
          children: [
            if (field == sortField)
              Icon(
                sortAscending
                    ? PiconsRegular.sortAscending
                    : PiconsRegular.sortDescending,
                size: 14,
              )
            else
              const SizedBox(width: 14),
            const SizedBox(width: Spacing.sm),
            Text(label),
          ],
        ),
      );
}

/// The second line of an entry row: size and age for a file, age alone for a
/// directory — a folder's "size" on most SFTP
/// servers is the size of its inode listing, not its contents, and showing
/// that number teaches the wrong lesson.
String paneRowSubtitle(
  BuildContext context, {
  required bool isDirectory,
  required String nowLabel,
  int? size,
  DateTime? modified,
}) {
  final age = relativeModified(
    modified,
    now: DateTime.now().toUtc(),
    nowLabel: nowLabel,
  );
  if (isDirectory) return age;
  return '${humanFileSize(size)} · $age';
}
