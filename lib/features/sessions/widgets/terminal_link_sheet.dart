import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/terminal_links.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/launcher.dart';
import '../../../l10n/app_localizations.dart';

/// Opens [raw], a link found in terminal output.
///
/// With [confirm] — a touch device, where a tap is also how you reach the
/// keyboard and a link is easy to hit by accident — a sheet shows the full
/// address with Open and Copy. Without it — a desktop, where the user already
/// said so by holding Ctrl or Cmd while clicking — it opens directly.
///
/// Either way only [TerminalLinks.allowedSchemes] are opened. Anything else is
/// refused with a message rather than silently ignored, so a link that does
/// nothing is not mistaken for a broken app.
Future<void> openTerminalLink(
  BuildContext context,
  String raw, {
  required bool confirm,
}) async {
  if (confirm) {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => TerminalLinkSheet(link: raw),
    );
    return;
  }
  await _open(context, raw);
}

Future<void> _open(BuildContext context, String raw) async {
  final l10n = AppLocalizations.of(context);
  final uri = TerminalLinks.openable(raw);
  if (uri == null) {
    context.toast(l10n.terminalLinkRefused, isError: true);
    return;
  }
  final opened = await Launcher.openUrl(uri.toString());
  if (!opened && context.mounted) {
    context.toast(l10n.terminalLinkOpenFailed, isError: true);
  }
}

Future<void> copyTerminalLink(BuildContext context, String raw) async {
  final l10n = AppLocalizations.of(context);
  await Clipboard.setData(ClipboardData(text: raw));
  if (context.mounted) context.toast(l10n.terminalLinkCopied);
}

/// The phone's "open this link?" sheet.
class TerminalLinkSheet extends StatelessWidget {
  const TerminalLinkSheet({required this.link, super.key});

  final String link;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final openable = TerminalLinks.openable(link) != null;
    // Outlives the sheet: the toast after Open or Copy belongs to the screen
    // underneath, not to a context that is about to be popped.
    final outer = Navigator.of(context).context;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.terminalLinkSheetTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: Spacing.sm),
            // The whole address, never truncated: the point of asking is that
            // the user can see where the link really goes.
            SelectableText(
              link,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: Mono.family,
                fontFamilyFallback: Mono.fallback,
              ),
            ),
            if (!openable) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                l10n.terminalLinkRefused,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(PiconsRegular.copy),
                  label: Text(l10n.terminalCopyLink),
                  onPressed: () {
                    Navigator.of(context).pop();
                    copyTerminalLink(outer, link);
                  },
                ),
                const SizedBox(width: Spacing.sm),
                FilledButton.icon(
                  icon: const Icon(PiconsRegular.arrowSquareOut),
                  label: Text(l10n.terminalOpenLink),
                  onPressed: openable
                      ? () {
                          Navigator.of(context).pop();
                          _open(outer, link);
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
