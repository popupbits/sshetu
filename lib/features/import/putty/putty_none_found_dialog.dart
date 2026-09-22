import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// "No PuTTY sessions found" — offered a `.reg` file instead. Pops true when
/// the user wants to choose one.
///
/// The body is capped like every other short message: an [AlertDialog] sizes
/// itself to its content, and a paragraph of text is as wide as it is
/// allowed to be, so on a desktop window it stretched the dialog to nearly
/// the full width of the screen.
class PuttyNoneFoundDialog extends StatelessWidget {
  const PuttyNoneFoundDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const cap = BoxConstraints(maxWidth: Breakpoints.maxMessageWidth);
    return AlertDialog(
      icon: const Icon(PiconsRegular.terminalWindow),
      // The title too, so a longer translation of it cannot widen the dialog
      // past its body.
      title: ConstrainedBox(
        constraints: cap,
        child: Text(l10n.puttyNoneFoundTitle),
      ),
      content: ConstrainedBox(
        constraints: cap,
        child: Text(l10n.puttyNoneFoundBody),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.puttyChooseFile),
        ),
      ],
    );
  }
}
