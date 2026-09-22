import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';

/// What follows the pointer while a row is dragged between panes: the icon
/// and name of what is moving, or how many things are.
///
/// Its own [Material]: drag feedback is drawn in the overlay, outside every
/// ancestor that would otherwise give text a style and ink a surface.
class DragFeedback extends StatelessWidget {
  const DragFeedback({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(Radii.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: Spacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
