import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/app.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/terminal/terminal_modifiers.dart';
import 'package:sshetu/features/hosts/host_editor_screen.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/keys/keys_controller.dart';
import 'package:sshetu/features/sessions/widgets/terminal_key_bar.dart';
import 'package:sshetu/features/settings/widgets/language_tile.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:xterm2/xterm.dart';

import 'support/test_database.dart';

/// The Nepali UI, at a phone width and a desktop width, without overflowing.
///
/// Nepali runs longer than English — "Delete" is "मेटाउनुहोस्" — and Flutter
/// lays Devanagari out with the *tall* script geometry, so rows that fit in
/// English can overflow in Nepali. Overflow is reported as an exception during
/// layout, so it can simply be asserted on.
///
/// The test font draws every character as a full-width box, combining vowel
/// signs included, so Devanagari measures wider here than on a device. A pass
/// is therefore conservative.
void main() {
  const widths = {'phone': Size(360, 740), 'desktop': Size(1280, 800)};
  final ne = lookupAppLocalizations(const Locale('ne'));

  void setSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  /// Scrolls every scrollable on screen to its end in steps, checking for an
  /// overflow at each step: a list only builds the rows it shows.
  Future<void> scrollThrough(WidgetTester tester, String where) async {
    final scrollables = find.byType(Scrollable);
    for (var i = 0; i < scrollables.evaluate().length; i++) {
      final scrollable = scrollables.at(i);
      final state = tester.state<ScrollableState>(scrollable);
      if (state.axisDirection != AxisDirection.down) continue;
      for (var step = 0; step < 40; step++) {
        final position = state.position;
        if (position.pixels >= position.maxScrollExtent) break;
        position.jumpTo(
          (position.pixels + 300).clamp(0, position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$where overflowed');
      }
    }
  }

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    setSize(tester, size);
    SharedPreferences.setMockInitialValues({'settings.locale': 'ne'});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // Bootstrap reads settings before the first frame; this is that.
          settingsControllerProvider.overrideWith(
            () => SettingsController(initial: readSettings(preferences)),
          ),
          hostsProvider.overrideWith((ref) => []),
          identitiesProvider.overrideWith((ref) => []),
          tunnelsProvider.overrideWith((ref) => []),
          snippetsProvider.overrideWith((ref) => []),
        ],
        child: const SshetuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final MapEntry(key: name, value: size) in widths.entries) {
    group('in Nepali on a $name', () {
      testWidgets('the empty host list renders without overflowing', (
        tester,
      ) async {
        await pumpApp(tester, size);
        expect(tester.takeException(), isNull);
        // Really Nepali, really the empty state.
        expect(find.text(ne.hostsEmptyTitle), findsOneWidget);
      });

      testWidgets('every destination renders without overflowing', (
        tester,
      ) async {
        await pumpApp(tester, size);
        for (final destination in [
          ne.navSessions,
          ne.navKeys,
          ne.navTunnels,
          ne.navSettings,
        ]) {
          final tab = find.text(destination);
          if (tab.evaluate().isEmpty) continue;
          await tester.tap(tab.first);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$destination overflowed',
          );
        }
      });

      testWidgets('settings renders top to bottom without overflowing', (
        tester,
      ) async {
        await pumpApp(tester, size);
        await tester.tap(find.text(ne.navSettings).first);
        await tester.pumpAndSettle();
        expect(find.text(ne.settingsLanguage), findsOneWidget);
        await scrollThrough(tester, 'Settings');
      });
    });
  }

  testWidgets('the language menu names each language in itself, and switching '
      'takes effect', (tester) async {
    await pumpApp(tester, widths['phone']!);
    await tester.tap(find.text(ne.navSettings).first);
    await tester.pumpAndSettle();

    final tile = find.byType(LanguageTile);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    // The subtitle names the pinned language.
    expect(
      find.descendant(of: tile, matching: find.text('नेपाली')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.arrow_drop_down)),
    );
    await tester.pumpAndSettle();
    // "English" in English even while the app is in Nepali, so someone who
    // switched by mistake can find their way back.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('नेपाली'), findsWidgets);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('the host editor in Nepali', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = await openTestDatabase();
      SharedPreferences.setMockInitialValues({'settings.locale': 'ne'});
      final preferences = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretVaultProvider.overrideWithValue(InMemorySecretVault()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          settingsControllerProvider.overrideWith(
            () => SettingsController(initial: readSettings(preferences)),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async => database.raw.close());

    for (final MapEntry(key: name, value: size) in widths.entries) {
      testWidgets('renders without overflowing on a $name, advanced '
          'sections open', (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('ne'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              home: const HostEditorScreen(),
            ),
          ),
        );
        // Real turns: the providers behind this screen read sqlite, and a
        // real future never completes under the test binding's fake clock.
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(ne.hostEditorNew), findsOneWidget);

        for (final section in [ne.hostEditorOrganise, ne.hostEditorAdvanced]) {
          final header = find.text(section);
          if (header.evaluate().isEmpty) continue;
          await tester.ensureVisible(header.first);
          await tester.pumpAndSettle();
          await tester.tap(header.first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$section overflowed');
        }
        await scrollThrough(tester, 'the host editor');
      });
    }
  });

  group('the terminal key bar in Nepali', () {
    for (final MapEntry(key: name, value: size) in widths.entries) {
      testWidgets('every row fits on a $name', (tester) async {
        setSize(tester, size);
        final terminal = Terminal();
        final modifiers = TerminalModifiers();
        addTearDown(modifiers.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ne'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: SizedBox.expand()),
                  // The labels the terminal pane passes in.
                  TerminalKeyBar(
                    terminal: terminal,
                    modifiers: modifiers,
                    copyLabel: ne.terminalCopy.toLowerCase(),
                    pasteLabel: ne.terminalPaste.toLowerCase(),
                    onCopy: () {},
                    onPaste: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The ⋯ row is the one carrying translated labels.
        await tester.tap(find.text('⋯'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(ne.terminalCopy), findsOneWidget);
        expect(find.text(ne.terminalPaste), findsOneWidget);
      });
    }
  });
}
