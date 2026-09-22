import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'open_screens.dart';

import '../../core/ssh/ssh_target.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../hosts/widgets/open_key_setup.dart';
import '../server_info/server_info_dock.dart';
import '../session_log/session_log_actions.dart';
import '../session_log/session_log_controller.dart';
import '../session_log/widgets/session_log_dot.dart';
import '../server_info/server_info_panel.dart';
import '../snippets/open_snippets.dart';
import '../../l10n/app_localizations.dart';
import 'server_sessions.dart';
import 'session_manager.dart';
import 'terminal_find_request.dart';
import 'widgets/session_tab_strip.dart';
import 'widgets/tab_panes.dart';

/// One session, full screen. The phone's terminal.
///
/// Pushed over the shell rather than living inside a tab: a terminal wants
/// every pixel, and a navigation bar under it is both wasted space and
/// something to hit by accident while reaching for the key bar. The desktop
/// does not use this at all — see `SessionsScreen`'s workspace.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  @override
  void initState() {
    super.initState();
    // A shell that dies because the screen dimmed mid-command is the most
    // annoying possible failure. Held only while this screen is on top, and
    // released in dispose — an app that quietly keeps a phone awake forever is
    // the second most annoying.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sessions = ref.watch(sessionManagerProvider);
    final manager = ref.read(sessionManagerProvider.notifier);
    final logs = ref.watch(sessionLogControllerProvider);

    // Follows the *active* session rather than the id this route was opened
    // with, so switching tabs in the strip changes what this screen shows
    // instead of pushing another copy of it over the top.
    final session =
        manager.active ??
        sessions.where((s) => s.id == widget.sessionId).firstOrNull;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(
          icon: PiconsRegular.terminalWindow,
          title: l10n.sessionsEmptyTitle,
          message: l10n.sessionsEmptyBody,
        ),
      );
    }

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      session.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SessionLogDot(sessionId: session.id, leading: Spacing.sm),
                ],
              ),
              // The address under the name. With three sessions open on hosts
              // all called "prod", which machine you are typing into matters
              // more than the label you gave it.
              Text(
                session.target.address,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Four buttons and a menu, at most five slots: 56 + 5 × 48 fits a
          // 360 pt phone with room for the title. Every action used mid-command
          // stays one tap away; the rest are one menu away.
          actions: [
            // The phone has no Ctrl+Shift+F and a long-press sheet is a
            // gesture people have to discover, so find gets a button.
            IconButton(
              tooltip: l10n.terminalFind,
              icon: const Icon(PiconsRegular.magnifyingGlass),
              onPressed: () => ref
                  .read(terminalFindRequestProvider.notifier)
                  .request(session.id),
            ),
            // No Ctrl+Shift+S on a phone either; saved commands get a button.
            IconButton(
              key: const Key('terminal.snippets'),
              tooltip: l10n.menuSnippets,
              icon: const Icon(PiconsRegular.codeBlock),
              onPressed: () =>
                  openSnippetPicker(context, ref, sessionId: session.id),
            ),
            // Opens the SFTP browser over this session's *existing*
            // connection rather than dialling the host a second time.
            IconButton(
              tooltip: l10n.filesTitle,
              icon: const Icon(PiconsRegular.folderOpen),
              onPressed: () => openFiles(context, ref, session.id),
            ),
            PopupMenuButton<_MoreAction>(
              key: const Key('terminal.more'),
              tooltip: l10n.terminalMoreActions,
              icon: const Icon(PiconsRegular.dotsThreeVertical),
              onSelected: (action) => switch (action) {
                _MoreAction.runningSessions => openRunningSessionsForTab(
                  context,
                  ref,
                  session,
                ),
                _MoreAction.serverInfo => openServerInfo(context, ref, session),
                _MoreAction.ports => showServerInfoSheet(
                  context,
                  session,
                  initialTab: ServerInfoPanel.portsTab,
                ),
                _MoreAction.keySetup => unawaited(
                  openKeySetup(context, ref, session.hostId),
                ),
                _MoreAction.log => unawaited(
                  toggleSessionLog(context, ref, session),
                ),
              },
              itemBuilder: (context) => [
                // What else SSHetu keeps running on this server — from this
                // device or another one. The strip, and its menu, is hidden
                // with a single tab on a phone, so it is reachable here.
                PopupMenuItem(
                  key: const Key('terminal.runningSessions'),
                  value: _MoreAction.runningSessions,
                  child: _MoreItem(
                    icon: PiconsRegular.stack,
                    label: l10n.sessionRunningSessions,
                  ),
                ),
                // CPU, memory, disks and processes of the machine behind
                // this tab, over its own connection.
                PopupMenuItem(
                  key: const Key('terminal.serverInfo'),
                  value: _MoreAction.serverInfo,
                  child: _MoreItem(
                    icon: PiconsRegular.gauge,
                    label: l10n.serverInfoTitle,
                  ),
                ),
                // Logging, which the tab strip's menu also offers — but
                // that strip is hidden with a single tab on a phone.
                PopupMenuItem(
                  key: const Key('terminal.log'),
                  value: _MoreAction.log,
                  child: _MoreItem(
                    icon: logs.containsKey(session.id)
                        ? PiconsRegular.stopCircle
                        : PiconsRegular.record,
                    label: logs.containsKey(session.id)
                        ? l10n.sessionLogStop
                        : l10n.sessionLogStartEllipsis,
                  ),
                ),
                // What the server is listening on, each a tap from a
                // forward to this phone.
                PopupMenuItem(
                  key: const Key('terminal.ports'),
                  value: _MoreAction.ports,
                  child: _MoreItem(
                    icon: PiconsRegular.plugs,
                    label: l10n.portsTitle,
                  ),
                ),
                // Offered only on a password session: this is the one screen
                // where the means to install a key — a way in — is already
                // open.
                if (session.connection.target.authMethod ==
                    SshAuthMethod.password)
                  PopupMenuItem(
                    value: _MoreAction.keySetup,
                    child: _MoreItem(
                      icon: PiconsRegular.key,
                      label: l10n.keySetupTitle,
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: l10n.terminalCloseTab,
              icon: const Icon(PiconsRegular.x),
              onPressed: () {
                manager.close(session.id);
                // Only leave when that was the last one; otherwise the strip
                // has already moved to a neighbour and there is a session
                // here to stay on.
                if (ref.read(sessionManagerProvider).isEmpty) {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Reachable without backing out: with several sessions open, the
            // strip is how you move between them on a phone.
            const SessionTabStrip(),
            Expanded(
              // One pane at a time here, with a switcher for a split tab.
              child: TabPanes(active: session),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MoreAction { runningSessions, serverInfo, ports, keySetup, log }

/// An icon and a label, the shape of every row in the terminal's More menu.
class _MoreItem extends StatelessWidget {
  const _MoreItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: Spacing.md),
      Flexible(child: Text(label)),
    ],
  );
}
