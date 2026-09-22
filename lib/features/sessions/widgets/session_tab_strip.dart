import 'dart:async';

import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/terminal_session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../pane_commands.dart';
import '../pane_layouts.dart';
import '../../server_info/server_info_dock.dart';
import '../../session_log/session_log_actions.dart';
import '../../session_log/session_log_controller.dart';
import '../../session_log/widgets/session_log_dot.dart';
import '../restart_in_tmux.dart';
import '../server_sessions.dart';
import '../session_manager.dart';
import '../workspace_pages.dart';

/// The row of open sessions.
///
/// One [Chrome.tabStrip] row and no more. A terminal's scarcest resource is
/// vertical space, so the strip is not drawn at all when a single session is
/// open — the screen's own title bar is already that session's header, and a
/// second row saying the same thing would be pure cost.
class SessionTabStrip extends ConsumerStatefulWidget {
  const SessionTabStrip({
    this.actions = const [],
    this.alwaysShow = false,
    super.key,
  });

  /// Actions for the *selected* session, drawn at the end of the row.
  ///
  /// The desktop workspace has no AppBar — the panel header and this strip are
  /// its only chrome — so without somewhere here to put them, a session's
  /// actions have nowhere to live at all. That is how the file browser
  /// shipped reachable only on a phone.
  final List<Widget> actions;

  /// Draw the row even with a single session open.
  ///
  /// True on desktop, where this row *is* the pane's header and its actions;
  /// false on a phone, where the AppBar already names the session and a second
  /// row saying the same thing is pure cost.
  final bool alwaysShow;

  @override
  ConsumerState<SessionTabStrip> createState() => _SessionTabStripState();
}

class _SessionTabStripState extends ConsumerState<SessionTabStrip> {
  final _scroll = ScrollController();

  /// One key per tab, by session or page id, so the selected one can be
  /// found and scrolled to.
  final _keys = <String, GlobalKey>{};

  /// The tab last scrolled into view; a rebuild that selects nothing new
  /// leaves the strip where the user put it.
  String? _revealed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Brings the selected tab into view after this frame — chosen from the
  /// palette, with Ctrl+Tab or by opening it, it may be far off the edge.
  /// Only as far as needed: a tab already showing does not move.
  void _reveal(String? id) {
    if (id == null || id == _revealed) return;
    _revealed = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[id]?.currentContext;
      if (!mounted || target == null) return;
      for (final policy in const [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        unawaited(Scrollable.ensureVisible(target, alignmentPolicy: policy));
      }
    });
  }

  /// A plain mouse wheel scrolls the strip. A horizontal list otherwise
  /// only follows Shift+wheel or a trackpad, and a desktop with twenty tabs
  /// open is exactly where someone reaches for the wheel.
  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    final delta = event.scrollDelta;
    if (delta.dx != 0 || delta.dy == 0) return;
    final position = _scroll.position;
    final target = (position.pixels + delta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) position.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    final sessions = ref.watch(sessionManagerProvider);
    final manager = ref.read(sessionManagerProvider.notifier);
    final pages = ref.watch(workspacePagesProvider);
    final workspace = ref.read(workspacePagesProvider.notifier);
    // A page covers the terminal while it is selected, so no session tab is
    // the selected one then.
    final selectedPageId = workspace.selected?.id;
    final activeId = selectedPageId == null ? manager.activeId : null;
    final scheme = Theme.of(context).colorScheme;
    // One tab per split layout, not one per pane.
    ref.watch(paneLayoutsProvider);
    final tabs = manager.tabs;
    // Keeps session logging alive while any terminal is on screen, so a tab
    // opened with "always log" on starts its log.
    ref.listen(sessionLogControllerProvider, (_, _) {});

    if (sessions.isEmpty && pages.isEmpty) return const SizedBox.shrink();
    if (tabs.length + pages.length < 2 && !widget.alwaysShow) {
      return const SizedBox.shrink();
    }

    String stripId(int index) => index >= tabs.length
        ? 'page:${pages[index - tabs.length].id}'
        : 'tab:${tabs[index].panes.first}';
    final ids = {
      for (var i = 0; i < tabs.length + pages.length; i++) stripId(i),
    };
    _keys.removeWhere((id, _) => !ids.contains(id));
    final selectedIndex = selectedPageId != null
        ? tabs.length + pages.indexWhere((p) => p.id == selectedPageId)
        : tabs.indexWhere((t) => activeId != null && t.contains(activeId));
    _reveal(
      selectedIndex >= 0 && selectedIndex < tabs.length + pages.length
          ? stripId(selectedIndex)
          : null,
    );

    return Container(
      height: Chrome.tabStrip,
      color: scheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: Listener(
              onPointerSignal: _onWheel,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                // Every tab built, not lazily: the selected one has to exist
                // to be scrolled to, and a strip is tens of tabs, not
                // thousands.
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < tabs.length + pages.length;
                      index++
                    )
                      KeyedSubtree(
                        key: _keyFor(stripId(index)),
                        child: Builder(
                          builder: (context) {
                            // Pages sit after the sessions, so opening one never reorders
                            // the tabs someone is already working in.
                            if (index >= tabs.length) {
                              final page = pages[index - tabs.length];
                              return _PageTab(
                                page: page,
                                selected: page.id == selectedPageId,
                                onTap: () => workspace.select(page.id),
                                onClose: () => unawaited(
                                  workspace.requestClose(context, page.id),
                                ),
                              );
                            }
                            // A split tab speaks for the pane last used in it.
                            final tab = tabs[index];
                            final session =
                                manager.byId(tab.focused) ??
                                manager.byId(tab.panes.first)!;
                            return ContextMenuRegion(
                              title: session.title,
                              actions: () => [
                                if (session.isLive)
                                  MenuAction(
                                    label: AppLocalizations.of(context)
                                        .sessionDisconnect,
                                    icon: PiconsRegular.plugs,
                                    // Ends the shell but keeps the tab, so the scrollback
                                    // is still there to read — which is the whole
                                    // difference between disconnecting and closing.
                                    onSelected: session.disconnect,
                                  ),
                                if (session.canRestartInTmux)
                                  MenuAction(
                                    label: AppLocalizations.of(context)
                                        .terminalRestartInTmux,
                                    icon: PiconsRegular.arrowsClockwise,
                                    onSelected: () => confirmRestartInTmux(
                                      context,
                                      ref,
                                      session,
                                    ),
                                  ),
                                MenuAction(
                                  label: AppLocalizations.of(context)
                                      .sessionRunningSessions,
                                  icon: PiconsRegular.stack,
                                  onSelected: () => openRunningSessionsForTab(
                                    context,
                                    ref,
                                    session,
                                  ),
                                ),
                                ...paneTabMenuActions(context, ref, session.id),
                                ...sessionLogMenuActions(context, ref, session),
                                MenuAction(
                                  label: isServerInfoShowing(ref, session)
                                      ? AppLocalizations.of(context)
                                            .serverInfoHide
                                      : AppLocalizations.of(context)
                                            .serverInfoShow,
                                  icon: PiconsRegular.gauge,
                                  onSelected: () =>
                                      openServerInfo(context, ref, session),
                                ),
                                MenuAction(
                                  label: AppLocalizations.of(context)
                                      .terminalCloseTab,
                                  icon: PiconsRegular.x,
                                  onSelected: () =>
                                      manager.closeTab(session.id),
                                ),
                                if (tabs.length > 1)
                                  MenuAction(
                                    label: AppLocalizations.of(context)
                                        .sessionCloseOthers,
                                    icon: PiconsRegular.xCircle,
                                    isDestructive: true,
                                    onSelected: () {
                                      // Snapshot first: closing mutates the list this
                                      // would otherwise be iterating.
                                      final others = [
                                        for (final other in sessions)
                                          if (!tab.contains(other.id)) other.id,
                                      ];
                                      for (final id in others) {
                                        manager.close(id);
                                      }
                                    },
                                  ),
                              ],
                              child: _SessionTab(
                                session: session,
                                selected:
                                    activeId != null && tab.contains(activeId),
                                panes: tab.panes.length,
                                broadcasting: tab.tree?.broadcast ?? false,
                                onTap: () {
                                  workspace.deselect();
                                  manager.select(session.id);
                                },
                                onClose: () => manager.closeTab(session.id),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onClose,
    this.panes = 1,
    this.broadcasting = false,
  });

  final TerminalSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  /// How many panes the tab holds; more than one shows a count.
  final int panes;

  /// Whether the tab is typing into all its panes — flagged here too, so it
  /// is visible from any tab, not only from inside the one doing it.
  final bool broadcasting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Material(
        // The selected tab takes the colour of the ground its content sits on,
        // so the tab and the terminal below read as one surface rather than
        // two stacked panels.
        color: selected ? scheme.surface : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: Chrome.tabStrip,
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.xs),
            decoration: BoxDecoration(
              border: Border(
                // Selection is a rule in the accent, not an outline: an outline
                // is invisible against a neutral ramp at this size.
                top: BorderSide(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: Chrome.selectionRule,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LivenessDot(status: session.status),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SessionLogDot(sessionId: session.id, leading: Spacing.xs),
                if (broadcasting) ...[
                  const SizedBox(width: Spacing.xs),
                  Tooltip(
                    message: l10n.paneTypeInAll,
                    child: Icon(
                      PiconsRegular.broadcast,
                      size: 12,
                      color: scheme.error,
                    ),
                  ),
                ],
                if (panes > 1) ...[
                  const SizedBox(width: Spacing.xs),
                  Tooltip(
                    message: l10n.paneCount(panes),
                    child: Text(
                      '$panes',
                      key: const Key('tab.paneCount'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: Spacing.xs),
                IconButton(
                  tooltip: l10n.terminalCloseTab,
                  onPressed: onClose,
                  icon: const Icon(PiconsRegular.x, size: 12),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 22,
                    height: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether a tab has a live session behind it.
///
/// A **shape**, not a tint on the label. Karmashala's shell makes the argument
/// and it holds here: whether a session is running is not something to say by
/// colouring its name — colour is already carrying selection, and a
/// red-vs-green label reads as an error rather than a state. A filled dot is
/// live, a hollow ring is not, and the difference survives being colour-blind.
class _LivenessDot extends StatelessWidget {
  const _LivenessDot({required this.status});

  final TerminalSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (status == TerminalSessionStatus.connecting) {
      return SizedBox.square(
        dimension: 8,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: scheme.primary,
        ),
      );
    }

    final live = status == TerminalSessionStatus.running;
    final failed = status == TerminalSessionStatus.failed;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: live ? scheme.primary : Colors.transparent,
        border: live
            ? null
            : Border.all(
                color: failed ? scheme.error : scheme.outline,
                width: 1.5,
              ),
      ),
    );
  }
}

/// A non-terminal tab. Same shape as a session's, without the liveness dot —
/// a page has no connection to be alive or dead.
class _PageTab extends StatelessWidget {
  const _PageTab({
    required this.page,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final WorkspacePage page;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: selected ? scheme.surface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: Chrome.tabStrip,
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.xs),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: selected ? scheme.primary : Colors.transparent,
                width: Chrome.selectionRule,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                page.icon,
                size: 12,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  page.titleIn(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.xs),
              IconButton(
                tooltip: l10n.terminalCloseTab,
                onPressed: onClose,
                icon: const Icon(PiconsRegular.x, size: 12),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 22,
                  height: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
