import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../open_screens.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui/views.dart';
import '../../../l10n/app_localizations.dart';
import '../session_manager.dart';
import '../pane_commands.dart';
import '../workspace_pages.dart';
import 'session_tab_strip.dart';
import 'tab_panes.dart';

/// The terminal half of the desktop layout: tabs, and the session they select.
///
/// Always on screen, whatever the side panel is showing. That is the whole
/// point of a workspace — reaching for a key or a port forward should not
/// take the shell you are working in off the screen, and going back to it
/// should not be navigation.
class TerminalWorkspace extends ConsumerWidget {
  const TerminalWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);
    final active = ref.read(sessionManagerProvider.notifier).active;
    final pages = ref.watch(workspacePagesProvider);
    final page = ref.read(workspacePagesProvider.notifier).selected;
    final scheme = Theme.of(context).colorScheme;

    final empty = ColoredBox(
      key: const ValueKey('workspace.empty'),
      color: scheme.surface,
      child: EmptyView(
        icon: PiconsRegular.terminalWindow,
        title: l10n.sessionsEmptyTitle,
        message: l10n.sessionsEmptyPickHost,
      ),
    );
    // Only with nothing open at all: a page with no session selected still
    // needs its tab, and must stay built.
    if (sessions.isEmpty && pages.isEmpty) return empty;

    return Column(
      children: [
        SessionTabStrip(
          alwaysShow: true,
          actions: [
            if (active != null)
              IconButton(
                tooltip: l10n.filesTitle,
                icon: const Icon(PiconsRegular.folderOpen, size: 16),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => openFiles(context, ref, active.id),
              ),
            if (active != null)
              IconButton(
                key: const Key('workspace.splitRight'),
                tooltip: l10n.paneSplitRight,
                icon: const Icon(PiconsRegular.columns, size: 16),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () =>
                    runPaneCommand(context, ref, PaneCommand.splitRight),
              ),
            const SizedBox(width: Spacing.xs),
          ],
        ),
        Expanded(
          // A page covers the terminal rather than replacing the window: the
          // session keeps running, its tab stays put, and one click is back.
          //
          // Every open page stays built, not just the selected one. Building
          // only the selected page disposed the others on every switch, so
          // going to a terminal and back threw a page's state away — the
          // file browser returned to / and to Documents. Hidden pages are
          // offstage, their tickers are off and they cannot take focus; each
          // is keyed by its id so switching never hands one page's state to
          // another. Closing a tab removes it from this list, which is what
          // disposes it.
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (page == null)
                active == null
                    ? empty
                    // The active session's tab: its one pane, or its split
                    // layout.
                    : TabPanes(
                        key: const ValueKey('workspace.terminal'),
                        active: active,
                      ),
              for (final open in pages)
                _KeptPage(
                  key: ValueKey('page:${open.id}'),
                  page: open,
                  visible: open.id == page?.id,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One open page, built whether or not it is the one showing.
///
/// Hidden, it keeps its state but does nothing a hidden page should not:
/// offstage, so it neither paints, takes pointers nor appears in the
/// semantics tree; tickers off, so an animation or a spinner stops costing
/// frames; and focus excluded, so a key press can never land in a page
/// nobody can see.
///
/// Each page has its own [Overlay], so the menus and tooltips it opens live
/// inside it. In the app's overlay they outlived the page going offstage: an
/// open menu stayed on screen over whatever tab was showing, and its
/// semantics — grafted onto an anchor that had left the tree — were sent to
/// the platform with no parent, which Windows' accessibility bridge rejects
/// ("will not be in the tree and is not the new root") and then keeps
/// rejecting. Dialogs and sheets still go to the navigator's overlay.
class _KeptPage extends StatelessWidget {
  const _KeptPage({required this.page, required this.visible, super.key});

  final WorkspacePage page;
  final bool visible;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !visible,
    child: TickerMode(
      enabled: visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: Overlay.wrap(
          // Material, not a ColoredBox. A page is a whole screen, and screens
          // contain ListTiles, ink and switches — all of which paint onto the
          // nearest Material ancestor. A bare ColoredBox gives them a
          // background they cannot draw on, and ListTile asserts about it *on
          // every frame*: with an animating spinner on the page that is sixty
          // exceptions a second, each building a full diagnostic tree, which
          // is what took the window down.
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: WorkspacePageScope(
              id: page.id,
              child: Builder(builder: page.builder),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The header above the side panel.
///
/// One [Chrome.tabStrip] row, the same as the session tabs opposite it, so the
/// two columns start on the same line instead of nearly doing so.
class PanelHeader extends StatelessWidget {
  const PanelHeader({required this.title, this.actions = const [], super.key});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: Chrome.tabStrip,
      padding: const EdgeInsets.only(left: Spacing.lg, right: Spacing.xs),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
