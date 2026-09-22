import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:xterm2/xterm.dart';

import '../../../core/terminal/terminal_find.dart';
import '../../../core/terminal/terminal_links.dart';
import '../../../core/terminal/terminal_session.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/ui/context_menu.dart';
import '../../../core/ui/keyboard_accessory.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../terminal_font_size.dart';
import '../session_shortcuts.dart';
import '../terminal_find_request.dart';
import '../terminal_paste.dart';
import 'terminal_find_bar.dart';
import 'terminal_key_bar.dart';
import 'terminal_link_sheet.dart';

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

  /// Owned here rather than left to the view, so closing the find bar can hand
  /// focus back to the terminal and a match can be scrolled into view.
  final _terminalFocus = FocusNode(debugLabel: 'terminal');
  final _scroll = ScrollController();
  final _viewKey = GlobalKey<TerminalViewState>();
  final _findBarKey = GlobalKey<TerminalFindBarState>();

  late final TerminalFind _find;

  var _findOpen = false;

  /// Where the pointer last went down, for "Open link" in the context menu:
  /// the menu is built after the press, and needs to know what was under it.
  Offset? _lastPointerDown;

  @override
  void initState() {
    super.initState();
    _find = TerminalFind(
      terminal: widget.session.terminal,
      controller: _controller,
    )..addListener(_revealCurrentMatch);
  }

  @override
  void dispose() {
    // Before the controller: clearing the find releases its highlights'
    // anchors, which the controller would otherwise dispose a second time.
    _find
      ..removeListener(_revealCurrentMatch)
      ..dispose();
    _controller.dispose();
    _terminalFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- find

  void _openFind() {
    if (_findOpen) {
      _findBarKey.currentState?.focus();
      return;
    }
    setState(() => _findOpen = true);
    // A query kept from the last time the bar was open is searched again, so
    // its highlights come back with it.
    _find.refresh();
  }

  void _closeFind() {
    if (!_findOpen) return;
    setState(() => _findOpen = false);
    _find.clear();
    _terminalFocus.requestFocus();
  }

  /// Scrolls the current match into view, centred, unless it already is.
  void _revealCurrentMatch() {
    final range = _find.currentRange;
    final view = _viewKey.currentState;
    if (range == null || view == null || !_scroll.hasClients) return;

    final double lineHeight;
    try {
      lineHeight = view.renderTerminal.lineHeight;
    } on StateError {
      return;
    }
    if (lineHeight <= 0) return;

    final position = _scroll.position;
    final top = range.begin.y * lineHeight;
    final visibleTop = position.pixels;
    final visibleBottom = visibleTop + position.viewportDimension;
    if (top >= visibleTop && top + lineHeight <= visibleBottom) return;

    final target = top - (position.viewportDimension - lineHeight) / 2;
    position.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  // --------------------------------------------------------------- links

  /// Ctrl on Windows and Linux, Cmd on macOS — the same modifier xterm2 uses
  /// to decide whether a click on an OSC 8 link is a click on the link.
  static bool get _linkModifierPressed =>
      defaultTargetPlatform == TargetPlatform.macOS
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  /// A plain click on a desktop is for selecting and placing focus, so a link
  /// opens only with the modifier held. On a phone there is no modifier and a
  /// tap is the only gesture there is — so it asks first instead.
  void _onTapUp(TapUpDetails details, CellOffset cell) {
    final terminal = widget.session.terminal;
    if (context.usesSoftwareKeyboard) {
      final link = TerminalLinks.linkAt(terminal, cell);
      if (link != null) openTerminalLink(context, link, confirm: true);
      return;
    }
    // OSC 8 links arrive through onHyperlinkTap; this is the plain-URL half.
    if (!_linkModifierPressed || terminal.hyperlinkAt(cell) != null) return;
    final url = TerminalLinks.plainUrlAtCell(terminal.buffer, cell);
    if (url != null) openTerminalLink(context, url, confirm: false);
  }

  void _onHyperlinkTap(String uri) {
    // Only reached with the modifier held, which a phone does not have.
    openTerminalLink(context, uri, confirm: context.usesSoftwareKeyboard);
  }

  /// The link under where the pointer last went down, if any.
  String? _linkUnderPointer() {
    final global = _lastPointerDown;
    final view = _viewKey.currentState;
    if (global == null || view == null) return null;
    try {
      final render = view.renderTerminal;
      final cell = render.getCellOffset(render.globalToLocal(global));
      return TerminalLinks.linkAt(widget.session.terminal, cell);
    } on StateError {
      return null;
    }
  }

  // --------------------------------------------------------------- menus

  /// The terminal's own key bindings, with two changes.
  ///
  /// Paste goes through [pasteClipboardInto] — sanitised, and confirmed when
  /// it would run something — instead of xterm2's action, which types the
  /// clipboard as-is. And find is added here as well as app-wide: a focused
  /// terminal answers every Ctrl chord itself before an ancestor's shortcuts
  /// are asked, so without this Ctrl+Shift+F would go to the shell.
  static Map<ShortcutActivator, Intent> _terminalShortcuts() => {
    for (final entry in defaultTerminalShortcuts.entries)
      entry.key: entry.value is PasteTextIntent
          ? const TerminalPasteIntent()
          : entry.value,
    findInTerminalActivator(): const FindInTerminalIntent(),
  };

  /// Copy, paste, find, a link under the pointer, and the housekeeping.
  ///
  /// Built per open rather than once: whether there is anything to copy
  /// depends on the selection at the moment the menu is asked for.
  List<MenuAction> _terminalActions(
    BuildContext context,
    TerminalSession session,
  ) {
    final l10n = AppLocalizations.of(context);
    final selection = _controller.selection;
    final link = _linkUnderPointer();

    return [
      if (link != null) ...[
        MenuAction(
          label: l10n.terminalOpenLink,
          icon: PiconsRegular.arrowSquareOut,
          onSelected: () => openTerminalLink(
            context,
            link,
            confirm: context.usesSoftwareKeyboard,
          ),
        ),
        MenuAction(
          label: l10n.terminalCopyLink,
          icon: PiconsRegular.link,
          onSelected: () => copyTerminalLink(context, link),
        ),
      ],
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
        // Sanitised and, when it would run a command, confirmed. See
        // [pasteClipboardInto].
        onSelected: () => pasteClipboardInto(context, ref, session.terminal),
      ),
      MenuAction(
        label: l10n.terminalFind,
        icon: PiconsRegular.magnifyingGlass,
        onSelected: _openFind,
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
    final fontSize = ref.watch(terminalFontSizeProvider(session.hostId));

    // The menu bar, the app-wide shortcut and the phone's app bar ask for the
    // find bar through this; only the pane showing that session answers.
    ref.listen(terminalFindRequestProvider, (_, request) {
      if (request != null && request.sessionId == session.id) _openFind();
    });

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
      child: Actions(
        actions: <Type, Action<Intent>>{
          TerminalPasteIntent: CallbackAction<TerminalPasteIntent>(
            onInvoke: (_) {
              pasteClipboardInto(context, ref, session.terminal);
              return null;
            },
          ),
          FindInTerminalIntent: CallbackAction<FindInTerminalIntent>(
            onInvoke: (_) {
              _openFind();
              return null;
            },
          ),
        },
        child: Listener(
          onPointerDown: (event) => _lastPointerDown = event.position,
          child: TerminalView(
            session.terminal,
            key: _viewKey,
            controller: _controller,
            focusNode: _terminalFocus,
            scrollController: _scroll,
            autofocus: true,
            backgroundOpacity: 1,
            padding: const EdgeInsets.all(Spacing.xs),
            theme: appTerminalTheme(Theme.of(context).colorScheme),
            textStyle: TerminalStyle(
              fontFamily: Mono.family,
              fontFamilyFallback: Mono.fallback,
              fontSize: fontSize,
            ),
            // The grid has its own size setting; the app-wide text scale must
            // not compound onto it and reflow the columns the remote program
            // drew.
            textScaler: TextScaler.noScaling,
            shortcuts: _terminalShortcuts(),
            onHyperlinkTap: _onHyperlinkTap,
            onTapUp: _onTapUp,
          ),
        ),
      ),
      builder: (context, child) => Column(
        children: [
          if (!session.isLive) _PaneStatusBar(session: session),
          if (_findOpen)
            TerminalFindBar(key: _findBarKey, find: _find, onClose: _closeFind),
          Expanded(
            child: ContextMenuRegion(
              actions: () => _terminalActions(context, session),
              child: child!,
            ),
          ),
          // An accessory to the software keyboard: present only with one, and
          // never on a platform that has real modifier keys.
          if (context.usesSoftwareKeyboard)
            KeyboardAccessory(
              child: TerminalKeyBar(
                terminal: session.terminal,
                modifiers: session.modifiers,
              ),
            ),
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
