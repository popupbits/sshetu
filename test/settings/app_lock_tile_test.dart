import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/secrets/device_authenticator.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/settings/widgets/app_lock_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:sshetu/l10n/app_localizations_en.dart';

import '../secrets/fake_device_authenticator.dart';

/// The Settings switch for the credential lock.
void main() {
  final l10n = AppLocalizationsEn();

  late FakeDeviceAuthenticator device;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    device = FakeDeviceAuthenticator();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        deviceAuthenticatorProvider.overrideWithValue(device),
      ],
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
          home: Scaffold(body: AppLockTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  for (final width in [390.0, 1400.0]) {
    testWidgets('starts off, and lays out at ${width.toInt()}px wide', (
      tester,
    ) async {
      await pump(tester, Size(width, 900));
      expect(find.text(l10n.settingsAppLock), findsOneWidget);
      expect(switchValue(tester), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('turns on after the device confirms', (tester) async {
    await pump(tester, const Size(1400, 900));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(device.prompts, [l10n.appLockEnableReason]);
    expect(switchValue(tester), isTrue);
    expect(container.read(settingsControllerProvider).requireUnlock, isTrue);
  });

  testWidgets('stays off, and says why, without a screen lock', (tester) async {
    device.available = false;
    await pump(tester, const Size(390, 900));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isFalse);
    expect(find.text(l10n.settingsAppLockUnavailable), findsOneWidget);
  });

  testWidgets('stays off when the prompt is cancelled', (tester) async {
    device.result = DeviceAuthResult.cancelled;
    await pump(tester, const Size(390, 900));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isFalse);
    expect(find.text(l10n.settingsAppLockCancelled), findsOneWidget);
  });
}
