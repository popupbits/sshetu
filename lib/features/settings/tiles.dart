import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/error/error_logger.dart';
import '../../core/error/error_record.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/ui/feedback.dart';
import '../../core/util/launcher.dart';
import '../../core/util/review_prompt.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'widgets/accent_tile.dart';
import 'widgets/language_tile.dart';
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
      tiles: const [AccentTile(), ThemeModeTile(), TextScaleTile()],
    ),
    SettingsSection(title: l10n.settingsGeneral, tiles: const [LanguageTile()]),
    SettingsSection(
      title: l10n.hostsTitle,
      tiles: [
        ListTile(
          leading: const Icon(PiconsRegular.downloadSimple),
          title: Text(l10n.hostsImport),
          subtitle: Text(l10n.importNoteBody),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushTo(Routes.importOpenSsh),
        ),
      ],
    ),
    // Signing in is offered, never required: everything in this app works on
    // this device without an account, and an SSH client that demands one
    // before it will open a shell is an SSH client people abandon. The only
    // thing it buys is syncing this configuration to another device.
    SettingsSection(
      title: l10n.settingsSync,
      tiles: [
        if (ref.watch(currentUserProvider) case final user?) ...[
          ListTile(
            leading: const Icon(PiconsRegular.user),
            title: Text(user.email),
          ),
          ListTile(
            leading: const Icon(PiconsRegular.signOut),
            title: Text(l10n.authSignOut),
            onTap: () async {
              final confirmed = await context.confirm(
                title: l10n.authSignOutConfirm,
                confirmLabel: l10n.authSignOut,
                isDestructive: true,
              );
              if (confirmed) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
          ),
        ] else
          ListTile(
            leading: const Icon(PiconsRegular.cloudArrowUp),
            title: Text(l10n.settingsSyncSignIn),
            subtitle: Text(l10n.settingsSyncBody),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushTo(Routes.signIn),
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
            onTap: () => context.pushTo(Routes.diagnostics),
          ),
        ),
        ListTile(
          leading: const Icon(PiconsRegular.info),
          title: Text(l10n.aboutTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushTo(Routes.about),
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
