import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Confirms the name a picked file will be written under.
///
/// Not ceremony — a correction. Android's file picker hands back a name of its
/// own making rather than the one on screen: a key called `test_key` arrives
/// as `test_key.bin`, an extension guessed from the MIME type of a file that
/// had none. Uploading that silently renames the user's file on their server,
/// which is the kind of thing you discover later, from a script that no longer
/// finds it.
///
/// So the name is shown before it is used, prefilled and editable, which also
/// makes "upload this, but call it something else" possible without a second
/// feature. Only for a single file: asking this once per file for a multi-
/// select would be worse than the problem.
///
/// Returns null if cancelled.
Future<String?> showUploadNameDialog(
  BuildContext context, {
  required String suggestion,
  required String destination,
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: suggestion);
  // The stem, so a rename does not mean retyping the extension — and so the
  // guessed `.bin` is already selected for whoever wants it gone.
  final dot = suggestion.lastIndexOf('.');
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: dot > 0 ? dot : suggestion.length,
  );

  return showDialog<String>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      void submit() {
        final name = controller.text.trim();
        if (name.isEmpty) return;
        Navigator.of(context).pop(name);
      }

      return AlertDialog(
        icon: const Icon(PiconsRegular.uploadSimple),
        title: Text(l10n.filesUploadTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.filesUploadAs),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              destination,
              style: Mono.apply(theme.textTheme.bodySmall)
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(onPressed: submit, child: Text(l10n.filesUpload)),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
