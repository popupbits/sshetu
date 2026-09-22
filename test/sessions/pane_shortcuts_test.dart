import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/sessions/pane_commands.dart';
import 'package:sshetu/features/sessions/session_shortcuts.dart';
import 'package:xterm2/xterm.dart';

/// The split-pane chords must not take a key anything else already answers —
/// a tab shortcut, find, snippets, the terminal's own copy and paste — and
/// must never be a plain Ctrl letter, which belongs to the shell.
void main() {
  /// A chord as a comparable value. `SingleActivator` has no `==` of its own,
  /// so two maps can hold the same chord under two keys without complaint.
  String signature(ShortcutActivator activator) {
    final a = activator as SingleActivator;
    return [
      a.trigger.keyId,
      if (a.control) 'ctrl',
      if (a.shift) 'shift',
      if (a.alt) 'alt',
      if (a.meta) 'meta',
    ].join('+');
  }

  T on<T>(TargetPlatform platform, T Function() read) {
    debugDefaultTargetPlatformOverride = platform;
    try {
      return read();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    group('on ${platform.name}', () {
      test('every pane command has its own chord', () {
        final chords = on(
          platform,
          () => [
            for (final command in PaneCommand.values)
              signature(paneActivator(command)),
          ],
        );
        expect(chords.toSet(), hasLength(PaneCommand.values.length));
      });

      test('no pane chord collides with an existing binding', () {
        final (pane, app, terminal) = on(platform, () {
          final pane = {
            for (final command in PaneCommand.values)
              signature(paneActivator(command)),
          };
          final app = {
            for (final entry in SessionShortcuts.shortcutMap().entries)
              if (entry.value is! PaneCommandIntent) signature(entry.key),
          };
          final terminal = {
            for (final key in defaultTerminalShortcuts.keys) signature(key),
          };
          return (pane, app, terminal);
        });
        expect(pane.intersection(app), isEmpty);
        expect(pane.intersection(terminal), isEmpty);
        // The menu bar's own chords (New Host, Save Backup, Settings).
        final mac = platform == TargetPlatform.macOS;
        final menu = {
          for (final key in [
            LogicalKeyboardKey.keyN,
            LogicalKeyboardKey.keyS,
            LogicalKeyboardKey.comma,
          ])
            signature(SingleActivator(key, meta: mac, control: !mac)),
        };
        expect(pane.intersection(menu), isEmpty);
      });

      test('the existing bindings are all still installed', () {
        final map = on(platform, SessionShortcuts.shortcutMap);
        expect(map.values.whereType<SelectSessionIntent>(), hasLength(9));
        expect(map.values.whereType<FindInTerminalIntent>(), hasLength(1));
        expect(map.values.whereType<OpenSnippetsIntent>(), hasLength(1));
        expect(map.values.whereType<CloseSessionIntent>(), hasLength(1));
        expect(
          map.values.whereType<PaneCommandIntent>().map((i) => i.command),
          unorderedEquals(PaneCommand.values),
        );
      });
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('on ${platform.name} every pane chord is shifted Ctrl', () {
      for (final command in PaneCommand.values) {
        final chord = on(platform, () => paneActivator(command));
        expect(chord.control, isTrue, reason: '$command');
        expect(
          chord.shift,
          isTrue,
          reason: '$command: a plain Ctrl chord has to reach the shell',
        );
        expect(chord.meta, isFalse, reason: '$command');
      }
    });
  }

  test('on macOS every pane chord uses Command', () {
    for (final command in PaneCommand.values) {
      final chord = on(TargetPlatform.macOS, () => paneActivator(command));
      expect(chord.meta, isTrue, reason: '$command');
      expect(chord.control, isFalse, reason: '$command');
    }
  });
}
