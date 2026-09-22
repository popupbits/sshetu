import 'dart:async';

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
import '../../../core/settings/settings_controller.dart';
import '../../../core/ui/context_menu.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/keyboard_accessory.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../palette/open_command_palette.dart';
import '../../palette/palette_shortcuts.dart';
import '../../snippets/open_snippets.dart';
import '../terminal_appearance.dart';
import '../terminal_font_size.dart';
import '../session_shortcuts.dart';
import '../terminal_find_request.dart';
import '../pane_commands.dart';
import '../session_manager.dart';
import '../terminal_paste.dart';
import 'terminal_find_bar.dart';
import 'terminal_key_bar.dart';
import 'pane_status_bar.dart';
import 'terminal_link_sheet.dart';
import 'tmux_install_banner.dart';

/// One session's terminal, with the chrome that belongs to the pane itself.
///
/// Shared by the phone's full-screen terminal and the desktop workspace, so a
/// session looks and behaves the same in both and there is one place to change
/// how a terminal is drawn.
class TerminalPane extends ConsumerStatefulWidget {
  const TerminalPane({
    required this.session,
    this.autofocus = true,
    this.onFocused,
    super.key,
  });

  final TerminalSession session;

  /// Whether this pane should hold the keyboard. True for a lone pane; in a
  /// split, only the active pane's — and turning it on later moves focus
  /// here, which is how next-pane reaches the keyboard.
  final bool autofocus;

  /// Called when the terminal takes keyboard focus, however it got it — a
  /// click in a split's other pane is how that pane becomes the active one.
  final VoidCallback? onFocused;

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

  /// Terminals that have already been given the user's blink preference.
  ///
  /// Blink is terminal state, not view state — a program turns it on and off
  /// with DECSCUSR or DECSET 12 — so the preference is applied once per
  /// terminal, when it is first shown. Re-applying it every time a pane is
  /// rebuilt for the same session would undo whatever the program asked for.
  static final _blinkApplied = Expando<bool>('cursor blink applied');

  @override
  void initState() {
    super.initState();
    _find = TerminalFind(
      terminal: widget.session.terminal,
      controller: _controller,
    )..addListener(_revealCurrentMatch);
    final terminal = widget.session.terminal;
    if (_blinkApplied[terminal] != true) {
      _blinkApplied[terminal] = true;
      terminal.setCursorBlinkMode(
        ref.read(settingsControllerProvider).cursorBlink,
      );
    }
    _terminalFocus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_terminalFocus.hasFocus) widget.onFocused?.call();
  }

  @override
  void didUpdateWidget(TerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus && !oldWidget.autofocus) {
      _terminalFocus.requestFocus();
    }
  }

  /// Paste text that has been through the sanitiser and any confirmation —
  /// into this pane, and into every pane of the tab when it is typing into
  /// all of them.
  void _deliverPaste(String text) => ref
      .read(sessionManagerProvider.notifier)
      .pasteToTab(widget.session, text);

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
  /// Copies the selection, or says how to make one. The key bar's copy: a
  /// phone's long press selects text but cannot also open the menu.
  Future<void> _copySelection(
    BuildContext context,
    TerminalSession session,
  ) async {
    final selection = _controller.selection;
    if (selection == null) {
      context.toast(AppLocalizations.of(context).terminalNothingSelected);
      return;
    }
    final text = session.terminal.buffer.getText(selection);
    await Clipboard.setData(ClipboardData(text: text));
    _controller.clearSelection();
  }

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
    snippetPickerActivator(): const OpenSnippetsIntent(),
    // Only the terminal-safe chords: plain Ctrl+K stays the shell's.
    for (final activator in terminalCommandPaletteActivators())
      activator: const OpenCommandPaletteIntent(),
    ...paneShortcutMap(),
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
        onSelected: () => pasteClipboardInto(
          context,
          ref,
          session.terminal,
          deliver: _deliverPaste,
        ),
      ),
      MenuAction(
        label: l10n.terminalFind,
        icon: PiconsRegular.magnifyingGlass,
        onSelected: _openFind,
      ),
      MenuAction(
        label: l10n.menuSnippets,
        icon: PiconsRegular.codeBlock,
        onSelected: () =>
            openSnippetPicker(context, ref, sessionId: session.id),
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
    final l10n = AppLocalizations.of(context);
    final fontSize = ref.watch(terminalFontSizeProvider(session.hostId));
    final preset = ref.watch(terminalThemePresetProvider(session.hostId));
    final font = ref.watch(terminalFontProvider);
    final cursorShape = ref.watch(
      settingsControllerProvider.select((s) => s.cursorShape),
    );
    // Changing the setting is a deliberate act, so it does reach terminals
    // that are already open — unlike a rebuild, which must not.
    ref.listen(settingsControllerProvider.select((s) => s.cursorBlink), (
      _,
      blink,
    ) {
      session.terminal.setCursorBlinkMode(blink);
    });

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
      // The host's preset, or the app's default one. The default is built
      // from the app's ColorScheme, so the terminal follows the theme mode
      // and accent the user chose instead of shipping xterm2's own palette
      // regardless — which on a light theme meant a dark terminal pasted into
      // a light window.
      child: Actions(
        actions: <Type, Action<Intent>>{
          TerminalPasteIntent: CallbackAction<TerminalPasteIntent>(
            onInvoke: (_) {
              pasteClipboardInto(
                context,
                ref,
                session.terminal,
                deliver: _deliverPaste,
              );
              return null;
            },
          ),
          FindInTerminalIntent: CallbackAction<FindInTerminalIntent>(
            onInvoke: (_) {
              _openFind();
              return null;
            },
          ),
          OpenSnippetsIntent: CallbackAction<OpenSnippetsIntent>(
            onInvoke: (_) {
              openSnippetPicker(context, ref, sessionId: session.id);
              return null;
            },
          ),
          // Answered here as well as app-wide, so it works on a phone's
          // terminal page too, which is not under the shell's shortcuts.
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) {
              openCommandPalette(context, ref);
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
            autofocus: widget.autofocus,
            backgroundOpacity: 1,
            padding: const EdgeInsets.all(Spacing.xs),
            theme: preset.toTerminalTheme(Theme.of(context).colorScheme),
            textStyle: font.style(fontSize),
            // What a program asks for with DECSCUSR still wins; this is the
            // shape it returns to.
            cursorType: cursorShape.cursorType,
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
          if (!session.isLive) PaneStatusBar(session: session),
          // Offers to install tmux where it was wanted and is missing.
          TmuxInstallBanner(session: session),
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
                copyLabel: l10n.terminalCopy.toLowerCase(),
                pasteLabel: l10n.terminalPaste.toLowerCase(),
                onCopy: () => unawaited(_copySelection(context, session)),
                onPaste: () => pasteClipboardInto(
                  context,
                  ref,
                  session.terminal,
                  deliver: _deliverPaste,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
