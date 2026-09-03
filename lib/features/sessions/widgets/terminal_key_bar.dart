import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';

/// One key on the bar.
class _Key {
  const _Key(this.label, this.data);

  final String label;

  /// What to send.
  final String data;
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
class TerminalKeyBar extends StatefulWidget {
  const TerminalKeyBar({required this.onSend, super.key});

  /// Receives the bytes to write to the session.
  final void Function(String data) onSend;

  @override
  State<TerminalKeyBar> createState() => _TerminalKeyBarState();
}

class _TerminalKeyBarState extends State<TerminalKeyBar> {
  var _ctrl = false;
  var _alt = false;

  static const _keys = <_Key>[
    _Key('esc', '\x1b'),
    _Key('tab', '\t'),
    _Key('/', '/'),
    _Key('-', '-'),
    _Key('|', '|'),
    _Key('~', '~'),
    _Key('↑', '\x1b[A'),
    _Key('↓', '\x1b[B'),
    _Key('←', '\x1b[D'),
    _Key('→', '\x1b[C'),
    _Key('home', '\x1b[H'),
    _Key('end', '\x1b[F'),
    _Key('pgup', '\x1b[5~'),
    _Key('pgdn', '\x1b[6~'),
  ];

  void _send(String data) {
    var payload = data;

    if (_ctrl && payload.length == 1) {
      final code = payload.toUpperCase().codeUnitAt(0);
      // The control character for a letter is its position in the alphabet:
      // Ctrl-A is 0x01, Ctrl-C is 0x03. `@` through `_` covers the punctuation
      // that also has a control code, so Ctrl-[ correctly becomes Escape.
      if (code >= 0x40 && code <= 0x5F) {
        payload = String.fromCharCode(code - 0x40);
      }
    }
    // Alt is transmitted as ESC followed by the key — the "meta sends escape"
    // convention every shell and editor expects.
    if (_alt) payload = '\x1b$payload';

    widget.onSend(payload);

    if (_ctrl || _alt) {
      setState(() {
        _ctrl = false;
        _alt = false;
      });
    }
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
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            children: [
              _ModifierChip(
                label: 'ctrl',
                active: _ctrl,
                onTap: () => setState(() => _ctrl = !_ctrl),
              ),
              _ModifierChip(
                label: 'alt',
                active: _alt,
                onTap: () => setState(() => _alt = !_alt),
              ),
              for (final key in _keys)
                _KeyChip(label: key.label, onTap: () => _send(key.data)),
            ],
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
