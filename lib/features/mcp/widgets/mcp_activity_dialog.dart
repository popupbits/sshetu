import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../files/domain/format.dart';
import '../domain/audit_entry.dart';
import '../mcp_audit_controller.dart';

/// Opens the MCP activity log: full screen on a phone-sized window, a dialog
/// on a wide one.
Future<void> showMcpActivity(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const McpActivityDialog(),
);

/// Every MCP call, newest first: when, which client, which tool, on what,
/// and how it went. Clearable.
class McpActivityDialog extends ConsumerWidget {
  const McpActivityDialog({super.key});

  static String decisionLabel(AppLocalizations l10n, AuditDecision decision) =>
      switch (decision) {
        AuditDecision.read => l10n.mcpDecisionRead,
        AuditDecision.approved => l10n.mcpDecisionApproved,
        AuditDecision.remembered => l10n.mcpDecisionRemembered,
        AuditDecision.denied => l10n.mcpDecisionDenied,
        AuditDecision.timedOut => l10n.mcpDecisionTimedOut,
        AuditDecision.unavailable => l10n.mcpDecisionUnavailable,
        AuditDecision.rejected => l10n.mcpDecisionRejected,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(mcpAuditProvider);

    Future<void> clear() async {
      final confirmed = await context.confirm(
        title: l10n.mcpActivityClearTitle,
        confirmLabel: l10n.mcpActivityClear,
        cancelLabel: l10n.actionCancel,
        isDestructive: true,
      );
      if (confirmed) await ref.read(mcpAuditProvider.notifier).clear();
    }

    final list = entries.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Text(l10n.mcpActivityEmpty, textAlign: TextAlign.center),
            ),
          )
        : ListView.separated(
            key: const Key('mcp.activity.list'),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _EntryRow(entries[index]),
          );

    final clearButton = IconButton(
      key: const Key('mcp.activity.clear'),
      tooltip: l10n.mcpActivityClear,
      icon: const Icon(PiconsRegular.broom),
      onPressed: entries.isEmpty ? null : () => unawaited(clear()),
    );

    if (context.isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l10n.actionClose,
              icon: const Icon(PiconsRegular.x),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(l10n.mcpActivityTitle),
            actions: [clearButton],
          ),
          body: list,
        ),
      );
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxMessageWidth * 2,
          maxHeight: Breakpoints.maxMessageWidth * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.xl,
                Spacing.lg,
                Spacing.sm,
                Spacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.mcpActivityTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  clearButton,
                  IconButton(
                    tooltip: l10n.actionClose,
                    icon: const Icon(PiconsRegular.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: list),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow(this.entry);

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final local = entry.time.toLocal();
    final when =
        '${material.formatShortDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    final refused = switch (entry.decision) {
      AuditDecision.denied ||
      AuditDecision.timedOut ||
      AuditDecision.unavailable ||
      AuditDecision.rejected => true,
      _ => false,
    };
    final bytes = entry.resultBytes;
    final error = entry.error;
    final target = entry.target;

    return ListTile(
      title: Text('${entry.tool} · ${entry.client}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$when · ${McpActivityDialog.decisionLabel(l10n, entry.decision)}',
            style: TextStyle(color: refused ? scheme.error : null),
          ),
          if (target != null)
            Text(target, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (error != null)
            Text(
              error,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.error),
            )
          else if (bytes != null)
            Text(l10n.mcpActivityBytes(humanFileSize(bytes))),
        ],
      ),
    );
  }
}
