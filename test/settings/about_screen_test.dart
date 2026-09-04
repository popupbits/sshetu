import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/settings/about_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// Where the licences open.
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('on a desktop they open in a dialog, over what is behind', (
    tester,
  ) async {
    await pump(tester, const Size(1400, 900));

    await tester.tap(find.text('Open-source licences'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(LicensePage), findsOneWidget);
    // The point of the dialog: About is still there underneath.
    expect(find.byType(AboutScreen), findsOneWidget);
  });

  testWidgets('on a phone they stay a page', (tester) async {
    await pump(tester, const Size(390, 844));

    await tester.tap(find.text('Open-source licences'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('the licences dialog fits every window it can open in', (
    tester,
  ) async {
    // A dialog gives its child loose constraints, and LicensePage lays itself
    // out side-by-side above 840 points. A window between those two numbers is
    // where a fixed master column and the space actually available disagree.
    for (final width in [1600.0, 1200.0, 1000.0, 900.0, 860.0, 700.0, 620.0]) {
      await pump(tester, Size(width, 900));

      await tester.tap(find.text('Open-source licences'));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the licences overflowed at ${width}pt',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
