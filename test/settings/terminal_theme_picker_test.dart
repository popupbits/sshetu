import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/theme/terminal_theme_presets.dart';
import 'package:sshetu/features/settings/widgets/cursor_shape_tile.dart';
import 'package:sshetu/features/settings/widgets/scrollback_tile.dart';
import 'package:sshetu/features/settings/widgets/terminal_font_tile.dart';
import 'package:sshetu/features/settings/widgets/terminal_theme_picker.dart';
import 'package:sshetu/features/settings/widgets/terminal_theme_preview.dart';
import 'package:sshetu/features/settings/widgets/terminal_theme_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// Choosing a terminal theme by looking at it, on a phone and on a desktop.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: ListView(children: [child])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String themeId() =>
      container.read(settingsControllerProvider).terminalThemeId;

  testWidgets('on a phone (360 px) it is a sheet, and a tap chooses', (
    tester,
  ) async {
    await pump(tester, const Size(360, 780), const TerminalThemeTile());
    expect(find.text('SSHetu'), findsOneWidget, reason: 'the current one');

    await tester.tap(find.text('Terminal theme'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    // Rendered previews, not a list of names.
    expect(find.byType(TerminalThemePreview), findsWidgets);
    expect(find.text('error: permission denied'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Every preset is reachable.
    for (final preset in TerminalThemePresets.all) {
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(TerminalThemePicker),
          matching: find.text(preset.name),
        ),
        100,
        scrollable: find
            .descendant(
              of: find.byType(TerminalThemePicker),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Monokai').last);
    await tester.pumpAndSettle();

    expect(themeId(), 'monokai');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Monokai'), findsOneWidget, reason: 'the row updated');
  });

  testWidgets('on a desktop (1280 px) it is a dialog with several columns', (
    tester,
  ) async {
    await pump(tester, const Size(1280, 900), const TerminalThemeTile());

    await tester.tap(find.text('Terminal theme'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);

    // More than one column: the first two previews share a row.
    final previews = find.byType(TerminalThemePreview);
    final first = tester.getTopLeft(previews.at(0));
    final second = tester.getTopLeft(previews.at(1));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));

    // The current one is marked, in its own card.
    final check = find.byIcon(PiconsRegular.checkCircle);
    expect(check, findsOneWidget);
    final card = find.ancestor(of: check, matching: find.byType(InkWell));
    expect(
      find.descendant(of: card, matching: find.text('SSHetu')),
      findsOneWidget,
    );

    await tester.tap(find.text('Nord'));
    await tester.pumpAndSettle();
    expect(themeId(), 'nord');
    expect(find.byType(Dialog), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('dismissing it changes nothing', (tester) async {
    await pump(tester, const Size(360, 780), const TerminalThemeTile());
    await tester.tap(find.text('Terminal theme'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(themeId(), 'sshetu');
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('the other terminal rows fit at ${width.toInt()} px', (
      tester,
    ) async {
      await pump(
        tester,
        Size(width, 900),
        const Column(
          children: [TerminalFontTile(), CursorShapeTile(), ScrollbackTile()],
        ),
      );
      expect(find.text('System monospace'), findsOneWidget);
      expect(find.text('10,000 lines · applies to new tabs'), findsOneWidget);
      expect(find.text('Underline'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Bar'));
      await tester.pumpAndSettle();
      expect(container.read(settingsControllerProvider).cursorShape.id, 'bar');

      await tester.tap(find.byTooltip('Scrollback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50,000 lines').last);
      await tester.pumpAndSettle();
      expect(container.read(settingsControllerProvider).scrollbackLines, 50000);

      await tester.tap(find.byTooltip('Terminal font'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fira Code').last);
      await tester.pumpAndSettle();
      expect(
        container.read(settingsControllerProvider).terminalFontId,
        'fira-code',
      );
    });
  }
}
