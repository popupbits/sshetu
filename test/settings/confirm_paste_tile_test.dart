import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/settings/widgets/confirm_paste_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The way back after "Don't ask again", and where the setting persists.
void main() {
  late ProviderContainer container;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
  });

  test('is on for a fresh install', () {
    expect(readSettings(preferences).confirmMultilinePaste, isTrue);
  });

  test('a stored false is read back', () async {
    SharedPreferences.setMockInitialValues({
      'settings.confirmMultilinePaste': false,
    });
    final stored = await SharedPreferences.getInstance();
    expect(readSettings(stored).confirmMultilinePaste, isFalse);
  });

  for (final width in [390.0, 1400.0]) {
    testWidgets('toggles and persists at ${width.toInt()}px wide', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
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
            home: Scaffold(body: ConfirmPasteTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirm multi-line paste'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        container.read(settingsControllerProvider).confirmMultilinePaste,
        isFalse,
      );
      expect(preferences.getBool('settings.confirmMultilinePaste'), isFalse);
    });
  }
}
