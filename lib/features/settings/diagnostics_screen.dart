import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/error/error_logger.dart';
import '../../core/error/error_record.dart';
import '../../core/theme/terminal_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/feedback.dart';
import '../../core/ui/views.dart';
import '../../core/util/launcher.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';

/// What the app has gone wrong at, most recent first.
///
/// This exists so a user can tell you *what* broke instead of "it crashed".
/// Nothing here leaves the device unless they tap share.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logger = ErrorLogger.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsDiagnostics),
        actions: [
          ValueListenableBuilder<List<ErrorRecord>>(
            valueListenable: logger.records,
            builder: (context, records, _) {
              if (records.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(PiconsRegular.shareNetwork),
                    tooltip: l10n.diagnosticsShare,
                    onPressed: () => Launcher.shareText(
                      logger.export(),
                      subject: l10n.diagnosticsShareSubject,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.diagnosticsClear,
                    onPressed: () => _confirmClear(context, logger),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<ErrorRecord>>(
          valueListenable: logger.records,
          builder: (context, records, _) {
            if (records.isEmpty) {
              return EmptyView(
                icon: PiconsRegular.bug,
                title: l10n.diagnosticsEmpty,
                message: l10n.diagnosticsEmptyBody,
              );
            }
            return ContentWidth(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                itemCount: records.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _ErrorTile(record: records[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, ErrorLogger logger) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await context.confirm(
      title: l10n.diagnosticsClearConfirm,
      confirmLabel: l10n.diagnosticsClear,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (confirmed) await logger.clear();
  }
}

/// One error, collapsed to its type and message until tapped.
///
/// The stack trace is behind the expansion on purpose: it is what a developer
/// needs and what makes the list unreadable for everyone else.
class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.record});

  final ErrorRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ExpansionTile(
      leading: Icon(PiconsRegular.bug, color: theme.colorScheme.error),
      title: Text(record.type, style: theme.textTheme.titleSmall),
      subtitle: Text(
        record.count > 1
            ? l10n.diagnosticsSeenTimes(record.count)
            : record.source,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        0,
        Spacing.lg,
        Spacing.lg,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(record.message, style: theme.textTheme.bodyMedium),
        if (record.stack.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          // Horizontally scrollable rather than wrapped: a wrapped stack frame
          // is much harder to read than one you scroll.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                record.stack,
                style: Mono.apply(theme.textTheme.bodySmall),
              ),
            ),
          ),
        ],
        const SizedBox(height: Spacing.sm),
        Text(
          '${record.source} · ${record.lastSeen.toLocal()}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
