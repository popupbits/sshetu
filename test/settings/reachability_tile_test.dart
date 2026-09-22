import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/domain/reachability.dart';
import 'package:sshetu/features/hosts/reachability_controller.dart';
import 'package:sshetu/features/settings/widgets/reachability_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The reachability interval: its default per platform, and where it persists.
void main() {
  late ProviderContainer container;
  late SharedPreferences preferences;

  Future<void> setUpWith(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
  }

  test('unset follows the platform default', () async {
    await setUpWith({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      container.read(effectiveReachabilityIntervalProvider),
      ReachabilityInterval.minutes5,
    );
  });

  test('a stored choice wins over the default', () async {
    await setUpWith({'settings.reachabilityInterval': 'off'});
    expect(
      container.read(effectiveReachabilityIntervalProvider),
      ReachabilityInterval.off,
    );
  });

  test('a corrupt stored value falls back to the default', () async {
    await setUpWith({'settings.reachabilityInterval': '5s'});
    expect(container.read(reachabilityIntervalSettingProvider), isNull);
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('picks and persists at ${width.toInt()}px wide', (
      tester,
    ) async {
      await setUpWith({});
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
            home: Scaffold(body: ReachabilityTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check whether hosts are reachable'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('30 s'));
      await tester.pumpAndSettle();
      expect(
        container.read(effectiveReachabilityIntervalProvider),
        ReachabilityInterval.seconds30,
      );
      expect(preferences.getString('settings.reachabilityInterval'), '30s');

      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(preferences.getString('settings.reachabilityInterval'), 'off');
    });
  }
}
