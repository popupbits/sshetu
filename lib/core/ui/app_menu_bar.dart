import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/sessions/open_screens.dart';

import '../../features/sessions/session_manager.dart';
import '../../features/sessions/session_shortcuts.dart';
import '../../features/sessions/workspace_pages.dart';
import '../../features/transfer/presentation/open_transfer.dart';
import '../../l10n/app_localizations.dart';
import '../router/navigation.dart';
import '../router/routes.dart';
import '../util/responsive.dart';

/// The desktop menu bar.
///
/// A desktop app with no menus is a phone app in a window. On macOS the bar
/// belongs to the system and is the first place anyone looks for "what can
/// this do"; on Windows and Linux it is the conventional home for the same
/// answers. Either way it is also where a person *learns the shortcuts* — the
/// app already has Cmd-W, Cmd-1..9 and the bracket pair, and until now nothing
/// told anyone they existed.
///
/// Every item here routes through the same intents the keyboard uses, so a
/// menu item and its shortcut can never drift into meaning different things.
///
/// Wraps its child rather than replacing it: [PlatformMenuBar] renders no
/// visible chrome on macOS (the system draws it) and this app keeps its own
/// in-window navigation regardless, so the menus are additive on every
/// platform.
class AppMenuBar extends ConsumerWidget {
  const AppMenuBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phones have no menu bar, and building one costs a platform channel call
    // that does nothing there.
    if (context.usesSoftwareKeyboard) return child;

    final l10n = AppLocalizations.of(context);

    return PlatformMenuBar(
      menus: [
        // The application menu. macOS puts About / Services / Hide / Quit
        // here and gives them their standard shortcuts — but only if we ask
        // for them: supplying any menus at all *replaces* the default bar, so
        // leaving this out is what took Cmd-Q away.
        if (_isMac)
          PlatformMenu(
            label: l10n.appTitle,
            menus: [
              PlatformMenuItem(
                label: l10n.menuAboutApp,
                // Ours, not the system panel: the app has a real About screen
                // with versions and licences, and two different "about"s is
                // one more than anyone wants.
                onSelected: () => openAbout(context, ref),
              ),
              const PlatformMenuItemGroup(
                members: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.servicesSubmenu,
                  ),
                ],
              ),
              const PlatformMenuItemGroup(
                members: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.hide,
                  ),
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.hideOtherApplications,
                  ),
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.showAllApplications,
                  ),
                ],
              ),
              const PlatformMenuItemGroup(
                members: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.quit,
                  ),
                ],
              ),
            ],
          ),
        PlatformMenu(
          label: l10n.menuFile,
          menus: [
            PlatformMenuItem(
              label: l10n.menuNewHost,
              shortcut: _primary(LogicalKeyboardKey.keyN),
              onSelected: () => openHostEditor(context, ref),
            ),
            PlatformMenuItem(
              label: l10n.menuImport,
              onSelected: () => openImport(context, ref),
            ),
            PlatformMenuItemGroup(
              members: [
                // Close Tab, not Close Session: the workspace has terminals
                // and pages side by side, and Cmd-W means "close the one in
                // front" for both.
                PlatformMenuItem(
                  label: l10n.menuCloseTab,
                  shortcut: _primary(LogicalKeyboardKey.keyW),
                  onSelected: _hasTab(ref) ? () => closeCurrentTab(ref) : null,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: l10n.menuSendToDevice,
                  onSelected: () => openTransferSend(context, ref),
                ),
                PlatformMenuItem(
                  label: l10n.menuReceiveFromDevice,
                  onSelected: () => openTransferReceive(context, ref),
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuSession,
          menus: [
            // Disabled with no sessions rather than hidden: a menu whose items
            // come and go is a menu people stop reading.
            PlatformMenuItem(
              label: l10n.menuCloseSession,
              onSelected: _hasSessions(ref) ? () => _closeActive(ref) : null,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: l10n.menuNextSession,
                  shortcut: _primary(LogicalKeyboardKey.bracketRight),
                  onSelected: _hasSessions(ref) ? () => _cycle(ref, 1) : null,
                ),
                PlatformMenuItem(
                  label: l10n.menuPreviousSession,
                  shortcut: _primary(LogicalKeyboardKey.bracketLeft),
                  onSelected: _hasSessions(ref) ? () => _cycle(ref, -1) : null,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: l10n.menuView,
          menus: [
            PlatformMenuItem(
              label: l10n.menuHosts,
              shortcut: _primary(LogicalKeyboardKey.digit1),
              onSelected: () => context.goTo(Routes.hosts),
            ),
            PlatformMenuItem(
              label: l10n.menuKeys,
              onSelected: () => context.goTo(Routes.keys),
            ),
            PlatformMenuItem(
              label: l10n.menuTunnels,
              onSelected: () => context.goTo(Routes.tunnels),
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: l10n.menuSettings,
                  shortcut: _primary(LogicalKeyboardKey.comma),
                  onSelected: () => context.goTo(Routes.settings),
                ),
              ],
            ),
          ],
        ),
        // Minimise, Zoom and Full Screen come with their standard shortcuts
        // attached. They are only absent because we replaced the default bar.
        if (_isMac)
          PlatformMenu(
            label: l10n.menuWindow,
            menus: const [
              PlatformMenuItemGroup(
                members: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.minimizeWindow,
                  ),
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.zoomWindow,
                  ),
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.toggleFullScreen,
                  ),
                ],
              ),
              PlatformMenuItemGroup(
                members: [
                  PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                  ),
                ],
              ),
            ],
          ),
        PlatformMenu(
          label: l10n.menuHelp,
          menus: [
            PlatformMenuItem(
              label: l10n.menuTrustedHostKeys,
              onSelected: () => openKnownHosts(context, ref),
            ),
            PlatformMenuItem(
              label: l10n.menuDiagnostics,
              onSelected: () => openDiagnostics(context, ref),
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: l10n.settingsAbout,
                  onSelected: () => openAbout(context, ref),
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }

  static bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  /// Whether there is anything Cmd-W could close.
  static bool _hasTab(WidgetRef ref) =>
      ref.watch(sessionManagerProvider).isNotEmpty ||
      ref.watch(workspacePagesProvider).isNotEmpty;

  /// Cmd on macOS, Ctrl elsewhere — the same rule the keyboard shortcuts use.
  static MenuSerializableShortcut _primary(LogicalKeyboardKey key) {
    final usesMeta = defaultTargetPlatform == TargetPlatform.macOS;
    return SingleActivator(key, meta: usesMeta, control: !usesMeta);
  }

  static bool _hasSessions(WidgetRef ref) =>
      ref.watch(sessionManagerProvider).isNotEmpty;

  static void _closeActive(WidgetRef ref) {
    final manager = ref.read(sessionManagerProvider.notifier);
    final active = manager.activeId;
    if (active != null) manager.close(active);
  }

  static void _cycle(WidgetRef ref, int delta) =>
      ref.read(sessionManagerProvider.notifier).cycle(delta);
}
