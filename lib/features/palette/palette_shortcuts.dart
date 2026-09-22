import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Open the command palette.
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// **Cmd+K** or **Cmd+Shift+P** on macOS; **Ctrl+Shift+P** everywhere else,
/// and **Ctrl+K** too while the keyboard is not in a terminal.
///
/// Ctrl+K is readline's kill-line (and nano's cut, and Emacs's kill-line):
/// a terminal user presses it constantly, and a palette that popped up
/// instead would destroy exactly the keystroke they meant. So on Windows and
/// Linux Ctrl+K is bound only at the app level — a focused terminal answers
/// every Ctrl chord itself before its ancestors are asked (see
/// `TerminalPane`), so there the byte reaches the shell untouched, and from
/// the host list, a form or anywhere else it opens the palette.
///
/// Ctrl+Shift+P is the chord that works from everywhere, including inside a
/// terminal, where it is installed in the terminal's own shortcut map the way
/// find and snippets are. It is VS Code's, so it is already in the hands of
/// most people who would look for a palette; and a shifted Ctrl chord sends
/// the same byte as the unshifted one (0x10, previous-history), which the
/// shell still has on plain Ctrl+P. xterm2 binds nothing to it.
///
/// On macOS neither costs the shell anything: Command never reaches it.
/// Cmd+K is the modern palette chord (Slack, Linear, Raycast); Cmd+Shift+P is
/// kept for people coming from VS Code. Terminal.app's "Clear to Start" also
/// lives on Cmd+K, but this app has no such command, so nothing is displaced.
List<SingleActivator> commandPaletteActivators() => _isMac
    ? const [
        SingleActivator(LogicalKeyboardKey.keyK, meta: true),
        SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true),
      ]
    : const [
        SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true),
        SingleActivator(LogicalKeyboardKey.keyK, control: true),
      ];

/// The subset of [commandPaletteActivators] that is safe to claim while a
/// terminal has focus — installed in the terminal's own shortcut map.
///
/// Everything on macOS; on Windows and Linux only the shifted chord, because
/// plain Ctrl+K belongs to the shell.
List<SingleActivator> terminalCommandPaletteActivators() => _isMac
    ? commandPaletteActivators()
    : const [
        SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true),
      ];

/// The chord a menu shows for the palette: the one that works everywhere.
SingleActivator commandPaletteMenuActivator() =>
    terminalCommandPaletteActivators().first;
