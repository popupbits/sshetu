import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/host_env.dart';

/// The host editor's list of environment variables: a name and a value per
/// row, rows added and removed freely.
///
/// Validated as part of the surrounding [Form] — see [HostEnv.problemAt] —
/// so a bad name stops Save the way a bad port does. Reports every edit
/// through [onChanged] as the raw pairs; the editor turns them into a map
/// with [HostEnv.fromPairs] when it saves.
class EnvVarsEditor extends StatefulWidget {
  const EnvVarsEditor({
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final Map<String, String> initial;
  final ValueChanged<List<(String, String)>> onChanged;

  @override
  State<EnvVarsEditor> createState() => _EnvVarsEditorState();
}

class _Row {
  _Row(String name, String value)
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _EnvVarsEditorState extends State<EnvVarsEditor> {
  late final List<_Row> _rows = [
    for (final MapEntry(:key, :value) in widget.initial.entries)
      _Row(key, value),
  ];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  List<(String, String)> get _pairs => [
    for (final row in _rows) (row.name.text, row.value.text),
  ];

  void _changed() => widget.onChanged(_pairs);

  void _add() {
    setState(() => _rows.add(_Row('', '')));
    _changed();
  }

  void _remove(int index) {
    setState(() => _rows.removeAt(index).dispose());
    _changed();
  }

  String? _message(AppLocalizations l10n, EnvVarProblem? problem) =>
      switch (problem) {
        null => null,
        EnvVarProblem.missingName => l10n.hostEditorEnvMissingName,
        EnvVarProblem.invalidName => l10n.hostEditorEnvInvalidName,
        EnvVarProblem.duplicateName => l10n.hostEditorEnvDuplicateName,
        EnvVarProblem.invalidValue => l10n.hostEditorEnvInvalidValue,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      key: const Key('hostEditor.env'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.hostEditorEnv),
        Text(
          l10n.hostEditorEnvHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final (index, row) in _rows.indexed) ...[
          const SizedBox(height: Spacing.md),
          Row(
            key: ValueKey(row),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: Key('hostEditor.env.name.$index'),
                  controller: row.name,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.hostEditorEnvName,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorMaxLines: 3,
                  ),
                  style: Mono.apply(theme.textTheme.bodyMedium),
                  onChanged: (_) => _changed(),
                  validator: (_) {
                    final problem = HostEnv.problemAt(_pairs, index);
                    return problem == EnvVarProblem.invalidValue
                        ? null
                        : _message(l10n, problem);
                  },
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: Key('hostEditor.env.value.$index'),
                  controller: row.value,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.hostEditorEnvValue,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorMaxLines: 3,
                  ),
                  style: Mono.apply(theme.textTheme.bodyMedium),
                  onChanged: (_) => _changed(),
                  validator: (_) {
                    final problem = HostEnv.problemAt(_pairs, index);
                    return problem == EnvVarProblem.invalidValue
                        ? _message(l10n, problem)
                        : null;
                  },
                ),
              ),
              IconButton(
                key: Key('hostEditor.env.remove.$index'),
                tooltip: l10n.hostEditorEnvRemove,
                icon: const Icon(PiconsRegular.minusCircle),
                onPressed: () => _remove(index),
              ),
            ],
          ),
        ],
        const SizedBox(height: Spacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('hostEditor.env.add'),
            onPressed: _add,
            icon: const Icon(PiconsRegular.plus),
            label: Text(l10n.hostEditorEnvAdd),
          ),
        ),
      ],
    );
  }
}
