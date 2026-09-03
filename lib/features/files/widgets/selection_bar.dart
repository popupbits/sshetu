import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Replaces the breadcrumb while a pane is in multi-select mode: how many
/// rows are checked, "select all", and the batch actions that apply to the
/// whole set — download/upload/delete acting on every checked file in one
/// go instead of one dialog per file.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    required this.count,
    required this.onSelectAll,
    required this.onDone,
    required this.actions,
    super.key,
  });

  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback onDone;
  final List<SelectionAction> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      height: Chrome.row,
      child: Row(
        children: [
          const SizedBox(width: Spacing.sm),
          IconButton(
            tooltip: l10n.actionCancel,
            icon: const Icon(PiconsRegular.x, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: onDone,
          ),
          Expanded(
            child: Text(
              l10n.filesSelectionCount(count),
              style: theme.textTheme.labelMedium,
            ),
          ),
          TextButton(onPressed: onSelectAll, child: Text(l10n.filesSelectAll)),
          for (final action in actions)
            IconButton(
              tooltip: action.label,
              icon: Icon(
                action.icon,
                size: 16,
                color: action.isDestructive ? theme.colorScheme.error : null,
              ),
              visualDensity: VisualDensity.compact,
              // Nothing to act on with an empty selection — greying the
              // button out is the difference between "disabled" and "does
              // this silently no-op if I tap it".
              onPressed: count == 0 ? null : action.onSelected,
            ),
        ],
      ),
    );
  }
}

/// One batch action offered by [SelectionBar] — a smaller sibling of
/// `MenuAction` (`core/ui/context_menu.dart`) without the desktop/touch
/// dispatch, since this always renders as a fixed toolbar row rather than a
/// menu.
class SelectionAction {
  const SelectionAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool isDestructive;
}
