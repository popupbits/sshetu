import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm2/xterm.dart';

import '../../core/terminal/terminal_session.dart';
import '../../core/ui/views.dart';
import '../../l10n/app_localizations.dart';
import 'session_manager.dart';
import 'widgets/terminal_key_bar.dart';

/// One session, full screen.
///
/// Pushed over the shell rather than living inside a tab: a terminal wants
/// every pixel, and a navigation bar under it is both wasted space and
/// something to hit by accident while reaching for the key bar.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _controller = TerminalController();

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionManagerProvider);
    final session = sessions
        .where((s) => s.id == widget.sessionId)
        .firstOrNull;

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

    // ListenableBuilder rather than a provider: the session is a
    // ChangeNotifier that ticks on every status change, and the terminal
    // itself repaints independently. Rebuilding this subtree is cheap; the
    // TerminalView below is not rebuilt by it.
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          bottom: session.status == TerminalSessionStatus.connecting
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
          actions: [
            if (session.status == TerminalSessionStatus.failed ||
                session.status == TerminalSessionStatus.closed)
              IconButton(
                tooltip: l10n.terminalReconnect,
                icon: const Icon(PiconsRegular.arrowClockwise),
                onPressed: session.start,
              ),
            IconButton(
              tooltip: l10n.terminalCloseTab,
              icon: const Icon(PiconsRegular.x),
              onPressed: () {
                ref.read(sessionManagerProvider.notifier).close(session.id);
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: TerminalView(
                session.terminal,
                controller: _controller,
                autofocus: true,
                backgroundOpacity: 1,
                padding: const EdgeInsets.all(4),
              ),
            ),
            TerminalKeyBar(onSend: session.send),
          ],
        ),
      ),
    );
  }
}
