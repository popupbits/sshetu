import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/local_fs_service.dart';
import '../file_browser_controller.dart';
import 'breadcrumb_bar.dart';
import 'entry_row.dart';
import 'pane_header.dart';

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
        ),
        BreadcrumbBar(
          segments: controller.localAncestry,
          labelOf: controller.localLabel,
          onTap: controller.openLocal,
        ),
        const Divider(height: 1),
        Expanded(
          child: controller.localEntries.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: '$error',
              onRetry: controller.refreshLocal,
              retryLabel: l10n.actionRetry,
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
                      return EntryRow(
                        name: entry.name,
                        isDirectory: entry.isDirectory,
                        subtitle: paneRowSubtitle(
                          context,
                          isDirectory: entry.isDirectory,
                          nowLabel: l10n.timeNow,
                          size: entry.size,
                          modified: entry.modified,
                        ),
                        onTap: entry.isDirectory
                            ? () => controller.openLocal(entry.path)
                            : null,
                        trailing: entry.isDirectory
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: l10n.filesUpload,
                                    icon: const Icon(
                                      PiconsRegular.uploadSimple,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => controller.upload(entry),
                                  ),
                                  IconButton(
                                    tooltip: l10n.filesDelete,
                                    icon: Icon(
                                      PiconsRegular.trash,
                                      size: 18,
                                      color: theme.colorScheme.error,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        _delete(context, controller, entry),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
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
