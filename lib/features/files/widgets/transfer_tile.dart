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
  const TransferTile({required this.job, super.key});

  final TransferJob job;

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
                if (job.failed)
                  Text(
                    job.error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.error,
                    ),
                  )
                else
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
            job.failed
                ? l10n.filesTransferFailed
                : total == null
                ? humanFileSize(job.transferred)
                : '${humanFileSize(job.transferred)} / ${humanFileSize(total)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
