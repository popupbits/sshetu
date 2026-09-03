import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../files/domain/format.dart' show relativeModified;

/// The signed-in half of the Sync settings row: last sync time, how many
/// local changes have not reached the backend yet, a manual trigger, and
/// whatever went wrong the last time one was attempted.
///
/// Only ever built while signed in — see `tiles.dart`, which shows the
/// existing "Sign in to sync" row instead when signed out and never builds
/// this at all. That matters beyond UI: reading [syncControllerProvider]
/// runs a handful of local `SELECT`s (see `SyncController.build`), and a
/// signed-out user should not pay for even that.
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(syncControllerProvider);

    return status.when(
      loading: () => ListTile(
        leading: const Icon(PiconsRegular.cloudCheck),
        title: Text(l10n.settingsSyncNow),
        subtitle: Text(l10n.settingsSyncSyncing),
      ),
      // A failure to even compute local pending/last-synced state (a database
      // error, not a sync failure) shows as an error row rather than a sync
      // attempt's own [SyncStatus.lastError], which is deliberately kept
      // separate — see that field's doc comment.
      error: (error, _) => ListTile(
        leading: Icon(PiconsRegular.cloudWarning, color: scheme.error),
        title: Text(l10n.settingsSyncNow),
        subtitle: Text('$error'),
      ),
      data: (value) {
        final lastSynced = value.lastSyncedAt == null
            ? l10n.settingsSyncNeverSynced
            : l10n.settingsSyncLastSyncedAt(
                relativeModified(
                  value.lastSyncedAt,
                  now: DateTime.now(),
                  nowLabel: l10n.timeNow,
                ),
              );
        final subtitle = value.lastError != null
            ? l10n.settingsSyncFailed(value.lastError!)
            : '$lastSynced · ${l10n.settingsSyncPendingCount(value.pendingCount)}';

        return ListTile(
          leading: Icon(
            value.lastError != null
                ? PiconsRegular.cloudWarning
                : PiconsRegular.cloudCheck,
            color: value.lastError != null ? scheme.error : null,
          ),
          title: Text(l10n.settingsSyncNow),
          subtitle: Text(
            subtitle,
            style: value.lastError != null
                ? TextStyle(color: scheme.error)
                : null,
          ),
          trailing: value.isSyncing
              ? const SizedBox(
                  width: Spacing.lg,
                  height: Spacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(PiconsRegular.arrowClockwise),
                  onPressed: () =>
                      ref.read(syncControllerProvider.notifier).syncNow(),
                ),
          onTap: value.isSyncing
              ? null
              : () => ref.read(syncControllerProvider.notifier).syncNow(),
        );
      },
    );
  }
}
