import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/app_settings.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/settings/widgets/reopen_tabs_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// "Reopen tabs on launch": Ask on a phone, Always on a desktop, persisted.
void main() {
  test('defaults: Ask on a phone, Always on a desktop', () {
    expect(ReopenTabs.defaultFor(TargetPlatform.android), ReopenTabs.ask);
    expect(ReopenTabs.defaultFor(TargetPlatform.iOS), ReopenTabs.ask);
    for (final desktop in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      expect(ReopenTabs.defaultFor(desktop), ReopenTabs.always);
    }
  });

  test('unset follows the platform; a choice overrides it', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = readSettings(await SharedPreferences.getInstance());
    expect(fresh.reopenTabs, isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(fresh.effectiveReopenTabs, ReopenTabs.ask);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(fresh.effectiveReopenTabs, ReopenTabs.always);
    debugDefaultTargetPlatformOverride = null;

    SharedPreferences.setMockInitialValues({'settings.reopenTabs': 'never'});
    final chosen = readSettings(await SharedPreferences.getInstance());
    expect(chosen.effectiveReopenTabs, ReopenTabs.never);
  });

  test('a stored value this build does not know reads as unset', () async {
    SharedPreferences.setMockInitialValues({
      'settings.reopenTabs': 'sometimes',
    });
    expect(
      readSettings(await SharedPreferences.getInstance()).reopenTabs,
      isNull,
    );
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('chooses and persists at ${width.toInt()}px wide', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
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
            home: Scaffold(body: ReopenTabsTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reopen tabs on launch'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Never'));
      await tester.pumpAndSettle();
      expect(
        container.read(settingsControllerProvider).reopenTabs,
        ReopenTabs.never,
      );
      expect(preferences.getString('settings.reopenTabs'), 'never');
    });
  }
}
