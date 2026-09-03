import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/responsive.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../l10n/app_localizations.dart';

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
      ShellDestination(label: l10n.navTunnels, icon: PiconsRegular.arrowsLeftRight),
      ShellDestination(label: l10n.navSettings, icon: PiconsRegular.gear),
    ];
  }

  /// The AppBar actions for the destination at [index].
  List<Widget> _actionsFor(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context);
    return switch (index) {
      // Hosts
      0 => [
        IconButton(
          tooltip: l10n.hostsImport,
          icon: const Icon(PiconsRegular.downloadSimple),
          onPressed: () => context.pushTo(Routes.importOpenSsh),
        ),
        IconButton(
          tooltip: l10n.hostsAdd,
          icon: const Icon(PiconsRegular.plus),
          onPressed: () => context.pushTo(Routes.hostNew),
        ),
      ],
      // Keys
      2 => [
        IconButton(
          tooltip: l10n.keysImport,
          icon: const Icon(PiconsRegular.downloadSimple),
          onPressed: () => context.pushTo(Routes.importFocused('keys')),
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

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsOf(context);
    final index = navigationShell.currentIndex;
    final useRail = context.useRail;

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[index].label),
        // Per-destination actions rather than a floating button: the same
        // widget then works on a phone and on a desktop window, where a FAB
        // floating over a list reads as out of place.
        actions: _actionsFor(context, index),
      ),
      // Modal on a phone; the wide layout below shows it inline instead.
      drawer: useRail
          ? null
          : _AppDrawer(
              destinations: destinations,
              selectedIndex: index,
              onSelected: (i) {
                Navigator.of(context).pop();
                _go(i);
              },
            ),
      body: Row(
        children: [
          if (useRail) ...[
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: _go,
              labelType: context.isExpanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              extended: context.isExpanded,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
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

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xl,
            Spacing.lg,
            Spacing.lg,
          ),
          child: Text(
            AppLocalizations.of(context).appTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        for (final destination in destinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
