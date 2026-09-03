import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/ui/views.dart';
import '../../l10n/app_localizations.dart';
import 'session_manager.dart';
import 'widgets/session_tab_strip.dart';
import 'widgets/terminal_pane.dart';

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
              Text(session.title, style: theme.textTheme.titleMedium),
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
          actions: [
            // Opens the SFTP browser over this session's *existing*
            // connection rather than dialling the host a second time.
            IconButton(
              tooltip: l10n.filesTitle,
              icon: const Icon(PiconsRegular.folderOpen),
              onPressed: () => context.pushTo(Routes.filesFor(session.id)),
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
              child: TerminalPane(key: ValueKey(session.id), session: session),
            ),
          ],
        ),
      ),
    );
  }
}
