import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/sessions/session_shortcuts.dart';

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

  group('the find shortcut', () {
    SingleActivator findOn(TargetPlatform platform) =>
        activatorFor(shortcutsFor(platform), (i) => i is FindInTerminalIntent)!
            as SingleActivator;

    test('is Command+F on macOS', () {
      final activator = findOn(TargetPlatform.macOS);
      expect(activator.trigger, LogicalKeyboardKey.keyF);
      expect(activator.meta, isTrue);
      expect(activator.control, isFalse);
      expect(activator.shift, isFalse);
    });

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      test('is Control+Shift+F on $platform, leaving Ctrl+F to the shell', () {
        final activator = findOn(platform);
        expect(activator.trigger, LogicalKeyboardKey.keyF);
        expect(activator.control, isTrue);
        expect(activator.shift, isTrue, reason: 'Ctrl+F is forward-char');
        expect(activator.meta, isFalse);
      });
    }

    test('matches the activator the menu and the terminal use', () {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
        debugDefaultTargetPlatformOverride = platform;
        final shared = findInTerminalActivator();
        debugDefaultTargetPlatformOverride = null;
        final installed = findOn(platform);
        expect(shared.trigger, installed.trigger);
        expect(shared.control, installed.control);
        expect(shared.meta, installed.meta);
        expect(shared.shift, installed.shift);
      }
    });
  });

  group('the terminal zoom shortcuts', () {
    Iterable<TerminalFontSizeIntent> zoomOn(TargetPlatform platform) =>
        shortcutsFor(platform).values.whereType<TerminalFontSizeIntent>();

    Iterable<SingleActivator> activatorsFor(
      TargetPlatform platform,
      double delta,
    ) => shortcutsFor(platform).entries
        .where((e) {
          final intent = e.value;
          return intent is TerminalFontSizeIntent && intent.delta == delta;
        })
        .map((e) => e.key as SingleActivator);

    test('bind a step each way and a reset', () {
      expect(zoomOn(TargetPlatform.windows).map((i) => i.delta).toSet(), {
        1.0,
        -1.0,
        0.0,
      });
    });

    test('reset sits on digit 0, which no tab claims', () {
      final shortcuts = shortcutsFor(TargetPlatform.windows);
      expect(
        activatorsFor(TargetPlatform.windows, 0).single.trigger,
        LogicalKeyboardKey.digit0,
      );
      expect(
        shortcuts.values.whereType<SelectSessionIntent>().map(
          (i) => i.position,
        ),
        isNot(contains(0)),
        reason: 'digits 1-9 pick a tab; 0 is free for this',
      );
    });

    test('`+` is bound as well as `=`, being a shifted `=`', () {
      final increase = activatorsFor(TargetPlatform.windows, 1);
      expect(
        increase.any((a) => a.trigger == LogicalKeyboardKey.equal && !a.shift),
        isTrue,
      );
      expect(
        increase.any((a) => a.trigger == LogicalKeyboardKey.equal && a.shift),
        isTrue,
        reason: 'binding only `=` reads as "the shortcut does not work"',
      );
    });
  });
}
