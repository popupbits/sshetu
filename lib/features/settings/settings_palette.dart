import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../backup/presentation/open_backup.dart';
import '../mcp/mcp_settings.dart';
import '../palette/domain/palette_item.dart';
import '../sessions/open_screens.dart';
import '../transfer/presentation/open_transfer.dart';
import 'settings_scroll_request.dart';

/// The Settings sections, the app's own places, and the actions that live
/// under Settings — theme, moving to another device, backups.
final settingsPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>((ref, l10n) {
      PaletteItem simple({
        required String id,
        required String title,
        required IconData icon,
        required PaletteRun run,
        PaletteCategory category = PaletteCategory.action,
        List<String> keywords = const [],
      }) => PaletteItem(
        id: id,
        title: title,
        category: category,
        icon: icon,
        keywords: keywords,
        actions: [
          PaletteAction(id: 'open', label: title, icon: icon, run: run),
        ],
      );

      return [
        simple(
          id: 'action:toggleTheme',
          title: l10n.paletteToggleTheme,
          icon: PiconsRegular.moon,
          keywords: [l10n.settingsThemeMode],
          run: (context, ref) => toggleThemeMode(context, ref),
        ),
        simple(
          id: 'action:sendToDevice',
          title: l10n.transferSend,
          icon: PiconsRegular.qrCode,
          keywords: [l10n.menuSendToDevice],
          run: openTransferSend,
        ),
        simple(
          id: 'action:receiveFromDevice',
          title: l10n.transferReceive,
          icon: PiconsRegular.downloadSimple,
          keywords: [l10n.menuReceiveFromDevice],
          run: openTransferReceive,
        ),
        simple(
          id: 'action:backupExport',
          title: l10n.backupExport,
          icon: PiconsRegular.archive,
          keywords: [l10n.menuSaveBackup],
          run: openBackupExport,
        ),
        simple(
          id: 'action:backupRestore',
          title: l10n.backupImport,
          icon: PiconsRegular.clockCounterClockwise,
          keywords: [l10n.menuRestoreBackup],
          run: openBackupImport,
        ),
        simple(
          id: 'action:knownHosts',
          title: l10n.knownHostsTitle,
          icon: PiconsRegular.shieldCheck,
          run: openKnownHosts,
        ),
        simple(
          id: 'action:diagnostics',
          title: l10n.settingsDiagnostics,
          icon: PiconsRegular.bug,
          run: openDiagnostics,
        ),
        for (final (id, name, route, icon) in [
          ('hosts', l10n.navHosts, Routes.hosts, PiconsRegular.hardDrives),
          ('keys', l10n.navKeys, Routes.keys, PiconsRegular.key),
          (
            'tunnels',
            l10n.navTunnels,
            Routes.tunnels,
            PiconsRegular.arrowsLeftRight,
          ),
          (
            'snippets',
            l10n.navSnippets,
            Routes.snippets,
            PiconsRegular.codeBlock,
          ),
          ('settings', l10n.navSettings, Routes.settings, PiconsRegular.gear),
        ])
          simple(
            id: 'goto:$id',
            title: l10n.paletteGoTo(name),
            icon: icon,
            keywords: [name],
            run: (context, ref) => context.goTo(route),
          ),
        for (final (id, section) in settingsSectionTitles(
          l10n,
          integrations: ref.watch(mcpSupportedProvider),
        ))
          simple(
            id: 'settings:$id',
            title: l10n.paletteSettingsSection(section),
            category: PaletteCategory.setting,
            icon: PiconsRegular.gear,
            keywords: [section],
            run: (context, ref) => openSettingsAt(context, ref, section),
          ),
      ];
    });

/// The Settings screen's sections, by a stable id and the title
/// `settingsSections` gives them. Kept in step with that list by
/// `settings_palette_test.dart`, which fails if a title here names no section.
List<(String, String)> settingsSectionTitles(
  AppLocalizations l10n, {
  bool integrations = false,
}) => [
  ('appearance', l10n.settingsAppearance),
  ('terminalAppearance', l10n.settingsTerminalAppearance),
  ('general', l10n.settingsGeneral),
  ('terminal', l10n.settingsTerminal),
  ('hosts', l10n.hostsTitle),
  ('security', l10n.settingsSecurity),
  ('transfer', l10n.transferTitle),
  ('backup', l10n.backupTitle),
  // Desktop only, like the section itself.
  if (integrations) ('integrations', l10n.settingsIntegrations),
  ('about', l10n.settingsAbout),
];

/// Opens Settings with [section] in view.
void openSettingsAt(BuildContext context, WidgetRef ref, String section) {
  context.goTo(Routes.settings);
  ref.read(settingsScrollRequestProvider.notifier).request(section);
}

/// Light if the app is drawn dark right now, dark otherwise.
///
/// Judged by what is on screen rather than the stored choice, so from "follow
/// the system" it always flips to the opposite of what the user is looking at.
void toggleThemeMode(BuildContext context, WidgetRef ref) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  ref
      .read(settingsControllerProvider.notifier)
      .setThemeMode(dark ? AppThemeMode.light : AppThemeMode.dark);
}
