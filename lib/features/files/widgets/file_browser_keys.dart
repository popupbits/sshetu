import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

/// The file browser's keyboard shortcuts, and the focus that makes them fire.
///
/// F2 renames the one selected entry, the key every desktop file manager uses
/// for it. A shortcut only fires when focus is inside it, and in a desktop
/// workspace tab focus usually was not: rows are not focusable, so clicking
/// one left focus wherever it had been — most often on the route's own scope,
/// above this widget — and `autofocus` only applies when nothing else in the
/// scope has had focus. F2 did nothing at all.
///
/// So this takes focus itself, in two moments:
///
/// - **a click anywhere in the browser** — checked on the pointer's down and
///   again on its up — unless focus is already inside it. The guard is what
///   keeps it off text fields: clicking into the path bar lands focus there
///   as usual (the field takes it on the tap, after this has looked), and F2
///   still fires from the field, because this sits above it and a text field
///   has no use for F2. The second look is for a click on a row while typing:
///   on a desktop the field drops its focus to the route's scope on the
///   pointer down, after this has seen it — without the look on the up, focus
///   would land outside the browser again.
/// - **becoming visible** — first built, or its workspace tab selected again.
///   A hidden tab has its tickers off (see `TerminalWorkspace`), and that is
///   the signal read here.
///
/// A dialog opened from here (rename itself) is its own route, so its field
/// is not under these shortcuts and F2 there does nothing.
class FileBrowserKeys extends StatefulWidget {
  const FileBrowserKeys({
    required this.onRename,
    required this.child,
    super.key,
  });

  final VoidCallback onRename;
  final Widget child;

  @override
  State<FileBrowserKeys> createState() => _FileBrowserKeysState();
}

class _FileBrowserKeysState extends State<FileBrowserKeys> {
  final _focus = FocusNode(debugLabel: 'file-browser');
  var _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) _claimFocusAfterFrame();
    _visible = visible;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// After the frame: a tab being uncovered cannot take focus until the
  /// frame that stops excluding it has been built.
  void _claimFocusAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_visible) return;
      _claimFocus();
    });
  }

  void _claimFocus() {
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _claimFocus(),
    onPointerUp: (_) => _claimFocus(),
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.f2): widget.onRename},
      child: Focus(focusNode: _focus, child: widget.child),
    ),
  );
}
