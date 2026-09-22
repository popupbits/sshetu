import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/host_editor_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// The host editor in Nepali says everything in Nepali.
///
/// The legacy-algorithms warning was a Dart constant, so a Nepali user met
/// the one paragraph that asks them to accept a real security downgrade in
/// English.
void main() {
  late AppDatabase database;

  setUp(() async => database = await openTestDatabase());
  tearDown(() async => database.raw.close());

  testWidgets('the legacy-algorithms warning is translated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
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

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);

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
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final ne = await AppLocalizations.delegate.load(const Locale('ne'));
    await tester.tap(find.text(ne.hostEditorAdvanced));
    await tester.pumpAndSettle();

    expect(find.text(ne.hostEditorLegacy), findsOneWidget);
    expect(find.text(ne.hostEditorLegacyHelp), findsOneWidget);
    expect(find.textContaining('Allows SHA-1'), findsNothing);
  });
}
