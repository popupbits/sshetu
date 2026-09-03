import 'package:material_ui/material_ui.dart';
import 'package:xterm2/xterm.dart';

import '../../../core/terminal/terminal_modifiers.dart';
import '../../../core/theme/tokens.dart';

/// One key on the bar.
///
/// Carries a [TerminalKey] wherever the terminal has one, rather than a
/// hard-coded escape sequence. The sequence for a key is not fixed: an arrow
/// is `ESC [ A` normally and `ESC O A` in application cursor keys mode, which
/// is the mode vim and less put the terminal into — so a bar that sent the
/// literal bytes worked at the shell and moved the cursor to the wrong place
/// in an editor. Going through [Terminal.keyInput] means the terminal decides,
/// with everything it knows about its own modes.
class _Key {
  const _Key(this.label, {this.key, this.text});

  final String label;

  /// The key pressed, if the terminal has one for it.
  final TerminalKey? key;

  /// The literal character, for keys that are just awkward to reach.
  final String? text;
}

/// The row of keys above a phone keyboard that makes a terminal usable.
///
/// A software keyboard has no Ctrl, no Esc, no Tab and no arrows, which means
/// that without this bar the app cannot interrupt a command, exit vim,
/// complete a path or recall history — that is to say, it cannot be used. This
/// is not a convenience; it is the difference between a working SSH client on
/// a phone and a demo.
///
/// Ctrl and Alt are **sticky**: tap Ctrl, then C. Holding two keys at once on
/// a touch screen is not something anyone can do, so a chord has to become a
/// sequence. They release after one key, the way a shift-once behaves, because
/// a modifier that stays down silently is a modifier that eats the next thing
/// you type.
///
/// The latch itself is [TerminalModifiers], owned by the session, because the
/// key it modifies is usually typed on the *software keyboard* rather than on
/// this bar — and that keystroke never passes through here.
class TerminalKeyBar extends StatelessWidget {
  const TerminalKeyBar({
    required this.terminal,
    required this.modifiers,
    super.key,
  });

  /// Where the bar's own keys go. Sent as key events rather than written to
  /// the session directly, so they pick up the latch and the terminal's modes
  /// exactly as a typed key does.
  final Terminal terminal;

  final TerminalModifiers modifiers;

  static const _keys = <_Key>[
    _Key('esc', key: TerminalKey.escape),
    _Key('tab', key: TerminalKey.tab),
    _Key('/', text: '/'),
    _Key('-', text: '-'),
    _Key('|', text: '|'),
    _Key('~', text: '~'),
    _Key('↑', key: TerminalKey.arrowUp),
    _Key('↓', key: TerminalKey.arrowDown),
    _Key('←', key: TerminalKey.arrowLeft),
    _Key('→', key: TerminalKey.arrowRight),
    _Key('home', key: TerminalKey.home),
    _Key('end', key: TerminalKey.end),
    _Key('pgup', key: TerminalKey.pageUp),
    _Key('pgdn', key: TerminalKey.pageDown),
  ];

  /// Presses [key] on the terminal, exactly as the keyboard would.
  ///
  /// Nothing here translates a modifier: the latch is read by the terminal's
  /// own input handler, so Ctrl-C from this bar and Ctrl-C from a hardware
  /// keyboard produce the same bytes by running the same code.
  void _press(_Key key) {
    final consumed = terminal.keyInput(
      key.key ?? TerminalKey.none,
      text: key.text,
    );
    // The same fallback the terminal view uses for a key it has no mapping
    // for: send the character itself.
    if (!consumed && key.text != null) terminal.textInput(key.text!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          // Rebuilt from the latch, so a modifier lights up whether it was
          // latched here or released by a key typed on the keyboard.
          child: ListenableBuilder(
            listenable: modifiers,
            builder: (context, _) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              children: [
                _ModifierChip(
                  label: 'ctrl',
                  active: modifiers.ctrl,
                  onTap: modifiers.toggleCtrl,
                ),
                _ModifierChip(
                  label: 'alt',
                  active: modifiers.alt,
                  onTap: modifiers.toggleAlt,
                ),
                for (final key in _keys)
                  _KeyChip(label: key.label, onTap: () => _press(key)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xxs,
        vertical: Spacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.xs),
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
      ),
    );
  }
}

class _ModifierChip extends StatelessWidget {
  const _ModifierChip({
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xxs,
        vertical: Spacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.xs),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          decoration: BoxDecoration(
            // A sticky modifier has to look held, or the next keystroke is a
            // surprise. Colour, not a border: it must read at a glance from
            // the corner of the eye while the user is looking at the output.
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: active ? theme.colorScheme.onPrimary : null,
              fontWeight: active ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}
