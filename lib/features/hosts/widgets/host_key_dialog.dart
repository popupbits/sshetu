import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/ssh/host_key.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Asks whether to trust a host key seen for the first time.
///
/// Only ever shown for [HostKeyVerdict.unknown]. There is deliberately **no**
/// dialog for a changed key: the verifier refuses those outright, and offering
/// a "trust anyway" button here would undo the one guarantee that makes host
/// key verification worth having.
Future<bool> showHostKeyDialog(
  BuildContext context,
  HostKeyPresentation presentation,
) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);

  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(PiconsRegular.shieldWarning),
      title: Text(l10n.hostKeyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The authenticity of ${presentation.hostname}:'
            '${presentation.port} cannot be established. Trust it only if '
            'this fingerprint matches the one the server should have.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            '${l10n.hostKeyFingerprint} (${presentation.keyType})',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          // Monospace and selectable: the entire point is comparing it,
          // character by character, against what the server operator published.
          SelectableText(
            presentation.fingerprint,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.hostKeyTrust),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

/// Explains a refused connection when the host key changed.
///
/// Not a question — a statement. The connection is already refused by the time
/// this appears; the only way forward is to remove the pin deliberately from
/// the known-hosts screen, having established the host really was rebuilt.
Future<void> showHostKeyChangedDialog(
  BuildContext context,
  HostKeyPresentation presentation,
) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(PiconsRegular.warning, color: theme.colorScheme.error),
      title: Text(l10n.hostKeyChangedTitle),
      content: Text(presentation.describe(), style: theme.textTheme.bodyMedium),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    ),
  );
}
