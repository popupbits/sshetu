import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/error/error_logger.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../backup/presentation/open_backup.dart';
import '../portable_export_service.dart';

/// What the user chose in the export dialog.
enum ExportJsonChoice { export, backupInstead }

/// Settings → Hosts → Export as JSON: say what the file holds — and, as
/// loudly, what it does not — then write it.
Future<void> exportJson(
  BuildContext context,
  WidgetRef ref, {
  PortableExportService? service,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showDialog<ExportJsonChoice>(
    context: context,
    builder: (_) => const ExportJsonDialog(),
  );
  if (!context.mounted || choice == null) return;
  if (choice == ExportJsonChoice.backupInstead) {
    openBackupExport(context, ref);
    return;
  }

  try {
    final text = await ref.read(portableExportControllerProvider).exportText();
    final PortableExportService files =
        service ?? ref.read(portableExportServiceProvider);
    final result = await files.save(text);
    if (!context.mounted) return;
    switch (result.destination) {
      case ExportDestination.saved:
        context.toast(l10n.exportJsonSaved(result.path ?? ''));
      case ExportDestination.shared:
        context.toast(l10n.exportJsonShared);
      case ExportDestination.cancelled:
        break;
    }
  } on Object catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'export-json');
    if (context.mounted) {
      context.toast(l10n.exportJsonFailed('$error'), isError: true);
    }
  }
}

class ExportJsonDialog extends StatelessWidget {
  const ExportJsonDialog({super.key});

  static const exportKey = ValueKey('export-json-confirm');
  static const backupKey = ValueKey('export-json-backup');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(PiconsRegular.fileText),
      title: Text(l10n.exportJsonTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxMessageWidth + Spacing.xxxl * 3,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.exportJsonBody),
              const SizedBox(height: Spacing.lg),
              // The one thing someone must not misunderstand about this
              // file, so it is set apart rather than left in the paragraph.
              Card.filled(
                margin: EdgeInsets.zero,
                color: scheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        PiconsRegular.keyhole,
                        size: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          l10n.exportJsonNoSecrets,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: backupKey,
          onPressed: () =>
              Navigator.of(context).pop(ExportJsonChoice.backupInstead),
          child: Text(l10n.exportJsonBackupInstead),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: exportKey,
          onPressed: () => Navigator.of(context).pop(ExportJsonChoice.export),
          child: Text(l10n.exportJsonAction),
        ),
      ],
    );
  }
}
