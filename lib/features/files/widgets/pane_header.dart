import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/format.dart';

/// The header every pane shares: an icon and label naming which side this is,
/// with a refresh action — useful the moment someone uploads or downloads
/// something from the *other* pane and this one's listing goes stale.
class PaneHeader extends StatelessWidget {
  const PaneHeader({
    required this.icon,
    required this.label,
    required this.onRefresh,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
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
            tooltip: AppLocalizations.of(context).actionRetry,
            icon: const Icon(PiconsRegular.arrowClockwise, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
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
