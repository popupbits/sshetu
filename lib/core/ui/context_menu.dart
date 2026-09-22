import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../util/responsive.dart';

/// One entry in a context menu.
///
/// Actions are **data**, not widgets, because the same list has to be rendered
/// two different ways: a popup under the pointer on desktop and a sheet from
/// the bottom on a phone. Building widgets at the call site would mean writing
/// every menu twice.
class MenuAction {
  const MenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Drawn in the error colour and, in a sheet, separated from the rest.
  final bool isDestructive;
}

/// Makes [child] carry a context menu.
///
/// **Right-click on desktop, long-press on touch**, which is what each
/// platform's users already do — and neither gesture exists on the other, so
/// wiring both costs nothing and there is no conflict to resolve.
///
/// The two presentations differ on purpose. A popup appears under the pointer,
/// where a mouse user is already looking. A phone shows a bottom sheet
/// instead: a popup at the finger is a popup *under the finger*, and the row
/// you meant is the one your hand is covering.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    required this.actions,
    required this.child,
    this.title,
    super.key,
  });

  /// Built on demand, so a menu can reflect state at the moment it opens
  /// rather than at the moment the row was built.
  final List<MenuAction> Function() actions;

  /// Shown as the sheet's heading on touch. Ignored on desktop, where a popup
  /// with a title is a dialog wearing a menu's clothes.
  final String? title;

  final Widget child;

  Future<void> _showPopup(BuildContext context, Offset globalPosition) async {
    final items = actions();
    if (items.isEmpty) return;

    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final theme = Theme.of(context);

    final chosen = await showMenu<MenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        for (final action in items)
          PopupMenuItem<MenuAction>(
            value: action,
            height: Chrome.menuRow,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: 16,
                  color: action.isDestructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.md),
                // Flexible: a popup menu is at most five units wide, and a
                // long label — or a long translation — must ellipsize rather
                // than overflow the row.
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: action.isDestructive
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    chosen?.onSelected();
  }

  Future<void> _showSheet(BuildContext context) async {
    final items = actions();
    if (items.isEmpty) return;
    final theme = Theme.of(context);

    final chosen = await showModalBottomSheet<MenuAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xl,
                  0,
                  Spacing.xl,
                  Spacing.md,
                ),
                child: Text(
                  title!,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            for (final action in items)
              ListTile(
                leading: Icon(
                  action.icon,
                  color: action.isDestructive ? theme.colorScheme.error : null,
                ),
                title: Text(
                  action.label,
                  style: action.isDestructive
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        ),
      ),
    );
    chosen?.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final touch = context.usesSoftwareKeyboard;

    return GestureDetector(
      // Right-click. Absent on touch platforms, so wiring it there is harmless.
      onSecondaryTapDown: touch
          ? null
          : (details) => _showPopup(context, details.globalPosition),
      // Long-press. On desktop this would fight with click-and-hold to select,
      // so it is only wired where there is no pointer.
      onLongPress: touch ? () => _showSheet(context) : null,
      child: child,
    );
  }
}
