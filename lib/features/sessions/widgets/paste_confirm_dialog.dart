import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/paste_sanitizer.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// What the user chose in a [PasteConfirmDialog].
@immutable
class PasteDecision {
  const PasteDecision({required this.dontAskAgain});

  /// Whether "Don't ask again" was ticked when they chose Paste.
  final bool dontAskAgain;
}

/// Asks before a paste that would press Enter.
///
/// Shows what is about to be typed — the first [previewLines] lines, in the
/// terminal's own font so what you read is what the shell gets — and how many
/// hidden characters were already removed from it. Returns null for Cancel or
/// a barrier tap, so dismissing is never a yes.
class PasteConfirmDialog extends StatefulWidget {
  const PasteConfirmDialog({required this.paste, super.key});

  final SanitizedPaste paste;

  static const previewLines = 10;

  static Future<PasteDecision?> show(
    BuildContext context,
    SanitizedPaste paste,
  ) => showDialog<PasteDecision>(
    context: context,
    builder: (_) => PasteConfirmDialog(paste: paste),
  );

  @override
  State<PasteConfirmDialog> createState() => _PasteConfirmDialogState();
}

class _PasteConfirmDialogState extends State<PasteConfirmDialog> {
  var _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = widget.paste.lines;
    final shown = lines.take(PasteConfirmDialog.previewLines).toList();
    final hidden = lines.length - shown.length;
    final removed = widget.paste.removedCount;

    return AlertDialog(
      icon: const Icon(PiconsRegular.clipboardText),
      title: Text(l10n.pasteConfirmTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxMessageWidth,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pasteConfirmBody(lines.length)),
              const SizedBox(height: Spacing.md),
              Text(
                l10n.pasteConfirmLineCount(lines.length),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    shown.join('\n'),
                    key: const ValueKey('paste-preview'),
                    softWrap: false,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: Mono.family,
                      fontFamilyFallback: Mono.fallback,
                    ),
                  ),
                ),
              ),
              if (hidden > 0) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  l10n.pasteConfirmMoreLines(hidden),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (removed > 0) ...[
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    Icon(PiconsRegular.warning, size: 16, color: scheme.error),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        l10n.pasteHiddenRemoved(removed),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Spacing.sm),
              CheckboxListTile(
                value: _dontAskAgain,
                onChanged: (value) =>
                    setState(() => _dontAskAgain = value ?? false),
                title: Text(l10n.pasteDontAskAgain),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () =>
              Navigator.of(context)
                  .pop(PasteDecision(dontAskAgain: _dontAskAgain)),
          child: Text(l10n.pasteConfirmAction),
        ),
      ],
    );
  }
}
