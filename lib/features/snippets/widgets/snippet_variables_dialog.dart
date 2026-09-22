import 'package:material_ui/material_ui.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/snippet_template.dart';
import '../snippet_delivery.dart';

/// Asks for every user variable a snippet has, in one dialog.
///
/// One field per name however often it appears in the body, prefilled with
/// its default. A live preview underneath shows the exact command that will
/// be typed — the last look anyone gets before Run presses Enter on it.
class SnippetVariablesDialog extends StatefulWidget {
  const SnippetVariablesDialog({
    required this.variables,
    required this.action,
    required this.preview,
    super.key,
  });

  final List<SnippetVariable> variables;
  final SnippetAction action;

  /// The rendered command for the values typed so far.
  final String Function(Map<String, String> values) preview;

  /// The answers, or null when the dialog was cancelled.
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required List<SnippetVariable> variables,
    required SnippetAction action,
    required String Function(Map<String, String> values) preview,
  }) => showDialog<Map<String, String>>(
    context: context,
    builder: (_) => SnippetVariablesDialog(
      variables: variables,
      action: action,
      preview: preview,
    ),
  );

  @override
  State<SnippetVariablesDialog> createState() => _SnippetVariablesDialogState();
}

class _SnippetVariablesDialogState extends State<SnippetVariablesDialog> {
  late final Map<String, TextEditingController> _fields = {
    for (final variable in widget.variables)
      variable.name: TextEditingController(text: variable.defaultValue ?? ''),
  };

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _values => {
    for (final entry in _fields.entries) entry.key: entry.value.text,
  };

  void _submit() => Navigator.of(context).pop(_values);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = _fields.keys.toList();

    return AlertDialog(
      title: Text(l10n.snippetVariablesTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < names.length; i++) ...[
                if (i > 0) const SizedBox(height: Spacing.md),
                TextField(
                  key: Key('snippetVariable.${names[i]}'),
                  controller: _fields[names[i]],
                  autofocus: i == 0,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: Mono.apply(theme.textTheme.bodyMedium),
                  decoration: InputDecoration(
                    labelText: names[i],
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: i == names.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (i == names.length - 1) _submit();
                  },
                ),
              ],
              const SizedBox(height: Spacing.lg),
              Text(
                l10n.snippetVariablesPreview,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
                child: Text(
                  widget.preview(_values),
                  key: const Key('snippetVariables.preview'),
                  style: Mono.apply(theme.textTheme.bodySmall),
                ),
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
          onPressed: _submit,
          child: Text(
            widget.action == SnippetAction.run
                ? l10n.snippetRun
                : l10n.snippetInsert,
          ),
        ),
      ],
    );
  }
}
