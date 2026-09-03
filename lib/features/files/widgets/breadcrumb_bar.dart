import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';

/// A row of tappable path segments, root on the left, the current directory
/// (not tappable — it is already where the pane is) on the right.
///
/// A horizontally scrolling row rather than a fixed-width truncated string:
/// a path six levels deep on a build server is common, and the alternative —
/// eliding the middle — throws away exactly the segment someone taps to jump
/// up from `/var/log/nginx/sites` to `/var/log`.
class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({
    required this.segments,
    required this.labelOf,
    required this.onTap,
    super.key,
  });

  /// Full paths from the root down to (and including) the current directory.
  final List<String> segments;
  final String Function(String path) labelOf;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: Chrome.row,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        itemCount: segments.length,
        separatorBuilder: (context, index) => Center(
          child: Icon(
            PiconsRegular.caretRight,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        itemBuilder: (context, index) {
          final path = segments[index];
          final isCurrent = index == segments.length - 1;
          return Center(
            child: TextButton(
              onPressed: isCurrent ? null : () => onTap(path),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                disabledForegroundColor: theme.colorScheme.onSurface,
              ),
              child: Text(
                labelOf(path),
                style: isCurrent
                    ? theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )
                    : theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
