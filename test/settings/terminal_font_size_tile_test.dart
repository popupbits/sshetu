import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/settings/widgets/terminal_font_size_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The row that makes the grid readable without a keyboard, which is how most
/// people will find the setting at all.
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

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: TerminalFontSizeTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double size() => container.read(settingsControllerProvider).terminalFontSize;

  for (final width in [390.0, 1400.0]) {
    testWidgets('shows the current size at ${width.toInt()}px wide', (
      tester,
    ) async {
      await pump(tester, Size(width, 900));
      expect(find.text('13 pt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the buttons step the size', (tester) async {
    await pump(tester, const Size(1400, 900));

    await tester.tap(find.byTooltip('Larger'));
    await tester.pumpAndSettle();
    expect(size(), AppSettings.defaultTerminalFontSize + 1);
    expect(find.text('14 pt'), findsOneWidget);

    await tester.tap(find.byTooltip('Smaller'));
    await tester.pumpAndSettle();
    expect(size(), AppSettings.defaultTerminalFontSize);
  });

  testWidgets('the buttons disable at the limits', (tester) async {
    container
        .read(settingsControllerProvider.notifier)
        .setTerminalFontSize(AppSettings.maxTerminalFontSize);
    await pump(tester, const Size(1400, 900));

    IconButton buttonFor(String tooltip) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );

    expect(
      buttonFor('Larger').onPressed,
      isNull,
      reason: 'already at the maximum',
    );
    expect(buttonFor('Smaller').onPressed, isNotNull);
  });
}
