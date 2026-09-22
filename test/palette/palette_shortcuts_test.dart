import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/palette/palette_registry.dart';
import 'package:sshetu/features/palette/palette_shortcuts.dart';
import 'package:sshetu/features/palette/widgets/command_palette.dart';
import 'package:sshetu/features/sessions/session_shortcuts.dart';
import 'package:sshetu/features/sessions/widgets/terminal_pane.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:xterm2/xterm.dart';

/// The palette's chords, checked against every other chord the app binds.
///
/// Two things can go wrong, and both are silent: a palette chord that equals
/// another shortcut quietly steals it, and a palette chord installed in the
/// terminal takes a byte away from the shell. The second is the reason the
/// palette is not simply Ctrl+K everywhere — Ctrl+K is kill-line.
void main() {
  const desktops = [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  T on<T>(TargetPlatform platform, T Function() body) {
    debugDefaultTargetPlatformOverride = platform;
    try {
      return body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// A chord as comparable data. SingleActivator has no value equality.
  String spell(ShortcutActivator activator) {
    final a = activator as SingleActivator;
    return [
      if (a.control) 'ctrl',
      if (a.meta) 'meta',
      if (a.alt) 'alt',
      if (a.shift) 'shift',
      a.trigger.keyLabel,
    ].join('+');
  }

  bool isPalette(Intent intent) => intent is OpenCommandPaletteIntent;

  /// Everything else the app-wide map binds.
  Set<String> appChords() => {
    for (final entry in SessionShortcuts.shortcutMap().entries)
      if (!isPalette(entry.value)) spell(entry.key),
  };

  /// What a focused terminal binds, apart from the palette: xterm2's own
  /// defaults (copy, paste, select all, scrolling) plus find and snippets.
  Set<String> terminalChords() => {
    for (final activator in defaultTerminalShortcuts.keys) spell(activator),
    spell(findInTerminalActivator()),
    spell(snippetPickerActivator()),
  };

  /// The menu bar's own shortcuts (`AppMenuBar`), which on macOS the system
  /// fires whatever has focus.
  Set<String> menuChords() {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    SingleActivator primary(LogicalKeyboardKey key) =>
        SingleActivator(key, meta: mac, control: !mac);
    return {
      for (final key in [
        LogicalKeyboardKey.keyN,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.bracketRight,
        LogicalKeyboardKey.bracketLeft,
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.equal,
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.comma,
      ])
        spell(primary(key)),
      // And the ones macOS provides: Quit, Hide, Minimise, Full Screen.
      if (mac) ...['meta+Q', 'meta+H', 'meta+M', 'meta+alt+H'],
    };
  }

  group('chord conflicts', () {
    for (final platform in desktops) {
      test('no palette chord is taken by anything else on $platform', () {
        on(platform, () {
          final palette = {
            for (final a in commandPaletteActivators()) spell(a),
          };
          expect(palette, isNotEmpty);
          expect(palette.intersection(appChords()), isEmpty);
          expect(palette.intersection(terminalChords()), isEmpty);
          expect(palette.intersection(menuChords()), isEmpty);
        });
      });

      test('the app-wide map installs every palette chord on $platform', () {
        on(platform, () {
          final installed = {
            for (final entry in SessionShortcuts.shortcutMap().entries)
              if (isPalette(entry.value)) spell(entry.key),
          };
          expect(installed, {
            for (final a in commandPaletteActivators()) spell(a),
          });
        });
      });

      test('the menu shows a chord that works in a terminal on $platform', () {
        on(platform, () {
          expect([
            for (final a in terminalCommandPaletteActivators()) spell(a),
          ], contains(spell(commandPaletteMenuActivator())));
        });
      });
    }

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      test('Ctrl+K is never claimed inside a terminal on $platform', () {
        on(platform, () {
          final inTerminal = {
            for (final a in terminalCommandPaletteActivators()) spell(a),
          };
          expect(inTerminal, isNot(contains('ctrl+K')));
          // Only shifted chords may be taken from a shell: the unshifted
          // byte stays reachable on the plain chord.
          for (final activator in terminalCommandPaletteActivators()) {
            expect(activator.shift, isTrue, reason: spell(activator));
          }
          expect(inTerminal, {'ctrl+shift+P'});
        });
      });

      test('Ctrl+K opens it from outside a terminal on $platform', () {
        on(platform, () {
          expect([
            for (final a in commandPaletteActivators()) spell(a),
          ], contains('ctrl+K'));
        });
      });
    }

    test('macOS uses Command+K and Command+Shift+P', () {
      on(TargetPlatform.macOS, () {
        expect(
          [for (final a in commandPaletteActivators()) spell(a)],
          ['meta+K', 'meta+shift+P'],
        );
        expect(spell(commandPaletteMenuActivator()), 'meta+K');
      });
    });
  });

  group('in a focused terminal on Windows', () {
    /// Bounded, because a terminal's cursor blinks forever and
    /// `pumpAndSettle` would wait for it to stop.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    TerminalSession buildSession() => TerminalSession(
      id: 'tab-1',
      title: 'web-01',
      hostId: 'host',
      connection: SshConnection(
        target: const SshTarget(hostname: 'example.invalid', username: 'me'),
        verifierFactory: (_, _) => throw UnimplementedError(),
      ),
    );

    Future<(TerminalSession, List<String>)> pumpPane(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final session = buildSession();
      final sent = <String>[];
      session.terminal.onOutput = sent.add;

      final source = Provider.family<List<PaletteItem>, AppLocalizations>(
        (ref, l10n) => [
          PaletteItem(
            id: 'action:x',
            title: 'Do the thing',
            category: PaletteCategory.action,
            icon: PiconsRegular.play,
            actions: [
              PaletteAction(
                id: 'go',
                label: 'Go',
                icon: PiconsRegular.play,
                run: (_, _) {},
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            paletteSourcesProvider.overrideWithValue([source]),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: SessionShortcuts(child: TerminalPane(session: session)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'terminal');
      return (session, sent);
    }

    Future<void> chord(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool shift = false,
    }) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
    }

    Future<void> finish(WidgetTester tester, TerminalSession session) async {
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    }

    testWidgets('Ctrl+K reaches the shell as kill-line, not the palette', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final (session, sent) = await pumpPane(tester);
        await chord(tester, LogicalKeyboardKey.keyK);

        expect(find.byType(CommandPalette), findsNothing);
        expect(sent.join(), contains('\x0b'));
        await finish(tester, session);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Ctrl+Shift+P opens it, and Esc hands focus back', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final (session, sent) = await pumpPane(tester);
        await chord(tester, LogicalKeyboardKey.keyP, shift: true);

        expect(find.byType(CommandPalette), findsOneWidget);
        expect(
          sent,
          isEmpty,
          reason: 'the chord must not also reach the shell',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester);

        expect(find.byType(CommandPalette), findsNothing);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'terminal');
        await finish(tester, session);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('choosing an item also hands focus back to the terminal', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final (session, _) = await pumpPane(tester);
        await chord(tester, LogicalKeyboardKey.keyP, shift: true);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester);

        expect(find.byType(CommandPalette), findsNothing);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'terminal');
        await finish(tester, session);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
