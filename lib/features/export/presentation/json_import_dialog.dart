import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/error/error_logger.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/json_import_plan.dart';
import '../domain/portable_export.dart';
import '../portable_export_service.dart';

/// Settings → Hosts → Import from JSON: pick a file, show what it would
/// change, and write it only once the user agrees.
Future<void> importJson(
  BuildContext context,
  WidgetRef ref, {
  PortableExportService? service,
}) async {
  final l10n = AppLocalizations.of(context);
  final PortableExportService files =
      service ?? ref.read(portableExportServiceProvider);
  final picked = await files.pick(PortableExportService.jsonTypeGroup);
  if (picked == null || !context.mounted) return;

  final JsonImportPlan plan;
  try {
    plan = await ref
        .read(portableExportControllerProvider)
        .plan(utf8.decode(picked.bytes, allowMalformed: true));
  } on PortableExportException catch (error) {
    if (context.mounted) {
      context.toast(portableExportProblemText(l10n, error), isError: true);
    }
    return;
  } on Object catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'import-json');
    if (context.mounted) {
      context.toast(l10n.importJsonReadFailed, isError: true);
    }
    return;
  }
  if (!context.mounted) return;

  final rule = await showDialog<ConflictRule>(
    context: context,
    builder: (_) => JsonImportDialog(plan: plan, source: picked.name),
  );
  if (rule == null || !context.mounted) return;

  try {
    final changes = await ref
        .read(portableExportControllerProvider)
        .apply(plan, rule);
    if (context.mounted) {
      context.toast(
        l10n.importJsonDone(
          changes.hosts.length,
          changes.tunnels.length,
          changes.snippets.length,
        ),
      );
    }
  } on Object catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'import-json');
    if (context.mounted) context.toast('$error', isError: true);
  }
}

/// The sentence for a file that could not be read.
String portableExportProblemText(
  AppLocalizations l10n,
  PortableExportException error,
) => switch (error.problem) {
  PortableExportProblem.notJson => l10n.importJsonNotJson,
  PortableExportProblem.notAnExport => l10n.importJsonNotExport,
  PortableExportProblem.newerVersion => l10n.importJsonNewer(
    error.version ?? 0,
    PortableExport.version,
  ),
  PortableExportProblem.invalidVersion => l10n.importJsonInvalidVersion,
  PortableExportProblem.malformed => l10n.importJsonMalformed(
    error.detail ?? '?',
  ),
};

/// The preview. Pops the [ConflictRule] to apply, or null to cancel.
class JsonImportDialog extends StatefulWidget {
  const JsonImportDialog({required this.plan, required this.source, super.key});

  final JsonImportPlan plan;
  final String source;

  static const confirmKey = ValueKey('json-import-confirm');

  @override
  State<JsonImportDialog> createState() => _JsonImportDialogState();
}

class _JsonImportDialogState extends State<JsonImportDialog> {
  /// Merge by default: the likeliest reading of "the same server, saved on
  /// another device" is that it *is* the same server, and a duplicate row is
  /// the more annoying mistake to undo.
  var _rule = ConflictRule.merge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = widget.plan;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final changes = plan.resolve(_rule);

    final also = <String>[
      if (plan.groups.changes > 0)
        l10n.importJsonGroups(plan.groups.added, plan.groups.updated),
      if (changes.tunnels.isNotEmpty)
        l10n.importJsonTunnels(changes.tunnels.length),
      if (plan.snippets.changes > 0)
        l10n.importJsonSnippets(plan.snippets.added, plan.snippets.updated),
      if (plan.knownHostsAdded > 0)
        l10n.importJsonKnownHosts(plan.knownHostsAdded),
    ];

    return AlertDialog(
      icon: const Icon(PiconsRegular.fileArrowDown),
      title: Text(l10n.importJsonTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxMessageWidth + Spacing.xxxl * 3,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.importJsonFrom(widget.source),
                style: Mono.apply(muted),
              ),
              const SizedBox(height: Spacing.lg),
              if (plan.isEmpty)
                _CountRow(
                  icon: PiconsRegular.checkCircle,
                  color: scheme.onSurfaceVariant,
                  text: l10n.importJsonNothing,
                )
              else ...[
                if (plan.newHosts > 0)
                  _CountRow(
                    icon: PiconsRegular.plusCircle,
                    color: scheme.primary,
                    text: l10n.importJsonHostsNew(plan.newHosts),
                  ),
                if (plan.updatedHosts > 0)
                  _CountRow(
                    icon: PiconsRegular.arrowClockwise,
                    color: scheme.primary,
                    text: l10n.importJsonHostsUpdated(plan.updatedHosts),
                  ),
                if (plan.unchangedHosts > 0)
                  _CountRow(
                    icon: PiconsRegular.checkCircle,
                    color: scheme.onSurfaceVariant,
                    text: l10n.importJsonHostsUnchanged(plan.unchangedHosts),
                  ),
              ],
              if (plan.conflicts > 0) ...[
                _CountRow(
                  icon: PiconsRegular.warning,
                  color: scheme.tertiary,
                  text: l10n.importJsonConflicts(plan.conflicts),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: Spacing.xl,
                    bottom: Spacing.sm,
                  ),
                  child: Text(l10n.importJsonConflictsBody, style: muted),
                ),
                for (final row in plan.conflictRows)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: Spacing.xl,
                      bottom: Spacing.xs,
                    ),
                    child: Text(
                      l10n.importJsonConflictRow(
                        row.incoming.label,
                        row.existing!.label,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: Spacing.sm),
                SegmentedButton<ConflictRule>(
                  segments: [
                    ButtonSegment(
                      value: ConflictRule.merge,
                      icon: const Icon(PiconsRegular.arrowsMerge),
                      label: Text(l10n.importJsonMerge),
                    ),
                    ButtonSegment(
                      value: ConflictRule.addAsNew,
                      icon: const Icon(PiconsRegular.copySimple),
                      label: Text(l10n.importJsonAddAsNew),
                    ),
                  ],
                  selected: {_rule},
                  onSelectionChanged: (value) =>
                      setState(() => _rule = value.single),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  _rule == ConflictRule.merge
                      ? l10n.importJsonMergeHelp
                      : l10n.importJsonAddAsNewHelp,
                  style: muted,
                ),
              ],
              if (also.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Text(l10n.importJsonAlso, style: theme.textTheme.labelLarge),
                const SizedBox(height: Spacing.xs),
                for (final line in also)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xxs),
                    child: Text('• $line'),
                  ),
              ],
              if (plan.knownHostsConflicting > 0) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  l10n.importJsonKnownHostsConflicting(
                    plan.knownHostsConflicting,
                  ),
                  style: muted,
                ),
              ],
              if (plan.missingKeys.isNotEmpty) ...[
                const SizedBox(height: Spacing.lg),
                _MissingKeys(keys: plan.missingKeys),
              ],
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
          key: JsonImportDialog.confirmKey,
          onPressed: changes.isEmpty
              ? null
              : () => Navigator.of(context).pop(_rule),
          child: Text(l10n.importJsonAction),
        ),
      ],
    );
  }
}

/// The keys the file's hosts use that this device lacks, and what to do.
class _MissingKeys extends StatelessWidget {
  const _MissingKeys({required this.keys});

  final List<MissingKey> keys;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PiconsRegular.key, size: 18, color: scheme.tertiary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    l10n.importJsonMissingKeysTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(l10n.importJsonMissingKeysBody, style: muted),
            for (final key in keys) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                '${key.label} · ${key.keyType}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (key.fingerprint case final fingerprint?)
                SelectableText(
                  fingerprint,
                  style: Mono.apply(theme.textTheme.bodySmall),
                ),
              Text(
                l10n.importJsonMissingKeyHosts(key.hostLabels.join(', ')),
                style: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Spacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
