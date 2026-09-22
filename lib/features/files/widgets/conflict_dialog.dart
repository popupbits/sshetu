import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/transfer_plan.dart';

/// Asks what a folder transfer should do about files that already exist at
/// the destination. Asked once per job; the answer applies to every
/// conflicting file in it.
///
/// Dismissing the dialog is [ConflictChoice.cancel] — a barrier tap is never
/// consent to overwrite anything.
Future<ConflictChoice> showConflictDialog(
  BuildContext context, {
  required String folderName,
  required int count,
}) async {
  final choice = await showDialog<ConflictChoice>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        icon: const Icon(PiconsRegular.warning),
        title: Text(l10n.filesConflictTitle),
        content: Text(l10n.filesConflictBody(count, folderName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ConflictChoice.cancel),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(ConflictChoice.skipExisting),
            child: Text(l10n.filesConflictSkip),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(ConflictChoice.overwrite),
            child: Text(l10n.filesConflictOverwrite),
          ),
        ],
      );
    },
  );
  return choice ?? ConflictChoice.cancel;
}
