import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/format.dart';
import '../file_browser_controller.dart';

/// One transfer's row: direction, name, and a progress bar that is
/// indeterminate until the source reports a size.
///
/// This exists because a large file moving with no feedback is
/// indistinguishable from a stalled connection — see the download/upload
/// contract in `core/ssh/sftp_service.dart`.
class TransferTile extends StatelessWidget {
  const TransferTile({required this.job, this.onCancel, super.key});

  final TransferJob job;

  /// Null once the job is done — see `TransferJob.canCancel`.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = job.total;
    final progress = total == null || total == 0
        ? null
        : (job.transferred / total).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            job.direction == TransferDirection.download
                ? PiconsRegular.fileArrowDown
                : PiconsRegular.fileArrowUp,
            size: 16,
            color: job.failed ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.xxs),
                if (job.isFolder && !job.preparing) ...[
                  Text(
                    folderStatusLine(l10n, job),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.xxs),
                ],
                if (job.failed)
                  Text(
                    job.error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.error,
                    ),
                  )
                else if (!job.cancelled)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: job.done ? 1 : progress,
                      minHeight: 4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            job.cancelled
                ? l10n.filesTransferCancelled
                : job.failed
                ? l10n.filesTransferFailed
                : job.preparing
                ? l10n.filesFolderPreparing
                : total == null
                ? humanFileSize(job.transferred)
                : '${humanFileSize(job.transferred)} / ${humanFileSize(total)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (job.canCancel)
            IconButton(
              tooltip: l10n.actionCancel,
              icon: const Icon(PiconsRegular.xCircle, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }
}

/// The second line of a folder job's row: how many files have moved, and
/// what the job left alone. A stopped job says "N of M files transferred"
/// rather than "N of M files", so it reads as a result, not a job still
/// running.
String folderStatusLine(AppLocalizations l10n, TransferJob job) {
  final stopped = job.done && (job.cancelled || job.failed);
  return [
    stopped
        ? l10n.filesFolderTransferred(job.filesDone, job.filesTotal)
        : l10n.filesFolderProgress(job.filesDone, job.filesTotal),
    if (job.skippedExisting > 0)
      l10n.filesFolderExistingSkipped(job.skippedExisting),
    if (job.skipped > 0) l10n.filesFolderSkipped(job.skipped),
  ].join(' · ');
}
