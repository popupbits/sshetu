import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:xterm2/xterm.dart';

import '../../../core/terminal/terminal_session.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/ui/context_menu.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import 'terminal_key_bar.dart';

/// One session's terminal, with the chrome that belongs to the pane itself.
///
/// Shared by the phone's full-screen terminal and the desktop workspace, so a
/// session looks and behaves the same in both and there is one place to change
/// how a terminal is drawn.
class TerminalPane extends ConsumerStatefulWidget {
  const TerminalPane({required this.session, super.key});

  final TerminalSession session;

  @override
  ConsumerState<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<TerminalPane> {
  final _controller = TerminalController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Copy, paste and the two housekeeping actions.
  ///
  /// Built per open rather than once: whether there is anything to copy
  /// depends on the selection at the moment the menu is asked for.
  List<MenuAction> _terminalActions(
    BuildContext context,
    TerminalSession session,
  ) {
    final l10n = AppLocalizations.of(context);
    final selection = _controller.selection;

    return [
      if (selection != null)
        MenuAction(
          label: l10n.actionCopy,
          icon: PiconsRegular.copy,
          onSelected: () async {
            final text = session.terminal.buffer.getText(selection);
            await Clipboard.setData(ClipboardData(text: text));
            _controller.clearSelection();
          },
        ),
      MenuAction(
        label: l10n.actionPaste,
        icon: PiconsRegular.clipboard,
        onSelected: () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final text = data?.text;
          // `Terminal.paste` rather than writing the text as keystrokes: it
          // handles bracketed paste, which is what stops a shell from running
          // half a pasted script the moment it sees the first newline.
          if (text != null && text.isNotEmpty) session.terminal.paste(text);
        },
      ),
      MenuAction(
        label: l10n.actionSelectAll,
        icon: PiconsRegular.selection,
        onSelected: () => _controller.setSelection(
          session.terminal.buffer.createAnchor(0, 0),
          session.terminal.buffer.createAnchor(
            session.terminal.viewWidth - 1,
            session.terminal.buffer.lines.length - 1,
          ),
        ),
      ),
      MenuAction(
        label: l10n.actionClear,
        icon: PiconsRegular.eraser,
        onSelected: () => session.terminal.buffer.clearScrollback(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return ListenableBuilder(
      listenable: session,
      // The TerminalView is passed as `child` so it is *not* rebuilt when the
      // session's status ticks. It repaints itself from the terminal's own
      // notifier; rebuilding it here would throw away its scroll position and
      // its selection every time a status line changed.
      // Built from the app's ColorScheme, so the terminal follows the theme
      // mode and accent the user chose instead of shipping xterm2's own
      // palette regardless — which on a light theme meant a dark terminal
      // pasted into a light window.
      child: TerminalView(
        session.terminal,
        controller: _controller,
        autofocus: true,
        backgroundOpacity: 1,
        padding: const EdgeInsets.all(Spacing.xs),
        theme: appTerminalTheme(Theme.of(context).colorScheme),
        textStyle: TerminalStyle(
          fontFamily: Mono.family,
          fontFamilyFallback: Mono.fallback,
          fontSize: 13,
        ),
      ),
      builder: (context, child) => Column(
        children: [
          if (!session.isLive) _PaneStatusBar(session: session),
          Expanded(
            child: ContextMenuRegion(
              actions: () => _terminalActions(context, session),
              child: child!,
            ),
          ),
          // An accessory to the software keyboard: present only with one, and
          // never on a platform that has real modifier keys.
          if (context.usesSoftwareKeyboard && context.isSoftwareKeyboardVisible)
            TerminalKeyBar(onSend: session.send),
        ],
      ),
    );
  }
}

/// The bar drawn over a pane whose session is not live.
///
/// A terminal that cannot be typed into looks exactly like one that can — a
/// prompt is a prompt whether it is live or a week old. This says which, in
/// words, and carries the only way back. Nothing here reconnects on its own:
/// a session the user ended should stay ended.
class _PaneStatusBar extends StatelessWidget {
  const _PaneStatusBar({required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final failed = session.status == TerminalSessionStatus.failed;

    if (session.status == TerminalSessionStatus.connecting) {
      return Container(
        height: Chrome.statusBar,
        color: scheme.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: Spacing.sm),
            Text(l10n.terminalConnecting, style: theme.textTheme.labelSmall),
          ],
        ),
      );
    }

    return Material(
      color: failed ? scheme.errorContainer : scheme.surfaceContainerHigh,
      child: SizedBox(
        height: Chrome.statusBar,
        child: Row(
          children: [
            const SizedBox(width: Spacing.md),
            Icon(
              failed ? PiconsRegular.warning : PiconsRegular.plugsConnected,
              size: 12,
              color: failed ? scheme.onErrorContainer : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                // The failure's own words when there are any: "connection
                // refused" is worth more than "disconnected".
                session.error ?? l10n.terminalSessionEnded,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: failed ? scheme.onErrorContainer : null,
                ),
              ),
            ),
            TextButton(
              onPressed: session.start,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.terminalReconnect),
            ),
            const SizedBox(width: Spacing.sm),
          ],
        ),
      ),
    );
  }
}
