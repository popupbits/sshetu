import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/settings/widgets/keep_sessions_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// "Keep sessions running on the server": on by default, and persisted.
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
    expect(readSettings(preferences).keepSessionsOnServer, isTrue);
  });

  test('a stored false is read back', () async {
    SharedPreferences.setMockInitialValues({
      'settings.keepSessionsOnServer': false,
    });
    final stored = await SharedPreferences.getInstance();
    expect(readSettings(stored).keepSessionsOnServer, isFalse);
  });

  test('a value of the wrong type falls back to on', () async {
    SharedPreferences.setMockInitialValues({
      'settings.keepSessionsOnServer': 'yes',
    });
    final stored = await SharedPreferences.getInstance();
    expect(readSettings(stored).keepSessionsOnServer, isTrue);
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
            home: Scaffold(body: KeepSessionsTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keep sessions running on the server'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        container.read(settingsControllerProvider).keepSessionsOnServer,
        isFalse,
      );
      expect(preferences.getBool('settings.keepSessionsOnServer'), isFalse);
    });
  }
}
