import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/ssh/sftp_service.dart';
import '../../../core/ui/context_menu.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/file_icons.dart';
import '../domain/permissions.dart';
import '../file_browser_controller.dart';
import 'chmod_dialog.dart';
import 'entry_row.dart';
import 'pane_header.dart';
import 'path_bar.dart';
import 'selection_bar.dart';
import 'upload_name_dialog.dart';

/// The host's filesystem, browsed over the session's SFTP channel.
class RemotePane extends StatelessWidget {
  const RemotePane({required this.controller, super.key});

  final FileBrowserController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        PaneHeader(
          icon: PiconsRegular.hardDrives,
          label: l10n.filesRemote,
          onRefresh: controller.refreshRemote,
          sortField: controller.remoteSortField,
          sortAscending: controller.remoteSortAscending,
          onSort: controller.setRemoteSort,
          showHidden: controller.remoteShowHidden,
          onToggleHidden: controller.toggleRemoteShowHidden,
          selectionMode: controller.remoteSelectionMode,
          onToggleSelectionMode: controller.toggleRemoteSelectionMode,
          extraActions: [
            // Only where the local pane cannot reach the user's own files.
            // On a desktop there is a whole filesystem in the other pane and
            // a picker would be a second, worse way to do the same thing.
            if (controller.localIsSandboxed)
              IconButton(
                tooltip: l10n.filesUploadFromDevice,
                icon: const Icon(PiconsRegular.uploadSimple, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _uploadFromDevice(context, controller),
              ),
          ],
        ),
        controller.remoteSelectionMode
            ? SelectionBar(
                count: controller.remoteSelection.length,
                onSelectAll: controller.selectAllRemote,
                onDone: controller.toggleRemoteSelectionMode,
                actions: [
                  SelectionAction(
                    label: l10n.filesDownloadSelected,
                    icon: PiconsRegular.downloadSimple,
                    onSelected: controller.downloadSelected,
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
                currentPath: controller.remotePath,
                segments: controller.remoteAncestry,
                labelOf: controller.remoteLabel,
                onTap: controller.openRemote,
                onSubmit: controller.submitRemotePath,
              ),
        const Divider(height: 1),
        Expanded(
          child: controller.remoteEntries.when(
            loading: () => const LoadingView(),
            error: (error, _) => _RemoteFailureView(
              error: error,
              path: controller.remotePath,
              onRetry: controller.refreshRemote,
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
                      final selecting = controller.remoteSelectionMode;
                      final row = EntryRow(
                        icon: fileIcon(
                          isDirectory: entry.isDirectory,
                          name: entry.name,
                        ),
                        name: entry.name,
                        isDirectory: entry.isDirectory,
                        permissions: entry.permissions == null
                            ? null
                            : formatPermissions(entry.permissions!),
                        subtitle: paneRowSubtitle(
                          context,
                          isDirectory: entry.isDirectory,
                          nowLabel: l10n.timeNow,
                          size: entry.size,
                          modified: entry.modified,
                        ),
                        selected: selecting
                            ? controller.remoteSelection.contains(entry.path)
                            : null,
                        onTap: entry.isDirectory
                            ? () => controller.openRemote(entry.path)
                            : null,
                        onSelectToggle: () =>
                            controller.toggleRemoteSelected(entry.path),
                      );
                      if (selecting) return row;
                      return ContextMenuRegion(
                        // A builder, not a list: the shared menu re-reads its
                        // actions when it opens, so a row's menu reflects the
                        // entry as it is then rather than as it was when the
                        // list was laid out.
                        actions: () => [
                          if (!entry.isDirectory)
                            MenuAction(
                              label: l10n.filesDownload,
                              icon: PiconsRegular.downloadSimple,
                              onSelected: () => controller.download(entry),
                            ),
                          // A plain download on a phone puts the file where
                          // only this app can see it, which is not what
                          // anybody means by "download".
                          if (!entry.isDirectory && controller.localIsSandboxed)
                            MenuAction(
                              label: l10n.filesSaveToDevice,
                              icon: PiconsRegular.export,
                              onSelected: () =>
                                  _saveToDevice(context, controller, entry),
                            ),
                          MenuAction(
                            label: l10n.filesChmod,
                            icon: PiconsRegular.lockSimple,
                            onSelected: () =>
                                _chmod(context, controller, entry),
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

/// A permission-denied or not-found listing renders as its own state, not
/// the generic `ErrorView`: a user who cannot read `/root` needs to see that
/// plainly and know retrying will not help, which "Could not read /root:
/// permission denied." buried in a wall of `ErrorView` text does not make
/// obvious the way a dedicated icon and title do.
class _RemoteFailureView extends StatelessWidget {
  const _RemoteFailureView({
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
    final kind = error is SftpException
        ? (error as SftpException).kind
        : SftpFailureKind.other;

    return switch (kind) {
      SftpFailureKind.permissionDenied => EmptyView(
        icon: PiconsRegular.lockSimple,
        title: l10n.filesPermissionDeniedTitle,
        message: l10n.filesPermissionDeniedBody(path),
        action: OutlinedButton(
          onPressed: onRetry,
          child: Text(l10n.actionRetry),
        ),
      ),
      SftpFailureKind.notFound => EmptyView(
        icon: PiconsRegular.fileX,
        title: l10n.filesNotFoundTitle,
        message: l10n.filesNotFoundBody(path),
        action: OutlinedButton(
          onPressed: onRetry,
          child: Text(l10n.actionRetry),
        ),
      ),
      SftpFailureKind.other => ErrorView(
        message: '$error',
        onRetry: onRetry,
        retryLabel: l10n.actionRetry,
      ),
    };
  }
}

Future<void> _chmod(
  BuildContext context,
  FileBrowserController controller,
  RemoteEntry entry,
) async {
  final mode = await ChmodDialog.show(context, entry.permissions ?? 0);
  if (mode == null) return;
  try {
    await controller.chmodRemote(entry, mode);
  } on Object catch (e) {
    if (context.mounted) context.toast('$e', isError: true);
  }
}

/// Picks files off the device and uploads them into the current directory.
///
/// The system picker rather than the local pane, because on a phone the local
/// pane can only see this app's own storage — the photo or document the user
/// wants to send is never in it. The picker is the one component that can see
/// everything, and choosing a file in it *is* the permission grant.
Future<void> _uploadFromDevice(
  BuildContext context,
  FileBrowserController controller,
) async {
  final l10n = AppLocalizations.of(context);
  final picked = await openFiles();
  if (picked.isEmpty || !context.mounted) return;

  // One file gets its name confirmed, because the picker's idea of the name
  // is not always the file's — see [showUploadNameDialog]. Several files do
  // not: a dialog per file would be worse than the problem it solves.
  if (picked.length == 1) {
    final file = picked.first;
    final name = await showUploadNameDialog(
      context,
      suggestion: file.name,
      destination: controller.remotePath,
    );
    if (name == null) return;
    await controller.uploadPickedFile(localPath: file.path, name: name);
    if (context.mounted) context.toast(l10n.filesUploadedName(name));
    return;
  }

  for (final file in picked) {
    await controller.uploadPickedFile(localPath: file.path, name: file.name);
  }
  if (context.mounted) context.toast(l10n.filesUploadedName(picked.first.name));
}

/// Downloads [entry] and hands it to the system share sheet.
///
/// "Save to Files", a messaging app, another device — every destination the
/// phone has, and this app never asks for permission to write to any of them.
Future<void> _saveToDevice(
  BuildContext context,
  FileBrowserController controller,
  RemoteEntry entry,
) async {
  final path = await controller.downloadForExport(entry);
  // Null means the transfer failed or was cancelled, and the job row already
  // says so; a second message here would only repeat it.
  if (path == null || !context.mounted) return;

  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], fileNameOverrides: [entry.name]),
  );
}

Future<void> _delete(
  BuildContext context,
  FileBrowserController controller,
  RemoteEntry entry,
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
    await controller.deleteRemote(entry);
  } on Object catch (e) {
    if (context.mounted) context.toast('$e', isError: true);
  }
}

Future<void> _deleteSelected(
  BuildContext context,
  FileBrowserController controller,
) async {
  final l10n = AppLocalizations.of(context);
  final count = controller.remoteSelection.length;
  final confirmed = await context.confirm(
    title: l10n.filesDeleteConfirm,
    message: l10n.filesDeleteSelectedBody(count),
    confirmLabel: l10n.filesDelete,
    isDestructive: true,
  );
  if (!confirmed) return;
  final failures = await controller.deleteSelectedRemote();
  if (context.mounted && failures.isNotEmpty) {
    context.toast(failures.join('; '), isError: true);
  }
}
