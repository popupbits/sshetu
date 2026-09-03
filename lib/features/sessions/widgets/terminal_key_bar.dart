import 'package:material_ui/material_ui.dart';
import 'package:xterm2/xterm.dart';

import '../../../core/terminal/terminal_modifiers.dart';
import '../../../core/theme/tokens.dart';

/// One key on the bar: a real [TerminalKey] where the terminal has one, or a
/// literal character where it does not.
///
/// The key rather than a hard-coded escape sequence, because the sequence is
/// not fixed: an arrow is `ESC [ A` normally and `ESC O A` in application
/// cursor keys mode, which is the mode vim and less set. A bar that sent the
/// literal bytes worked at the shell and moved the cursor to the wrong place
/// in an editor. Going through [Terminal.keyInput] lets the terminal decide,
/// with everything it knows about its own modes.
class _Key {
  const _Key(this.label, {this.key, this.text});

  final String label;
  final TerminalKey? key;
  final String? text;
}

/// Which row the bar is showing.
enum _Row { main, symbols, more, function }

/// The row of keys above a phone keyboard that makes a terminal usable.
///
/// A software keyboard has no Ctrl, no Esc, no Tab and no arrows, which means
/// that without this bar the app cannot interrupt a command, exit vim,
/// complete a path or recall history — that is to say, it cannot be used. This
/// is not a convenience; it is the difference between a working SSH client on
/// a phone and a demo.
///
/// **Grouped keys open in place**, swapping the strip for a sub-row with a
/// back chevron, rather than opening a popup or menu. Two reasons, and the
/// first is not cosmetic: a popup takes focus, and focus leaving the terminal
/// closes the keyboard this bar is sitting on top of — so the next key you
/// press goes nowhere. The second is that a single scrolling row hides its
/// own contents. The previous version put fourteen keys in one horizontally
/// scrolling strip, and on a phone that meant `←` and `→` were off the right
/// edge: the two keys most needed for editing a command line were the ones
/// you had to go looking for. Every row here fits without scrolling, except
/// the function keys, where twelve of them is inherent.
///
/// Ctrl and Alt are **sticky**: tap Ctrl, then C. Holding two keys at once on
/// a touch screen is not something anyone can do, so a chord has to become a
/// sequence. The latch itself is [TerminalModifiers], owned by the session,
/// because the key it modifies is usually typed on the *software keyboard*
/// and never passes through this bar at all.
class TerminalKeyBar extends StatefulWidget {
  const TerminalKeyBar({
    required this.terminal,
    required this.modifiers,
    super.key,
  });

  /// Where the bar's keys go. Sent as key events rather than written to the
  /// session directly, so they pick up the latch and the terminal's modes
  /// exactly as a typed key does.
  final Terminal terminal;

  final TerminalModifiers modifiers;

  @override
  State<TerminalKeyBar> createState() => _TerminalKeyBarState();
}

class _TerminalKeyBarState extends State<TerminalKeyBar> {
  var _row = _Row.main;

  static const _arrows = [
    _Key('←', key: TerminalKey.arrowLeft),
    _Key('↑', key: TerminalKey.arrowUp),
    _Key('↓', key: TerminalKey.arrowDown),
    _Key('→', key: TerminalKey.arrowRight),
  ];

  /// The characters a phone keyboard buries two layers deep, and a shell
  /// needs constantly.
  static const _symbols = [
    _Key('/', text: '/'),
    _Key('-', text: '-'),
    _Key('|', text: '|'),
    _Key('~', text: '~'),
    _Key(r'\', text: r'\'),
    _Key(r'$', text: r'$'),
    _Key('*', text: '*'),
    _Key('&', text: '&'),
  ];

  static const _more = [
    _Key('home', key: TerminalKey.home),
    _Key('end', key: TerminalKey.end),
    _Key('pgup', key: TerminalKey.pageUp),
    _Key('pgdn', key: TerminalKey.pageDown),
    _Key('ins', key: TerminalKey.insert),
    _Key('del', key: TerminalKey.delete),
  ];

  static const _function = [
    _Key('F1', key: TerminalKey.f1),
    _Key('F2', key: TerminalKey.f2),
    _Key('F3', key: TerminalKey.f3),
    _Key('F4', key: TerminalKey.f4),
    _Key('F5', key: TerminalKey.f5),
    _Key('F6', key: TerminalKey.f6),
    _Key('F7', key: TerminalKey.f7),
    _Key('F8', key: TerminalKey.f8),
    _Key('F9', key: TerminalKey.f9),
    _Key('F10', key: TerminalKey.f10),
    _Key('F11', key: TerminalKey.f11),
    _Key('F12', key: TerminalKey.f12),
  ];

  /// Presses [key] on the terminal, exactly as the keyboard would.
  ///
  /// Nothing here translates a modifier: the latch is read by the terminal's
  /// own input handler, so Ctrl-C from this bar and Ctrl-C from a hardware
  /// keyboard produce the same bytes by running the same code.
  void _press(_Key key) {
    final consumed = widget.terminal.keyInput(
      key.key ?? TerminalKey.none,
      text: key.text,
    );
    // The same fallback the terminal view uses for a key it has no mapping
    // for: send the character itself.
    if (!consumed && key.text != null) widget.terminal.textInput(key.text!);
  }

  void _show(_Row row) => setState(() => _row = row);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFieldTapRegion(
      // Without this, tapping the bar counts as tapping outside the terminal:
      // the text input is dismissed, and the keyboard the bar is pinned above
      // goes with it.
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        child: Focus(
          // A key on this bar must never become the focused thing. The
          // terminal has to keep focus for the keystroke to arrive at all.
          canRequestFocus: false,
          descendantsAreFocusable: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 44,
                child: ListenableBuilder(
                  listenable: widget.modifiers,
                  builder: (context, _) => _rowFor(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowFor(BuildContext context) => switch (_row) {
    _Row.main => Row(
      children: [
        _Modifier(
          label: 'ctrl',
          active: widget.modifiers.ctrl,
          onTap: widget.modifiers.toggleCtrl,
        ),
        _Modifier(
          label: 'alt',
          active: widget.modifiers.alt,
          onTap: widget.modifiers.toggleAlt,
        ),
        _Cell(label: 'esc', onTap: () => _press(_esc)),
        _Cell(label: 'tab', onTap: () => _press(_tab)),
        for (final key in _arrows)
          _Cell(label: key.label, onTap: () => _press(key)),
        _Cell(label: '#⌄', onTap: () => _show(_Row.symbols)),
        _Cell(label: '⋯', onTap: () => _show(_Row.more)),
      ],
    ),
    _Row.symbols => Row(
      children: [
        _Back(onTap: () => _show(_Row.main)),
        for (final key in _symbols)
          _Cell(label: key.label, onTap: () => _press(key)),
      ],
    ),
    _Row.more => Row(
      children: [
        _Back(onTap: () => _show(_Row.main)),
        for (final key in _more)
          _Cell(label: key.label, onTap: () => _press(key)),
        _Cell(label: 'F1-12', onTap: () => _show(_Row.function)),
      ],
    ),
    // The one row that scrolls, because twelve function keys will not fit on
    // a phone and dropping half of them is worse than a scroll.
    _Row.function => Row(
      children: [
        // Fixed, not flexible: everything else in this row lives inside a
        // scroller that is itself Expanded, and two Expanded siblings split
        // the row evenly — which gave the chevron half the bar.
        SizedBox(
          width: 56,
          child: _Back(onTap: () => _show(_Row.more), flexible: false),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final key in _function)
                SizedBox(
                  width: 52,
                  child: _Cell(
                    label: key.label,
                    onTap: () => _press(key),
                    flexible: false,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  };

  static const _esc = _Key('esc', key: TerminalKey.escape);
  static const _tab = _Key('tab', key: TerminalKey.tab);
}

/// One key. Shares the row's width with its siblings, so a row always fits.
class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.onTap, this.flexible = true});

  final String label;
  final VoidCallback onTap;
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xxs,
        vertical: Spacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.xs),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: theme.textTheme.labelMedium,
          ),
        ),
      ),
    );
    return flexible ? Expanded(child: child) : child;
  }
}

/// Returns to the previous row. Always first, always in the same place.
class _Back extends StatelessWidget {
  const _Back({required this.onTap, this.flexible = true});

  final VoidCallback onTap;

  /// False where the row already has an [Expanded] child of its own.
  final bool flexible;

  @override
  Widget build(BuildContext context) =>
      _Cell(label: '‹', onTap: onTap, flexible: flexible);
}

/// A sticky modifier, which has to look held or the next keystroke is a
/// surprise.
class _Modifier extends StatelessWidget {
  const _Modifier({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xxs,
          vertical: Spacing.xs,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.xs),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Colour, not a border: it has to read at a glance from the
              // corner of the eye while the user is looking at the output.
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                color: active ? theme.colorScheme.onPrimary : null,
                fontWeight: active ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
