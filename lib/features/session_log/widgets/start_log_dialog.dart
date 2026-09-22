import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/log_format.dart';

/// Asks which format to log in, and says plainly what ends up in the file.
///
/// Returns the chosen format, or null when dismissed.
Future<SessionLogFormat?> showStartLogDialog(
  BuildContext context, {
  required String sessionTitle,
  required SessionLogFormat initial,
}) => showDialog<SessionLogFormat>(
  context: context,
  builder: (_) => StartLogDialog(sessionTitle: sessionTitle, initial: initial),
);

class StartLogDialog extends StatefulWidget {
  const StartLogDialog({
    required this.sessionTitle,
    required this.initial,
    super.key,
  });

  final String sessionTitle;
  final SessionLogFormat initial;

  @override
  State<StartLogDialog> createState() => _StartLogDialogState();
}

class _StartLogDialogState extends State<StartLogDialog> {
  late SessionLogFormat _format = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      key: const Key('sessionLog.startDialog'),
      title: Text(l10n.sessionLogStartTitle(widget.sessionTitle)),
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(0, Spacing.lg, 0, Spacing.sm),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<SessionLogFormat>(
              groupValue: _format,
              onChanged: (format) {
                if (format != null) setState(() => _format = format);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final format in SessionLogFormat.values)
                    RadioListTile<SessionLogFormat>(
                      key: Key('sessionLog.format.${format.id}'),
                      value: format,
                      title: Text(sessionLogFormatLabel(l10n, format)),
                      subtitle: Text(sessionLogFormatHint(l10n, format)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.xl,
                Spacing.md,
                Spacing.xl,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PiconsRegular.info,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      l10n.sessionLogPrivacyNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('sessionLog.start'),
          onPressed: () => Navigator.of(context).pop(_format),
          child: Text(l10n.sessionLogStartAction),
        ),
      ],
    );
  }
}

String sessionLogFormatLabel(AppLocalizations l10n, SessionLogFormat format) =>
    switch (format) {
      SessionLogFormat.plain => l10n.sessionLogFormatPlain,
      SessionLogFormat.raw => l10n.sessionLogFormatRaw,
      SessionLogFormat.asciicast => l10n.sessionLogFormatAsciicast,
    };

String sessionLogFormatHint(AppLocalizations l10n, SessionLogFormat format) =>
    switch (format) {
      SessionLogFormat.plain => l10n.sessionLogFormatPlainHint,
      SessionLogFormat.raw => l10n.sessionLogFormatRawHint,
      SessionLogFormat.asciicast => l10n.sessionLogFormatAsciicastHint,
    };
