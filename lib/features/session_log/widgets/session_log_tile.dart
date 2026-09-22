import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/log_format.dart';
import '../session_log_settings.dart';
import 'start_log_dialog.dart';

/// Session logging in Settings: where logs go, whether every new tab is
/// logged, and in which format.
///
/// A desktop chooses a folder, and "always log" stays off until it has one —
/// logging without asking needs somewhere to write that the user picked. A
/// phone writes into the app's own folder and shares from there, so it has
/// no folder row at all.
class SessionLogTile extends ConsumerWidget {
  const SessionLogTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(sessionLogSettingsProvider);
    final controller = ref.read(sessionLogSettingsProvider.notifier);
    final appFolder = ref.watch(sessionLogUsesAppFolderProvider);
    final folder = settings.folder;
    final canAlwaysLog = appFolder || folder != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!appFolder)
          ListTile(
            key: const Key('sessionLog.folder'),
            leading: const Icon(PiconsRegular.folderOpen),
            title: Text(l10n.sessionLogFolder),
            subtitle: Text(
              folder ?? l10n.sessionLogFolderNone,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: folder == null
                ? null
                : IconButton(
                    tooltip: l10n.sessionLogFolderClear,
                    icon: const Icon(PiconsRegular.x),
                    onPressed: () {
                      unawaited(controller.setFolder(null));
                      unawaited(controller.setAlwaysLog(false));
                    },
                  ),
            onTap: () async {
              final picked = await getDirectoryPath(initialDirectory: folder);
              if (picked != null) await controller.setFolder(picked);
            },
          ),
        SwitchListTile(
          key: const Key('sessionLog.always'),
          secondary: const Icon(PiconsRegular.record),
          title: Text(l10n.sessionLogAlways),
          subtitle: Text(
            canAlwaysLog
                ? l10n.sessionLogAlwaysBody
                : l10n.sessionLogAlwaysNeedsFolder,
          ),
          isThreeLine: true,
          value: settings.alwaysLog && canAlwaysLog,
          onChanged: canAlwaysLog ? controller.setAlwaysLog : null,
        ),
        ListTile(
          leading: const Icon(PiconsRegular.fileText),
          title: Text(l10n.sessionLogFormat),
          // Under the title rather than trailing it: "Raw (with colours)"
          // beside a title does not fit a phone, and a trailing widget that
          // runs out of room takes the whole tile down with it.
          subtitle: DropdownButton<SessionLogFormat>(
            key: const Key('sessionLog.formatPicker'),
            value: settings.format,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            onChanged: (format) {
              if (format != null) unawaited(controller.setFormat(format));
            },
            items: [
              for (final format in SessionLogFormat.values)
                DropdownMenuItem(
                  value: format,
                  child: Text(
                    sessionLogFormatLabel(l10n, format),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
