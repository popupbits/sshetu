import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_navigator/features/sessions/session_shortcuts.dart';

/// The tab shortcuts have to use the *platform's* modifier: Command on macOS,
/// Control on Windows and Linux. A hard-coded `meta` is wrong everywhere but
/// macOS and a hard-coded `control` wrong on it, and either way the app feels
/// foreign on three of its four desktop targets.
void main() {
  ShortcutActivator? activatorFor(
    Map<ShortcutActivator, Intent> shortcuts,
    bool Function(Intent) matches,
  ) {
    for (final entry in shortcuts.entries) {
      if (matches(entry.value)) return entry.key;
    }
    return null;
  }

  /// Builds the shortcut map the widget installs, for [platform].
  Map<ShortcutActivator, Intent> shortcutsFor(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final map = SessionShortcuts.shortcutMap();
    debugDefaultTargetPlatformOverride = null;
    return map;
  }

  SingleActivator closeOn(TargetPlatform platform) =>
      activatorFor(shortcutsFor(platform), (i) => i is CloseSessionIntent)!
          as SingleActivator;

  group('the close shortcut', () {
    test('is Command+W on macOS', () {
      final activator = closeOn(TargetPlatform.macOS);
      expect(activator.trigger, LogicalKeyboardKey.keyW);
      expect(activator.meta, isTrue);
      expect(activator.control, isFalse);
    });

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      test('is Control+W on $platform', () {
        final activator = closeOn(platform);
        expect(activator.trigger, LogicalKeyboardKey.keyW);
        expect(activator.control, isTrue);
        expect(
          activator.meta,
          isFalse,
          reason: 'Command is not a key these platforms have',
        );
      });
    }
  });

  group('the tab shortcuts', () {
    test('cover next and previous, both ways round', () {
      final shortcuts = shortcutsFor(TargetPlatform.macOS);
      final forward = shortcuts.entries
          .where((e) => e.value is CycleSessionIntent)
          .where((e) => (e.value as CycleSessionIntent).delta > 0)
          .map((e) => (e.key as SingleActivator).trigger)
          .toSet();
      final back = shortcuts.entries
          .where((e) => e.value is CycleSessionIntent)
          .where((e) => (e.value as CycleSessionIntent).delta < 0)
          .map((e) => (e.key as SingleActivator).trigger)
          .toSet();

      // Both spellings, because both are muscle memory.
      expect(forward, contains(LogicalKeyboardKey.bracketRight));
      expect(forward, contains(LogicalKeyboardKey.tab));
      expect(back, contains(LogicalKeyboardKey.bracketLeft));
      expect(back, contains(LogicalKeyboardKey.tab));
    });

    test('Ctrl+Tab stays Ctrl+Tab on macOS', () {
      // The one shortcut that is Control everywhere: Cmd+Tab belongs to the
      // window manager and is not ours to take.
      final shortcuts = shortcutsFor(TargetPlatform.macOS);
      final tabForward = shortcuts.entries.firstWhere(
        (e) =>
            e.key is SingleActivator &&
            (e.key as SingleActivator).trigger == LogicalKeyboardKey.tab &&
            !(e.key as SingleActivator).shift,
      );
      expect((tabForward.key as SingleActivator).control, isTrue);
      expect((tabForward.key as SingleActivator).meta, isFalse);
    });

    test('digits 1 to 9 select a tab by position', () {
      final shortcuts = shortcutsFor(TargetPlatform.macOS);
      final positions =
          shortcuts.values
              .whereType<SelectSessionIntent>()
              .map((i) => i.position)
              .toList()
            ..sort();

      expect(positions, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    test('every activator uses the platform modifier except Ctrl+Tab', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        final usesMeta = platform == TargetPlatform.macOS;
        for (final entry in shortcutsFor(platform).entries) {
          final activator = entry.key as SingleActivator;
          if (activator.trigger == LogicalKeyboardKey.tab) continue;
          expect(
            activator.meta,
            usesMeta,
            reason: '${activator.trigger.keyLabel} on $platform',
          );
          expect(activator.control, !usesMeta);
        }
      }
    });
  });
}
