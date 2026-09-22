import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:picons/picons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app.dart' show rootMessengerKey;
import '../../core/error/error_logger.dart';
import '../../core/router/router.dart' show rootNavigatorKey;
import '../../core/secrets/app_lock.dart' show appLocalizationsFor;
import '../../core/settings/settings_controller.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/ui/context_menu.dart';
import '../../l10n/app_localizations.dart';
import '../sessions/session_manager.dart';
import 'domain/log_format.dart';
import 'session_log_controller.dart';
import 'session_log_settings.dart';
import 'widgets/start_log_dialog.dart';

/// Asks for a format and, on a desktop, a file, then starts logging
/// [session]. The one way in for every menu, so they all ask the same
/// questions.
Future<void> startSessionLog(
  BuildContext context,
  WidgetRef ref,
  TerminalSession session,
) async {
  final controller = ref.read(sessionLogControllerProvider.notifier);
  if (controller.isLogging(session.id)) return;
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(sessionLogSettingsProvider);

  final format = await showStartLogDialog(
    context,
    sessionTitle: session.title,
    initial: settings.format,
  );
  if (format == null || !context.mounted) return;

  final name = sessionLogFileName(session.title, DateTime.now(), format);
  final String path;
  if (ref.read(sessionLogUsesAppFolderProvider)) {
    path = p.join(await ref.read(sessionLogAppFolderProvider)(), name);
  } else {
    final location = await getSaveLocation(
      suggestedName: name,
      initialDirectory: settings.folder,
      // No type group: macOS rejects a save panel whose group names an
      // extension it has no type for, and .cast is one.
    );
    if (location == null) return;
    path = location.path;
  }

  // Remembered as the next default: whoever logs as asciicast once is
  // likely to again.
  unawaited(ref.read(sessionLogSettingsProvider.notifier).setFormat(format));

  try {
    await controller.start(session, format, path);
  } on Object catch (e, st) {
    ErrorLogger.instance.record(e, st);
    _show(l10n.sessionLogFailed);
    return;
  }
  _show(l10n.sessionLogStarted(p.basename(path)));
}

/// Stops logging [sessionId] and says where the file is — with a Share
/// action where the file lives inside the app, since that is the only way
/// out of there.
Future<void> stopSessionLog(WidgetRef ref, String sessionId) async {
  final l10n = appLocalizationsFor(
    ref.read(settingsControllerProvider.select((s) => s.localeCode)),
  );
  final log = await ref
      .read(sessionLogControllerProvider.notifier)
      .stop(sessionId);
  if (log == null) return;
  if (ref.read(sessionLogUsesAppFolderProvider)) {
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.sessionLogSaved(log.fileName)),
          action: SnackBarAction(
            label: l10n.sessionLogShare,
            onPressed: () => unawaited(shareSessionLog(log.path)),
          ),
        ),
      );
  } else {
    _show(l10n.sessionLogSaved(log.path));
  }
}

Future<void> shareSessionLog(String path) async {
  try {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], fileNameOverrides: [p.basename(path)]),
    );
  } on Object catch (e, st) {
    ErrorLogger.instance.record(e, st);
  }
}

/// Starts or stops, whichever [session] needs.
Future<void> toggleSessionLog(
  BuildContext context,
  WidgetRef ref,
  TerminalSession session,
) => ref.read(sessionLogControllerProvider.notifier).isLogging(session.id)
    ? stopSessionLog(ref, session.id)
    : startSessionLog(context, ref, session);

/// "Start logging…" or "Stop logging", for a tab's context menu.
List<MenuAction> sessionLogMenuActions(
  BuildContext context,
  WidgetRef ref,
  TerminalSession session,
) {
  final l10n = AppLocalizations.of(context);
  final logging = ref
      .read(sessionLogControllerProvider.notifier)
      .isLogging(session.id);
  return [
    MenuAction(
      label: logging ? l10n.sessionLogStop : l10n.sessionLogStartEllipsis,
      icon: logging ? PiconsRegular.stopCircle : PiconsRegular.record,
      onSelected: () => unawaited(
        // The menu is gone by now; its context may be too.
        toggleSessionLog(
          rootNavigatorKey.currentContext ?? context,
          ref,
          session,
        ),
      ),
    ),
  ];
}

/// The logging item of the menu bar's Session menu, for the active tab.
PlatformMenuItemGroup sessionLogMenuGroup(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  ref.watch(sessionManagerProvider);
  final logs = ref.watch(sessionLogControllerProvider);
  final active = ref.read(sessionManagerProvider.notifier).active;
  final logging = active != null && logs.containsKey(active.id);
  return PlatformMenuItemGroup(
    members: [
      PlatformMenuItem(
        label: logging ? l10n.sessionLogStop : l10n.sessionLogStartEllipsis,
        onSelected: active == null
            ? null
            : () => unawaited(
                toggleSessionLog(
                  rootNavigatorKey.currentContext ?? context,
                  ref,
                  active,
                ),
              ),
      ),
    ],
  );
}

void _show(String message) {
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
