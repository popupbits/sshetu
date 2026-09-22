import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../sessions/open_screens.dart';

import '../../core/error/error_logger.dart';
import '../../core/error/error_record.dart';
import '../../core/ssh/openssh_import.dart';
import '../../core/util/launcher.dart';
import '../../core/util/review_prompt.dart';
import '../../l10n/app_localizations.dart';
import '../backup/presentation/open_backup.dart';
import 'widgets/default_key_tile.dart';
import '../transfer/presentation/open_transfer.dart';
import 'widgets/accent_tile.dart';
import 'widgets/app_lock_tile.dart';
import 'widgets/confirm_paste_tile.dart';
import 'widgets/keep_alive_tile.dart';
import '../../core/background/keep_alive_service.dart';
import 'widgets/keep_sessions_tile.dart';
import 'widgets/language_tile.dart';
import 'widgets/terminal_font_size_tile.dart';
import 'widgets/text_scale_tile.dart';
import 'widgets/theme_mode_tile.dart';

/// A titled group of rows on the Settings screen.
class SettingsSection {
  const SettingsSection({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;
}

/// The Settings screen's content, assembled here rather than inline in the
/// screen.
///
/// This is the seam a feature extends: a brick that adds a settings row adds a
/// section here instead of editing the screen's build method, so two features
/// can be added without touching the same lines.
List<SettingsSection> settingsSections(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);

  return [
    SettingsSection(
      title: l10n.settingsAppearance,
      tiles: const [
        AccentTile(),
        ThemeModeTile(),
        TextScaleTile(),
        TerminalFontSizeTile(),
      ],
    ),
    SettingsSection(title: l10n.settingsGeneral, tiles: const [LanguageTile()]),
    SettingsSection(
      title: l10n.settingsTerminal,
      tiles: [
        const ConfirmPasteTile(),
        const KeepSessionsTile(),
        if (ref.watch(keepAliveSupportedProvider)) const KeepAliveTile(),
      ],
    ),
    SettingsSection(
      title: l10n.hostsTitle,
      tiles: [
        ListTile(
          leading: const Icon(PiconsRegular.downloadSimple),
          title: Text(l10n.hostsImport),
          // "Your ~/.ssh files are read" is a promise a phone cannot keep —
          // it has no such directory, and the screen behind this row offers a
          // file picker instead.
          subtitle: Text(
            OpenSshScanner.canAutoDetect
                ? l10n.importNoteBody
                : l10n.importNoteBodyMobile,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openImport(context, ref),
        ),
      ],
    ),
    SettingsSection(
      title: l10n.settingsSecurity,
      tiles: [
        const DefaultKeyTile(),
        const AppLockTile(),
        ListTile(
          leading: const Icon(PiconsRegular.shieldCheck),
          title: Text(l10n.knownHostsTitle),
          subtitle: Text(l10n.knownHostsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openKnownHosts(context, ref),
        ),
      ],
    ),
    // Not an account: a direct, one-shot transfer between two devices the
    // user has in front of them, over their own network.
    SettingsSection(
      title: l10n.transferTitle,
      tiles: [
        ListTile(
          leading: const Icon(PiconsRegular.qrCode),
          title: Text(l10n.transferSend),
          subtitle: Text(l10n.transferBody),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openTransferSend(context, ref),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.downloadSimple),
          title: Text(l10n.transferReceive),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openTransferReceive(context, ref),
        ),
      ],
    ),
    // The app has no account, which is right for an SSH client and removes
    // the accidental backup an account gives you. This is that backup, made
    // explicit: a file you hold, encrypted before it leaves.
    SettingsSection(
      title: l10n.backupTitle,
      tiles: [
        ListTile(
          leading: const Icon(PiconsRegular.archive),
          title: Text(l10n.backupExport),
          subtitle: Text(l10n.backupBody),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openBackupExport(context, ref),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.clockCounterClockwise),
          title: Text(l10n.backupImport),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openBackupImport(context, ref),
        ),
      ],
    ),
    SettingsSection(
      title: l10n.settingsAbout,
      tiles: [
        // Rebuilds itself as errors arrive, so the row shows a count
        // without Settings having to watch anything.
        ValueListenableBuilder<List<ErrorRecord>>(
          valueListenable: ErrorLogger.instance.records,
          builder: (context, records, _) => ListTile(
            leading: Icon(
              PiconsRegular.bug,
              color: records.isEmpty
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.settingsDiagnostics),
            subtitle: Text(
              records.isEmpty
                  ? l10n.settingsDiagnosticsNone
                  : l10n.settingsDiagnosticsBody(records.length),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openDiagnostics(context, ref),
          ),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.info),
          title: Text(l10n.aboutTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openAbout(context, ref),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.shareNetwork),
          title: Text(l10n.aboutShare),
          subtitle: Text(l10n.aboutShareSubtitle),
          onTap: () => Launcher.shareApp(l10n.aboutShareMessage),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.star),
          title: Text(l10n.aboutRate),
          subtitle: Text(l10n.aboutRateSubtitle),
          // Deliberate tap, so fall back to the store listing when the
          // platform declines to show its sheet.
          onTap: () => ReviewPrompt.request(),
        ),
      ],
    ),
  ];
}
