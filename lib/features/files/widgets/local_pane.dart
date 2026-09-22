import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui/context_menu.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/local_fs_service.dart';
import '../domain/file_icons.dart';
import '../file_browser_controller.dart';
import 'entry_row.dart';
import 'file_actions.dart';
import 'pane_header.dart';
import 'path_bar.dart';
import 'selection_bar.dart';

/// This device's filesystem, browsed with `dart:io`.
class LocalPane extends StatelessWidget {
  const LocalPane({required this.controller, super.key});

  final FileBrowserController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        PaneHeader(
          icon: PiconsRegular.deviceMobile,
          label: l10n.filesLocal,
          onRefresh: controller.refreshLocal,
          sortField: controller.localSortField,
          sortAscending: controller.localSortAscending,
          onSort: controller.setLocalSort,
          showHidden: controller.localShowHidden,
          onToggleHidden: controller.toggleLocalShowHidden,
          selectionMode: controller.localSelectionMode,
          onToggleSelectionMode: controller.toggleLocalSelectionMode,
          extraActions: [
            IconButton(
              tooltip: l10n.filesNewFolder,
              icon: const Icon(PiconsRegular.folderPlus, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => createLocalFolder(context, controller),
            ),
          ],
        ),
        // See `FileBrowserController._localBoundary` / `file_browser_screen`
        // for what decided this and why — shown for as long as the pane is
        // confined, not just once, since it explains every directory this
        // pane will ever show rather than being a one-off toast someone can
        // miss.
        if (controller.localIsSandboxed)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xxs,
              Spacing.sm,
              Spacing.xxs,
            ),
            child: Text(
              l10n.filesSandboxNotice,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        controller.localSelectionMode
            ? SelectionBar(
                count: controller.localSelection.length,
                onSelectAll: controller.selectAllLocal,
                onDone: controller.toggleLocalSelectionMode,
                actions: [
                  SelectionAction(
                    label: l10n.filesUploadSelected,
                    icon: PiconsRegular.uploadSimple,
                    onSelected: () => controller.uploadSelected(
                      onConflict: conflictResolverFor(context),
                    ),
                  ),
                  SelectionAction(
                    label: l10n.filesDeleteSelected,
                    icon: PiconsRegular.trash,
                    isDestructive: true,
                    onSelected: () => _deleteSelected(context, controller),
                  ),
                ],
              )
            : PathBar(
                currentPath: controller.localPath,
                segments: controller.localAncestry,
                labelOf: controller.localLabel,
                onTap: controller.openLocal,
                onSubmit: controller.submitLocalPath,
              ),
        const Divider(height: 1),
        Expanded(
          child: controller.localEntries.when(
            loading: () => const LoadingView(),
            error: (error, _) => _LocalFailureView(
              error: error,
              path: controller.localPath,
              onRetry: controller.refreshLocal,
            ),
            data: (entries) => entries.isEmpty
                ? EmptyView(
                    icon: PiconsRegular.folderOpen,
                    title: l10n.filesEmptyTitle,
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final selecting = controller.localSelectionMode;
                      final row = EntryRow(
                        icon: fileIcon(
                          isDirectory: entry.isDirectory,
                          name: entry.name,
                        ),
                        name: entry.name,
                        isDirectory: entry.isDirectory,
                        subtitle: paneRowSubtitle(
                          context,
                          isDirectory: entry.isDirectory,
                          nowLabel: l10n.timeNow,
                          size: entry.size,
                          modified: entry.modified,
                        ),
                        selected: selecting
                            ? controller.localSelection.contains(entry.path)
                            : null,
                        onTap: entry.isDirectory
                            ? () => controller.openLocal(entry.path)
                            : null,
                        onSelectToggle: () =>
                            controller.toggleLocalSelected(entry.path),
                      );
                      if (selecting) return row;
                      return ContextMenuRegion(
                        // A builder, not a list: the shared menu re-reads its
                        // actions when it opens, so a row's menu reflects the
                        // entry as it is then rather than as it was when the
                        // list was laid out.
                        actions: () => [
                          // A folder uploads whole, as one job.
                          MenuAction(
                            label: l10n.filesUpload,
                            icon: PiconsRegular.uploadSimple,
                            onSelected: () => controller.upload(
                              entry,
                              onConflict: conflictResolverFor(context),
                            ),
                          ),
                          MenuAction(
                            label: l10n.filesRename,
                            icon: PiconsRegular.pencilSimple,
                            onSelected: () =>
                                renameLocalEntry(context, controller, entry),
                          ),
                          MenuAction(
                            label: l10n.filesDelete,
                            icon: PiconsRegular.trash,
                            isDestructive: true,
                            onSelected: () =>
                                _delete(context, controller, entry),
                          ),
                        ],
                        child: row,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// See `_RemoteFailureView` in `remote_pane.dart` — same three-state split,
/// mirrored for `LocalFsException`.
class _LocalFailureView extends StatelessWidget {
  const _LocalFailureView({
    required this.error,
    required this.path,
    required this.onRetry,
  });

  final Object error;
  final String path;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = error is LocalFsException
        ? (error as LocalFsException).kind
        : LocalFsFailureKind.other;

    return switch (kind) {
      LocalFsFailureKind.permissionDenied => EmptyView(
        icon: PiconsRegular.lockSimple,
        title: l10n.filesPermissionDeniedTitle,
        message: l10n.filesPermissionDeniedBody(path),
        action: OutlinedButton(
          onPressed: onRetry,
          child: Text(l10n.actionRetry),
        ),
      ),
      LocalFsFailureKind.notFound => EmptyView(
        icon: PiconsRegular.fileX,
        title: l10n.filesNotFoundTitle,
        message: l10n.filesNotFoundBody(path),
        action: OutlinedButton(
          onPressed: onRetry,
          child: Text(l10n.actionRetry),
        ),
      ),
      LocalFsFailureKind.other => ErrorView(
        message: '$error',
        onRetry: onRetry,
        retryLabel: l10n.actionRetry,
      ),
    };
  }
}

Future<void> _delete(
  BuildContext context,
  FileBrowserController controller,
  LocalEntry entry,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await context.confirm(
    title: l10n.filesDeleteConfirm,
    message: l10n.filesDeleteBody(entry.name),
    confirmLabel: l10n.filesDelete,
    isDestructive: true,
  );
  if (!confirmed) return;
  try {
    await controller.deleteLocal(entry);
  } on Object catch (e) {
    if (context.mounted) context.toast('$e', isError: true);
  }
}

Future<void> _deleteSelected(
  BuildContext context,
  FileBrowserController controller,
) async {
  final l10n = AppLocalizations.of(context);
  final count = controller.localSelection.length;
  final confirmed = await context.confirm(
    title: l10n.filesDeleteConfirm,
    message: l10n.filesDeleteSelectedBody(count),
    confirmLabel: l10n.filesDelete,
    isDestructive: true,
  );
  if (!confirmed) return;
  final failures = await controller.deleteSelectedLocal();
  if (context.mounted && failures.isNotEmpty) {
    context.toast(failures.join('; '), isError: true);
  }
}
