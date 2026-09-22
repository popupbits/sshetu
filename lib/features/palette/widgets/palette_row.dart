import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../domain/palette_ranking.dart';
import 'highlighted_text.dart';

/// One result: icon, title and subtitle with the matched characters drawn
/// bold in the accent colour, and what kind of thing it is.
class PaletteRow extends StatelessWidget {
  const PaletteRow({
    required this.ranked,
    required this.highlighted,
    required this.categoryLabel,
    required this.onTap,
    this.recentLabel,
    super.key,
  });

  final RankedPaletteItem ranked;
  final bool highlighted;
  final String categoryLabel;

  /// Shown instead of the category when the item floats up as recently used.
  final String? recentLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = ranked.item;
    final subtitle = item.subtitle;

    return ListTile(
      selected: highlighted,
      selectedTileColor: scheme.secondaryContainer,
      selectedColor: scheme.onSecondaryContainer,
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(item.icon, size: 20),
      title: HighlightedText(
        item.title,
        highlights: ranked.titleHighlights,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: subtitle == null
          ? null
          : HighlightedText(
              subtitle,
              highlights: ranked.subtitleHighlights,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
      trailing: Padding(
        padding: const EdgeInsets.only(left: Spacing.sm),
        child: Text(
          recentLabel ?? categoryLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
