import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'session_manager.dart';

/// Close the current session.
class CloseSessionIntent extends Intent {
  const CloseSessionIntent();
}

/// Move to the next or previous session.
class CycleSessionIntent extends Intent {
  const CycleSessionIntent(this.delta);

  /// +1 for the next tab, -1 for the previous.
  final int delta;
}

/// Select the session at a position, 1-based.
class SelectSessionIntent extends Intent {
  const SelectSessionIntent(this.position);

  final int position;
}

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
  static Map<ShortcutActivator, Intent> shortcutMap() =>
      <ShortcutActivator, Intent>{
        _primary(LogicalKeyboardKey.keyW): const CloseSessionIntent(),
        // Both spellings of "next tab", because both are muscle memory:
        // Ctrl/Cmd+Tab and the bracket pair every browser and editor uses.
        _primary(LogicalKeyboardKey.bracketRight): const CycleSessionIntent(1),
        _primary(LogicalKeyboardKey.bracketLeft): const CycleSessionIntent(-1),
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            const CycleSessionIntent(1),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): const CycleSessionIntent(
          -1,
        ),
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
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: shortcutMap(),
      child: Actions(
        actions: <Type, Action<Intent>>{
          CloseSessionIntent: CallbackAction<CloseSessionIntent>(
            onInvoke: (_) {
              final manager = ref.read(sessionManagerProvider.notifier);
              final id = manager.activeId;
              if (id != null) manager.close(id);
              return null;
            },
          ),
          CycleSessionIntent: CallbackAction<CycleSessionIntent>(
            onInvoke: (intent) {
              final manager = ref.read(sessionManagerProvider.notifier);
              final sessions = ref.read(sessionManagerProvider);
              if (sessions.length < 2) return null;
              final current = sessions.indexWhere(
                (s) => s.id == manager.activeId,
              );
              if (current < 0) return null;
              // Wraps, the way every tabbed application does: past the last
              // tab is the first one, not a dead end.
              final next =
                  (current + intent.delta + sessions.length) % sessions.length;
              manager.select(sessions[next].id);
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
