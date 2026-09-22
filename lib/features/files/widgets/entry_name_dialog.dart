import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/entry_name.dart';

/// Asks for a file or folder name — shared by Rename and New folder on both
/// panes.
///
/// [validate] is the controller's check against the folder's current
/// listing; its verdict shows inline, under the field, as the user types,
/// and the confirm button stays disabled while there is one. An empty field
/// is not flagged until the user has typed something or tried to submit —
/// "Enter a name" in red before they have had the chance is scolding, not
/// help.
///
/// When [selectStem] is set the name is preselected up to its extension, so
/// renaming `notes.txt` means typing the new stem, not retyping `.txt`.
///
/// Returns the trimmed name, or null if cancelled.
Future<String?> showEntryNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required IconData icon,
  required EntryNameError? Function(String name) validate,
  String initial = '',
  bool selectStem = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => EntryNameDialog(
    title: title,
    confirmLabel: confirmLabel,
    icon: icon,
    validate: validate,
    initial: initial,
    selectStem: selectStem,
  ),
);

/// The dialog [showEntryNameDialog] opens. Public so a widget test can pump
/// it directly.
class EntryNameDialog extends StatefulWidget {
  const EntryNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.icon,
    required this.validate,
    this.initial = '',
    this.selectStem = false,
    super.key,
  });

  final String title;
  final String confirmLabel;
  final IconData icon;
  final EntryNameError? Function(String name) validate;
  final String initial;
  final bool selectStem;

  static const fieldKey = ValueKey('entryNameField');

  @override
  State<EntryNameDialog> createState() => _EntryNameDialogState();
}

class _EntryNameDialogState extends State<EntryNameDialog> {
  late final TextEditingController _text;
  var _touched = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _text = TextEditingController(text: initial);
    final dot = initial.lastIndexOf('.');
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.selectStem && dot > 0 ? dot : initial.length,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _touched = true);
    if (widget.validate(_text.text) != null) return;
    Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = widget.validate(_text.text);
    final shown = error == EntryNameError.empty && !_touched ? null : error;

    return AlertDialog(
      icon: Icon(widget.icon),
      title: Text(widget.title),
      content: TextField(
        key: EntryNameDialog.fieldKey,
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.filesNameLabel,
          errorText: shown == null
              ? null
              : entryNameErrorText(l10n, shown, _text.text.trim()),
        ),
        onChanged: (_) => setState(() => _touched = true),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: error == null ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// The message shown for [error] about the typed [name].
String entryNameErrorText(
  AppLocalizations l10n,
  EntryNameError error,
  String name,
) => switch (error) {
  EntryNameError.empty => l10n.filesNameEmpty,
  EntryNameError.containsSeparator => l10n.filesNameSeparator,
  EntryNameError.reserved => l10n.filesNameReserved,
  EntryNameError.exists => l10n.filesNameExists(name),
};
