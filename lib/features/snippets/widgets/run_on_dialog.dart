import 'package:material_ui/material_ui.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../snippet_delivery.dart';

/// Chooses which open sessions a snippet runs in.
///
/// Only tabs that are already open are offered — this never dials a server.
/// Running a command on a machine should mean the user can see that
/// machine's terminal and what the command did to it; a headless connection
/// would run it somewhere nobody is watching. A tab that is open but not
/// connected is listed, disabled, so the user can see why it is missing.
class RunOnDialog extends StatefulWidget {
  const RunOnDialog({required this.targets, required this.initial, super.key});

  final List<SnippetTarget> targets;

  /// Ids ticked when the dialog opens — the session the picker was opened
  /// from.
  final Set<String> initial;

  /// The chosen sessions, or null when cancelled.
  static Future<List<SnippetTarget>?> show(
    BuildContext context, {
    required List<SnippetTarget> targets,
    required Set<String> initial,
  }) => showDialog<List<SnippetTarget>>(
    context: context,
    builder: (_) => RunOnDialog(targets: targets, initial: initial),
  );

  @override
  State<RunOnDialog> createState() => _RunOnDialogState();
}

class _RunOnDialogState extends State<RunOnDialog> {
  late final Set<String> _selected = {
    for (final target in widget.targets)
      if (target.isLive && widget.initial.contains(target.id)) target.id,
  };

  List<SnippetTarget> get _live => [
    for (final target in widget.targets)
      if (target.isLive) target,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final live = _live;
    final allSelected = live.isNotEmpty && _selected.length == live.length;

    return AlertDialog(
      title: Text(l10n.snippetRunOnTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: Spacing.lg),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                key: const Key('runOn.all'),
                value: allSelected,
                onChanged: live.isEmpty
                    ? null
                    : (value) => setState(() {
                        _selected
                          ..clear()
                          ..addAll(
                            value ?? false ? live.map((t) => t.id) : const [],
                          );
                      }),
                title: Text(l10n.snippetRunOnAll),
              ),
              const Divider(height: 1),
              for (final target in widget.targets)
                CheckboxListTile(
                  key: Key('runOn.${target.id}'),
                  value: _selected.contains(target.id),
                  onChanged: target.isLive
                      ? (value) => setState(() {
                          value ?? false
                              ? _selected.add(target.id)
                              : _selected.remove(target.id);
                        })
                      : null,
                  title: Text(target.title),
                  subtitle: Text(
                    target.isLive
                        ? target.address
                        : l10n.snippetRunOnNotConnected,
                    style: target.isLive
                        ? Mono.apply(theme.textTheme.bodySmall)
                        : null,
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
          key: const Key('runOn.confirm'),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                  for (final target in widget.targets)
                    if (_selected.contains(target.id)) target,
                ]),
          child: Text(l10n.snippetRunOnConfirm(_selected.length)),
        ),
      ],
    );
  }
}
