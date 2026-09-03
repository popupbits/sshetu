import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/util/responsive.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../l10n/app_localizations.dart';
import '../keys/widgets/generate_key_sheet.dart';
import '../sessions/session_shortcuts.dart';
import '../sessions/widgets/terminal_workspace.dart';

/// One navigation destination.
class ShellDestination {
  const ShellDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The app's navigation chrome.
///
/// Owns the [Scaffold], the [AppBar] and the navigation surfaces; destinations
/// supply body content only. That split is what lets the drawer be reachable
/// from every destination — a nested Scaffold would capture the hamburger and
/// find no drawer on it.
///
/// Adapts by width: a bottom bar on a phone, a rail once there is room.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Destinations, in branch order. Settings is always last — the router
  /// builds its branches in exactly this order.
  static List<ShellDestination> destinationsOf(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      ShellDestination(label: l10n.navHosts, icon: PiconsRegular.hardDrives),
      ShellDestination(
        label: l10n.navSessions,
        icon: PiconsRegular.terminalWindow,
      ),
      ShellDestination(label: l10n.navKeys, icon: PiconsRegular.key),
      ShellDestination(
        label: l10n.navTunnels,
        icon: PiconsRegular.arrowsLeftRight,
      ),
      ShellDestination(label: l10n.navSettings, icon: PiconsRegular.gear),
    ];
  }

  /// The AppBar actions for the destination at [index].
  List<Widget> _actionsFor(
    BuildContext context,
    int index, {
    bool dense = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final size = dense ? 16.0 : 24.0;
    final constraints = dense
        ? const BoxConstraints.tightFor(width: 28, height: 28)
        : null;
    return switch (index) {
      // Hosts
      0 => [
        IconButton(
          tooltip: l10n.hostsImport,
          icon: Icon(PiconsRegular.downloadSimple, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => context.pushTo(Routes.importOpenSsh),
        ),
        IconButton(
          tooltip: l10n.hostsAdd,
          icon: Icon(PiconsRegular.plus, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => context.pushTo(Routes.hostNew),
        ),
      ],
      // Keys
      2 => [
        IconButton(
          tooltip: l10n.keysGenerate,
          icon: Icon(PiconsRegular.key, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => showGenerateKeySheet(context),
        ),
        IconButton(
          tooltip: l10n.keysImport,
          icon: Icon(PiconsRegular.downloadSimple, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => context.pushTo(Routes.importFocused('keys')),
        ),
      ],
      // Tunnels
      3 => [
        IconButton(
          tooltip: l10n.tunnelsAdd,
          icon: Icon(PiconsRegular.plus, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => context.pushTo(Routes.tunnelNew),
        ),
      ],
      _ => const [],
    };
  }

  void _go(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active destination returns to that branch's root, which
      // is what every platform's tab bar does.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Branch indices shown in the desktop rail.
  ///
  /// Sessions is missing on purpose. On desktop the terminal is not a place
  /// you navigate to — it is always on the right — so a rail entry leading to
  /// it would be a button that goes where you already are. The phone keeps it,
  /// because there the terminal really is a separate screen.
  static const List<int> _desktopBranches = [0, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsOf(context);
    final index = navigationShell.currentIndex;

    // Wrapped around the whole shell rather than around the terminal: Cmd-W
    // has to close a tab while the focus is in the host list too, which is
    // exactly where it will be when someone has just started a session.
    return SessionShortcuts(
      child: context.useRail
          ? _buildDesktop(context, destinations, index)
          : _buildCompact(context, destinations, index),
    );
  }

  /// Rail, one contextual panel, terminal.
  ///
  /// The layout this replaced had *two* vertical columns before any content —
  /// the rail, then a host sidebar — and the host list appeared in both the
  /// sidebar and the Hosts destination. That is 600px of chrome and one list
  /// drawn twice.
  ///
  /// So there is one navigation column and one panel, and the panel shows
  /// whatever the rail selected: hosts, keys, tunnels, settings. The terminal
  /// keeps the rest of the window at all times, which is what makes this a
  /// workspace rather than a set of pages — looking up a key no longer takes
  /// the shell you are working in off the screen.
  Widget _buildDesktop(
    BuildContext context,
    List<ShellDestination> destinations,
    int index,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // Settings is a page, not a list; it does not read in a 300px column.
    final panelIndex = _desktopBranches.contains(index) ? index : 0;

    return Scaffold(
      // No AppBar. Its title said the name of the destination, which the panel
      // header now says in a third of the height — and a terminal's scarcest
      // resource is vertical space.
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _desktopBranches.indexOf(panelIndex),
              onDestinationSelected: (i) => _go(_desktopBranches[i]),
              labelType: NavigationRailLabelType.all,
              backgroundColor: scheme.surfaceContainerLow,
              destinations: [
                for (final branch in _desktopBranches)
                  NavigationRailDestination(
                    icon: Icon(destinations[branch].icon),
                    label: Text(destinations[branch].label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            SizedBox(
              // 320 rather than 300: an IPv4 address plus a monogram is
              // almost exactly 300, and the difference decides whether a
              // host list of addresses is readable or a column of ellipses.
              width: 320,
              child: Column(
                children: [
                  PanelHeader(
                    title: destinations[panelIndex].label,
                    actions: _actionsFor(context, panelIndex, dense: true),
                  ),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            const Expanded(child: TerminalWorkspace()),
          ],
        ),
      ),
    );
  }

  /// Bottom bar, one screen at a time.
  Widget _buildCompact(
    BuildContext context,
    List<ShellDestination> destinations,
    int index,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[index].label),
        actions: _actionsFor(context, index),
      ),
      // No drawer. It listed exactly the destinations the bottom bar already
      // shows, so it was a second way to reach the same five screens — and it
      // cost a hamburger button in the corner of every screen, which on a
      // phone is the most valuable 48 points on the bar.
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _go,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
