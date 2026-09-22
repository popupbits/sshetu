import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/snippet.dart';
import '../open_snippets.dart';
import '../snippets_controller.dart';

/// One saved snippet, as a row: its name, the command in monospace, and its
/// tags. Tapping edits it; the menu copies or deletes it.
class SnippetTile extends ConsumerWidget {
  const SnippetTile({required this.snippet, super.key});

  final Snippet snippet;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: snippet.body));
    if (context.mounted) {
      context.toast(AppLocalizations.of(context).snippetCopied);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await context.confirm(
      title: l10n.snippetsDeleteConfirm,
      message: snippet.label,
      confirmLabel: l10n.snippetsDelete,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (confirmed) await ref.read(snippetsControllerProvider).delete(snippet);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = snippet.body.trim().split(RegExp('\r|\n'));

    return ListTile(
      key: Key('snippet.${snippet.id}'),
      onTap: () => openSnippetEditor(context, ref, snippetId: snippet.id),
      minVerticalPadding: Spacing.sm,
      leading: Icon(PiconsRegular.codeBlock, color: scheme.onSurfaceVariant),
      title: Text(snippet.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.length > 1 ? '${preview.first} …' : preview.first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Mono.apply(theme.textTheme.bodySmall)
                .copyWith(color: scheme.onSurfaceVariant),
          ),
          if (snippet.tags.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                for (final tag in snippet.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('snippet.copy.${snippet.id}'),
            tooltip: l10n.snippetCopy,
            icon: const Icon(PiconsRegular.copy, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () => _copy(context),
          ),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(PiconsRegular.pencilSimple),
                onPressed: () =>
                    openSnippetEditor(context, ref, snippetId: snippet.id),
                child: Text(l10n.snippetsEdit),
              ),
              MenuItemButton(
                key: Key('snippet.delete.${snippet.id}'),
                leadingIcon: Icon(PiconsRegular.trash, color: scheme.error),
                onPressed: () => _delete(context, ref),
                child: Text(l10n.snippetsDelete),
              ),
            ],
            builder: (context, controller, _) => IconButton(
              key: Key('snippet.menu.${snippet.id}'),
              tooltip: l10n.snippetsMore,
              icon: const Icon(PiconsRegular.dotsThreeVertical, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ],
      ),
    );
  }
}
