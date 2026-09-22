import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/settings/widgets/scrollback_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The scrollback count reads in Latin digits in Nepali, like every other
/// number in the app — it used to be the one place printing "१०,०००".
void main() {
  for (final locale in const [Locale('en'), Locale('ne')]) {
    testWidgets('scrollback count in Latin digits (${locale.languageCode})', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: const Scaffold(body: ScrollbackTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(locale);
      final lines = container.read(settingsControllerProvider).scrollbackLines;
      expect(lines, 10000, reason: 'the default this test was written for');
      expect(find.text(l10n.settingsScrollbackValue('10,000')), findsOneWidget);
      expect(find.textContaining(RegExp('[०-९]')), findsNothing);

      // The menu's options too.
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.text(l10n.scrollbackLinesOption('10,000')), findsWidgets);
      expect(find.textContaining(RegExp('[०-९]')), findsNothing);
    });
  }
}
