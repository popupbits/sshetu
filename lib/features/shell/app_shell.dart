import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../import/import_screen.dart';
import '../sessions/open_screens.dart';

import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../keys/widgets/generate_key_sheet.dart';
import '../keys/widgets/paste_key_sheet.dart';
import '../palette/open_command_palette.dart';
import '../sessions/session_shortcuts.dart';
import '../sessions/widgets/workspace_restore_listener.dart';
import '../sessions/widgets/terminal_workspace.dart';
import '../server_info/server_info_dock.dart';
import '../snippets/open_snippets.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/settings/settings_controller.dart';
import 'workspace_layout.dart';

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
class AppShell extends ConsumerWidget {
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
      ShellDestination(label: l10n.navSnippets, icon: PiconsRegular.codeBlock),
      ShellDestination(label: l10n.navSettings, icon: PiconsRegular.gear),
    ];
  }

  /// The AppBar actions for the destination at [index].
  List<Widget> _actionsFor(
    BuildContext context,
    WidgetRef ref,
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
          onPressed: () => openImport(context, ref),
        ),
        IconButton(
          tooltip: l10n.hostsAdd,
          icon: Icon(PiconsRegular.plus, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => openHostEditor(context, ref),
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
          tooltip: l10n.keysPaste,
          icon: Icon(PiconsRegular.clipboardText, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => showPasteKeySheet(context),
        ),
        IconButton(
          tooltip: l10n.keysImport,
          icon: Icon(PiconsRegular.downloadSimple, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => openImport(context, ref, focus: ImportFocus.keys),
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
          onPressed: () => openTunnelEditor(context, ref),
        ),
      ],
      // Sessions, on a phone: the bottom bar has no room for Snippets (see
      // [_compactBranches]), and this is the destination they belong to.
      1 => [
        IconButton(
          key: const Key('shell.openSnippets'),
          tooltip: l10n.navSnippets,
          icon: Icon(PiconsRegular.codeBlock, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => context.goTo(Routes.snippets),
        ),
      ],
      // Snippets
      4 => [
        IconButton(
          tooltip: l10n.snippetsAdd,
          icon: Icon(PiconsRegular.plus, size: size),
          visualDensity: dense ? VisualDensity.compact : null,
          padding: dense ? EdgeInsets.zero : null,
          constraints: constraints,
          onPressed: () => openSnippetEditor(context, ref),
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

  /// Branch indices shown in the desktop rail when the terminal is beside the
  /// panel.
  ///
  /// Sessions is missing on purpose. When the terminal is always on the right
  /// it is not a place you navigate to, so a rail entry leading to it would be
  /// a button that goes where you already are.
  static const List<int> _wideBranches = [0, 2, 3, 4, 5];

  /// And when the window is too narrow to hold both, Sessions comes back —
  /// the terminal is a separate pane again, so it needs a way to be reached.
  static const List<int> _narrowBranches = [0, 1, 2, 3, 4, 5];

  /// The phone's bottom bar: every destination except Snippets.
  ///
  /// Six is one more than a bottom bar holds — Material caps it at five, and
  /// at phone width six labels either truncate or vanish. Of the six,
  /// Snippets is the one that is never a place you *start*: a snippet is
  /// used from inside a terminal, where the terminal screen has its own
  /// button for the picker, and is managed from Sessions, whose app bar
  /// carries the way in. Keys and Tunnels are both configuration you go and
  /// look at, so they keep their tabs.
  static const List<int> _compactBranches = [0, 1, 2, 3, 5];

  /// The branch a compact bar highlights for [index]: Snippets lights up
  /// Sessions, which is where it is reached from.
  static int _compactSelected(int index) =>
      _compactBranches.contains(index) ? index : 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = destinationsOf(context);
    final index = navigationShell.currentIndex;

    // Wrapped around the whole shell rather than around the terminal: Cmd-W
    // has to close a tab while the focus is in the host list too, which is
    // exactly where it will be when someone has just started a session.
    //
    // The restore listener sits here, under the router, because reopening
    // last launch's tabs raises the same host-key and password dialogs a
    // connection does — and a dialog needs a navigator above it.
    return WorkspaceRestoreListener(
      child: SessionShortcuts(
        child: context.useRail
            ? _buildDesktop(context, ref, destinations, index)
            : _buildCompact(context, ref, destinations, index),
      ),
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
    WidgetRef ref,
    List<ShellDestination> destinations,
    int index,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final preferred = ref.watch(
      settingsControllerProvider.select((settings) => settings.panelWidth),
    );

    return Scaffold(
      // No AppBar. Its title said the name of the destination, which the panel
      // header now says in a third of the height — and a terminal's scarcest
      // resource is vertical space.
      body: SafeArea(
        // Measured *after* the rail rather than guessing its width: the rail
        // sizes itself from its labels and the text scale, so a constant here
        // would be wrong for anyone who has touched either.
        child: LayoutBuilder(
          builder: (context, outer) {
            final roomy = WorkspaceLayout.showsTerminalAt(outer.maxWidth);
            final branches = roomy ? _wideBranches : _narrowBranches;
            final selected = branches.contains(index) ? index : branches.first;

            return Row(
              children: [
                NavigationRail(
                  selectedIndex: branches.indexOf(selected),
                  onDestinationSelected: (i) => _go(branches[i]),
                  // Labels always. Dropping them to `selected` when the
                  // window is tight saves about eight points and costs every
                  // destination its name — a bad trade, and the responsive
                  // behaviour that matters happens to the right of here.
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: scheme.surfaceContainerLow,
                  destinations: [
                    for (final branch in branches)
                      NavigationRailDestination(
                        icon: Icon(destinations[branch].icon),
                        label: Text(destinations[branch].label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: scheme.outlineVariant),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, inner) {
                      final layout = WorkspaceLayout.resolve(
                        available: inner.maxWidth,
                        preferred: preferred,
                        showTerminal: roomy,
                      );
                      return _workspace(
                        context,
                        ref,
                        destinations,
                        selected,
                        layout,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The panel and, when it fits, the terminal beside it.
  Widget _workspace(
    BuildContext context,
    WidgetRef ref,
    List<ShellDestination> destinations,
    int index,
    WorkspaceLayout layout,
  ) {
    // Sessions selected in a narrow window means the terminal *is* the pane.
    if (!layout.showTerminal && index == 1) {
      return const ServerInfoDock(child: TerminalWorkspace());
    }

    final panel = Column(
      children: [
        PanelHeader(
          title: destinations[index].label,
          actions: _actionsFor(context, ref, index, dense: true),
        ),
        Expanded(child: navigationShell),
      ],
    );

    if (!layout.showTerminal) return panel;

    return Row(
      children: [
        SizedBox(width: layout.panelWidth, child: panel),
        _ResizeHandle(
          key: const Key('workspace.resizeHandle'),
          width: layout.panelWidth,
          onChanged: (width, {required done}) => ref
              .read(settingsControllerProvider.notifier)
              .setPanelWidth(width, persist: done),
        ),
        const Expanded(child: ServerInfoDock(child: TerminalWorkspace())),
      ],
    );
  }

  /// Bottom bar, one screen at a time.
  Widget _buildCompact(
    BuildContext context,
    WidgetRef ref,
    List<ShellDestination> destinations,
    int index,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[index].label),
        actions: [
          // The phone's way into the palette: no keyboard chord to press.
          IconButton(
            key: const Key('shell.openPalette'),
            tooltip: AppLocalizations.of(context).paletteOpenTooltip,
            icon: const Icon(PiconsRegular.magnifyingGlass),
            onPressed: () => openCommandPalette(context, ref),
          ),
          ..._actionsFor(context, ref, index),
        ],
      ),
      // No drawer. It listed exactly the destinations the bottom bar already
      // shows, so it was a second way to reach the same five screens — and it
      // cost a hamburger button in the corner of every screen, which on a
      // phone is the most valuable 48 points on the bar.
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _compactBranches.indexOf(_compactSelected(index)),
        onDestinationSelected: (i) => _go(_compactBranches[i]),
        destinations: [
          for (final branch in _compactBranches)
            NavigationDestination(
              icon: Icon(destinations[branch].icon),
              label: destinations[branch].label,
            ),
        ],
      ),
    );
  }
}

/// The divider between the panel and the terminal, made draggable.
///
/// A one-pixel line is not a hit target, so the handle is a wider transparent
/// strip with the line drawn down its middle — the pointer changes shape a few
/// pixels before the seam, which is what tells someone it can be dragged at
/// all. Double-clicking restores the default, because a divider dragged
/// somewhere silly otherwise has no obvious way back.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.width,
    required this.onChanged,
    super.key,
  });

  final double width;

  /// Called throughout the drag; `done` is true only on the last call, which
  /// is the one worth writing to disk.
  final void Function(double width, {required bool done}) onChanged;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  /// Where the panel edge started, so the drag tracks the pointer exactly.
  ///
  /// Accumulating deltas onto the *reported* width would drift: the reported
  /// width is clamped, so every pixel dragged past a limit would be a pixel
  /// the pointer never gets back on the way in.
  double _origin = 0;
  var _hovering = false;
  var _dragging = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _hovering || _dragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() {
          _dragging = true;
          _origin = widget.width;
        }),
        onHorizontalDragUpdate: (details) {
          _origin += details.delta.dx;
          widget.onChanged(_origin, done: false);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onChanged(_origin, done: true);
        },
        onDoubleTap: () =>
            widget.onChanged(WorkspaceLayout.defaultPanel, done: true),
        child: SizedBox(
          width: 9,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 3 : 1,
              color: active ? scheme.primary : scheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}
