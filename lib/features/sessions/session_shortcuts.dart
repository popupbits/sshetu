import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_controller.dart';
import 'session_manager.dart';
import 'terminal_find_request.dart';
import 'workspace_pages.dart';

/// Close whatever tab is showing.
///
/// The workspace has two kinds of tab — terminals and pages — and Cmd-W means
/// "close this one" for both. A page is on top when one is selected, so it
/// goes first; otherwise the active session does.
class CloseSessionIntent extends Intent {
  const CloseSessionIntent();
}

/// Closes the front tab, whichever kind it is. Shared by the shortcut and the
/// menu item so the two cannot mean different things.
void closeCurrentTab(WidgetRef ref) {
  final pages = ref.read(workspacePagesProvider.notifier);
  final page = pages.selected;
  if (page != null) {
    pages.close(page.id);
    return;
  }
  final manager = ref.read(sessionManagerProvider.notifier);
  final id = manager.activeId;
  if (id != null) manager.close(id);
}

/// Move to the next or previous session.
class CycleSessionIntent extends Intent {
  const CycleSessionIntent(this.delta);

  /// +1 for the next tab, -1 for the previous.
  final int delta;
}

/// Applies a font-size step. Shared by the shortcut and the menu item so the
/// two cannot drift into meaning different things.
void applyTerminalFontSize(WidgetRef ref, double delta) {
  final settings = ref.read(settingsControllerProvider.notifier);
  delta == 0
      ? settings.resetTerminalFontSize()
      : settings.adjustTerminalFontSize(delta);
}

/// Grow, shrink, or reset the terminal grid's font size.
class TerminalFontSizeIntent extends Intent {
  const TerminalFontSizeIntent.increase() : delta = 1;
  const TerminalFontSizeIntent.decrease() : delta = -1;

  /// Zero means "back to the default" rather than "step by nothing".
  const TerminalFontSizeIntent.reset() : delta = 0;

  final double delta;
}

/// Select the session at a position, 1-based.
class SelectSessionIntent extends Intent {
  const SelectSessionIntent(this.position);

  final int position;
}

/// Open the find bar on the active terminal.
class FindInTerminalIntent extends Intent {
  const FindInTerminalIntent();
}

/// Cmd+F on macOS; **Ctrl+Shift+F** elsewhere.
///
/// Not Ctrl+F: that is readline's forward-char and the key half of everyone's
/// muscle memory in `less` and Emacs sends to the shell. Every Linux and
/// Windows terminal emulator moves its own find to the shifted chord for the
/// same reason. Command is not a key a shell ever sees, so macOS keeps the
/// plain spelling.
///
/// Also installed in the terminal view's own shortcut map (see
/// `TerminalPane`), because a focused terminal claims every Ctrl chord for
/// the shell before an ancestor's shortcuts are consulted.
SingleActivator findInTerminalActivator() =>
    defaultTargetPlatform == TargetPlatform.macOS
    ? const SingleActivator(LogicalKeyboardKey.keyF, meta: true)
    : const SingleActivator(
        LogicalKeyboardKey.keyF,
        control: true,
        shift: true,
      );

/// Wraps the app in the tab shortcuts every desktop application has.
///
/// **The modifier is the platform's, not a guess.** `LogicalKeySet` with a hard
/// coded `meta` would be wrong everywhere except macOS, and a hard coded
/// `control` wrong on macOS — so the primary modifier is chosen from the target
/// platform: Command on macOS, Control on Windows and Linux. `SingleActivator`
/// does not offer a "platform primary" flag, so it is spelled out here once.
///
/// A terminal is the awkward case for shortcuts, because Ctrl is *also* how you
/// talk to the remote shell. On Windows and Linux, Ctrl+W is genuinely
/// ambiguous — but it is not a control sequence any shell binds by default
/// (Ctrl+W is readline's delete-word, which the terminal receives as 0x17 only
/// when the terminal has focus and nothing above it claimed the key). Flutter
/// gives the shortcut priority, which matches every terminal emulator on those
/// platforms: they all take Ctrl+Shift+W or Ctrl+W for the tab and leave the
/// rest to the shell.
class SessionShortcuts extends ConsumerWidget {
  const SessionShortcuts({required this.child, super.key});

  final Widget child;

  /// Command on macOS, Control elsewhere.
  static bool get _usesMeta => defaultTargetPlatform == TargetPlatform.macOS;

  static SingleActivator _primary(
    LogicalKeyboardKey key, {
    bool shift = false,
  }) =>
      SingleActivator(key, meta: _usesMeta, control: !_usesMeta, shift: shift);

  /// The bindings this widget installs.
  ///
  /// Exposed so a test can assert the modifier per platform without pumping a
  /// widget tree and synthesising key events — the thing worth checking is the
  /// map, and building it is the part that can be wrong.
  @visibleForTesting
  static Map<ShortcutActivator, Intent>
  shortcutMap() => <ShortcutActivator, Intent>{
    _primary(LogicalKeyboardKey.keyW): const CloseSessionIntent(),
    // Both spellings of "next tab", because both are muscle memory:
    // Ctrl/Cmd+Tab and the bracket pair every browser and editor uses.
    _primary(LogicalKeyboardKey.bracketRight): const CycleSessionIntent(1),
    _primary(LogicalKeyboardKey.bracketLeft): const CycleSessionIntent(-1),
    const SingleActivator(LogicalKeyboardKey.tab, control: true):
        const CycleSessionIntent(1),
    const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
        const CycleSessionIntent(-1),
    // Page Up/Down with the primary modifier: what every browser on
    // Windows and Linux uses, and the binding people who live in tabs
    // reach for first.
    _primary(LogicalKeyboardKey.pageDown): const CycleSessionIntent(1),
    _primary(LogicalKeyboardKey.pageUp): const CycleSessionIntent(-1),
    // And the shifted brackets, which is the same gesture in Safari and
    // Chrome on macOS. Costing nothing to support, and the alternative is
    // a user concluding the app has no tab shortcuts at all because the
    // one spelling they tried was not the one implemented.
    _primary(LogicalKeyboardKey.bracketRight, shift: true):
        const CycleSessionIntent(1),
    _primary(LogicalKeyboardKey.bracketLeft, shift: true):
        const CycleSessionIntent(-1),
    for (var i = 1; i <= 9; i++)
      _primary(_digits[i - 1]): SelectSessionIntent(i),
    // Zoom, in every spelling a browser accepts. `+` is a shifted `=` on
    // most layouts, and a keypad has its own pair, so binding only `=`
    // reads as "the shortcut does not work".
    _primary(LogicalKeyboardKey.equal): const TerminalFontSizeIntent.increase(),
    _primary(LogicalKeyboardKey.equal, shift: true):
        const TerminalFontSizeIntent.increase(),
    _primary(LogicalKeyboardKey.numpadAdd):
        const TerminalFontSizeIntent.increase(),
    _primary(LogicalKeyboardKey.minus): const TerminalFontSizeIntent.decrease(),
    _primary(LogicalKeyboardKey.numpadSubtract):
        const TerminalFontSizeIntent.decrease(),
    // Digit 0 is free: 1-9 pick a tab, and no tenth tab wants it.
    _primary(LogicalKeyboardKey.digit0): const TerminalFontSizeIntent.reset(),
    findInTerminalActivator(): const FindInTerminalIntent(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: shortcutMap(),
      child: Actions(
        actions: <Type, Action<Intent>>{
          CloseSessionIntent: CallbackAction<CloseSessionIntent>(
            onInvoke: (_) {
              closeCurrentTab(ref);
              return null;
            },
          ),
          CycleSessionIntent: CallbackAction<CycleSessionIntent>(
            onInvoke: (intent) {
              // The menu bar calls the same method, so a shortcut and its
              // menu item cannot drift apart.
              ref.read(sessionManagerProvider.notifier).cycle(intent.delta);
              return null;
            },
          ),
          TerminalFontSizeIntent: CallbackAction<TerminalFontSizeIntent>(
            onInvoke: (intent) {
              applyTerminalFontSize(ref, intent.delta);
              return null;
            },
          ),
          FindInTerminalIntent: CallbackAction<FindInTerminalIntent>(
            onInvoke: (_) {
              openTerminalFind(ref);
              return null;
            },
          ),
          SelectSessionIntent: CallbackAction<SelectSessionIntent>(
            onInvoke: (intent) {
              final sessions = ref.read(sessionManagerProvider);
              // Out of range does nothing rather than clamping: Cmd-9 with two
              // tabs open should not silently mean "the second one".
              if (intent.position > sessions.length) return null;
              ref
                  .read(sessionManagerProvider.notifier)
                  .select(sessions[intent.position - 1].id);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
}
