import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../l10n/app_localizations.dart';
import 'remote_file_editor_controller.dart';

/// Asks what to do when the file on the server changed after it was opened.
///
/// Dismissing is [SaveConflictChoice.cancel]: a barrier tap never overwrites
/// somebody else's change, and never throws away the user's own edits.
Future<SaveConflictChoice> showSaveConflictDialog(
  BuildContext context, {
  required String name,
}) async {
  final choice = await showDialog<SaveConflictChoice>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        icon: const Icon(PiconsRegular.warning),
        title: Text(l10n.editorConflictTitle),
        content: Text(l10n.editorConflictBody(name)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(SaveConflictChoice.cancel),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(SaveConflictChoice.reload),
            child: Text(l10n.editorConflictReload),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(SaveConflictChoice.overwrite),
            child: Text(l10n.editorConflictOverwrite),
          ),
        ],
      );
    },
  );
  return choice ?? SaveConflictChoice.cancel;
}
