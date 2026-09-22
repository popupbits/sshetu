import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/settings/widgets/launch_tunnels_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  for (final (name, size) in const [
    ('360', Size(360, 740)),
    ('1280', Size(1280, 800)),
  ]) {
    testWidgets('at $name: off by default, a tap turns it on and saves it', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: ListView(children: const [LaunchTunnelsTile()]),
            ),
          ),
        ),
      );

      expect(
        find.text('Start auto-start tunnels when SSHetu opens'),
        findsOneWidget,
      );
      final tile = find.byKey(const Key('settings.startTunnelsAtLaunch'));
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect(preferences.getBool('settings.startTunnelsAtLaunch'), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
