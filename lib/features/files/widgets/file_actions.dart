import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/error/error_logger.dart';
import '../../../core/ssh/sftp_service.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../data/local_fs_service.dart';
import '../domain/transfer_plan.dart';
import '../file_browser_controller.dart';
import 'conflict_dialog.dart';
import 'entry_name_dialog.dart';

// The thin UI half of rename, new folder and folder transfers: open a dialog,
// hand the answer to the controller, report what went wrong. Everything worth
// testing — validation, paths, the transfer itself — is in the controller.

/// Shows [error] from a file action as a toast.
///
/// [SftpException] and [LocalFsException] are failures the app expects and
/// already carry a message written for the user. Anything else is a bug, so
/// the user gets a plain "that didn't work" and the error itself is recorded
/// for Settings → Diagnostics — recorded even if [context] has gone, because
/// the screen closing does not make the bug any less real.
void reportFileError(BuildContext context, Object error, StackTrace stack) {
  final message = switch (error) {
    SftpException(:final message) => message,
    LocalFsException(:final message) => message,
    _ => null,
  };
  if (message == null) {
    ErrorLogger.instance.record(error, stack, source: 'files');
  }
  if (!context.mounted) return;
  context.toast(
    message ?? AppLocalizations.of(context).filesActionFailed,
    isError: true,
  );
}

/// A [ConflictResolver] that asks with [showConflictDialog].
///
/// Anchored to the root navigator, captured now: a folder walk can take a
/// while, and by the time the question comes the row or pane that started it
/// may have been rebuilt away — on a phone, simply by switching panes.
ConflictResolver conflictResolverFor(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return (folderName, count) async {
    if (!navigator.mounted) return ConflictChoice.cancel;
    return showConflictDialog(
      navigator.context,
      folderName: folderName,
      count: count,
    );
  };
}

Future<void> renameRemoteEntry(
  BuildContext context,
  FileBrowserController controller,
  RemoteEntry entry,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await showEntryNameDialog(
    context,
    title: l10n.filesRename,
    confirmLabel: l10n.filesRename,
    icon: PiconsRegular.pencilSimple,
    initial: entry.name,
    selectStem: !entry.isDirectory,
    validate: (name) =>
        controller.validateRemoteName(name, current: entry.name),
  );
  if (name == null || !context.mounted) return;
  try {
    await controller.renameRemote(entry, name);
  } on Object catch (e, st) {
    if (context.mounted) reportFileError(context, e, st);
  }
}

Future<void> renameLocalEntry(
  BuildContext context,
  FileBrowserController controller,
  LocalEntry entry,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await showEntryNameDialog(
    context,
    title: l10n.filesRename,
    confirmLabel: l10n.filesRename,
    icon: PiconsRegular.pencilSimple,
    initial: entry.name,
    selectStem: !entry.isDirectory,
    validate: (name) => controller.validateLocalName(name, current: entry.name),
  );
  if (name == null || !context.mounted) return;
  try {
    await controller.renameLocal(entry, name);
  } on Object catch (e, st) {
    if (context.mounted) reportFileError(context, e, st);
  }
}

Future<void> createRemoteFolder(
  BuildContext context,
  FileBrowserController controller,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await showEntryNameDialog(
    context,
    title: l10n.filesNewFolder,
    confirmLabel: l10n.filesCreate,
    icon: PiconsRegular.folderPlus,
    validate: controller.validateRemoteName,
  );
  if (name == null || !context.mounted) return;
  try {
    await controller.createRemoteFolder(name);
  } on Object catch (e, st) {
    if (context.mounted) reportFileError(context, e, st);
  }
}

Future<void> createLocalFolder(
  BuildContext context,
  FileBrowserController controller,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await showEntryNameDialog(
    context,
    title: l10n.filesNewFolder,
    confirmLabel: l10n.filesCreate,
    icon: PiconsRegular.folderPlus,
    validate: controller.validateLocalName,
  );
  if (name == null || !context.mounted) return;
  try {
    await controller.createLocalFolder(name);
  } on Object catch (e, st) {
    if (context.mounted) reportFileError(context, e, st);
  }
}

/// F2: renames the single selected entry in whichever pane
/// [FileBrowserController.renameShortcutPane] picks. Does nothing when no
/// pane has exactly one entry selected.
Future<void> renameFromShortcut(
  BuildContext context,
  FileBrowserController controller, {
  required bool bothPanesVisible,
}) async {
  switch (controller.renameShortcutPane(bothPanesVisible: bothPanesVisible)) {
    case BrowserPane.remote:
      final entry = controller.singleSelectedRemote;
      if (entry != null) await renameRemoteEntry(context, controller, entry);
    case BrowserPane.local:
      final entry = controller.singleSelectedLocal;
      if (entry != null) await renameLocalEntry(context, controller, entry);
    case null:
      return;
  }
}
