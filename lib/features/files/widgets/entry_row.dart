import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';

/// One file or directory, in either pane.
///
/// Takes primitive fields rather than a `RemoteEntry`/`LocalEntry`: the two
/// panes list different types, and a row that only needs a name, a size and a
/// modified time does not need to know which domain type it came from.
/// Density matches `HostTile` — a file listing is scanned the same way a host
/// list is.
class EntryRow extends StatelessWidget {
  const EntryRow({
    required this.name,
    required this.isDirectory,
    required this.subtitle,
    this.onTap,
    this.trailing,
    super.key,
  });

  final String name;
  final bool isDirectory;

  /// Size and modified time, already formatted — this widget does no
  /// formatting of its own.
  final String subtitle;

  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: Spacing.sm,
      leading: Icon(
        isDirectory ? PiconsRegular.folder : PiconsRegular.file,
        size: 20,
        color: isDirectory ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      trailing: trailing,
    );
  }
}
