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
    ref.watch(workspacePagesProvider);
    final page = ref.read(workspacePagesProvider.notifier).selected;
    final scheme = Theme.of(context).colorScheme;

    if (sessions.isEmpty && page == null) {
      return ColoredBox(
        color: scheme.surface,
        child: EmptyView(
          icon: PiconsRegular.terminalWindow,
          title: l10n.sessionsEmptyTitle,
          message: l10n.sessionsEmptyPickHost,
        ),
      );
    }

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
          child: page != null
              // Material, not a ColoredBox. A page is a whole screen, and
              // screens contain ListTiles, ink and switches — all of which
              // paint onto the nearest Material ancestor. A bare ColoredBox
              // gives them a background they cannot draw on, and ListTile
              // asserts about it *on every frame*: with an animating spinner
              // on the page that is sixty exceptions a second, each building
              // a full diagnostic tree, which is what took the window down.
              ? Material(
                  color: scheme.surface,
                  child: WorkspacePageScope(
                    id: page.id,
                    child: Builder(
                      key: ValueKey(page.id),
                      builder: page.builder,
                    ),
                  ),
                )
              : active == null
              ? const SizedBox.shrink()
              // The active session's tab: its one pane, or its split layout.
              : TabPanes(active: active),
        ),
      ],
    );
  }
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
