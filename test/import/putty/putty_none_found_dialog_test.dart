import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/theme/tokens.dart';
import 'package:sshetu/features/import/putty/putty_none_found_dialog.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// "No PuTTY sessions found" is a short message, sized like one.
///
/// At a desktop window's width it used to stretch nearly edge to edge: an
/// AlertDialog sizes itself to its content, and its paragraph was allowed to
/// be as wide as the window.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  Future<Future<bool?>> show(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Future<bool?> answer;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => answer = showDialog<bool>(
                  context: context,
                  builder: (_) => const PuttyNoneFoundDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('capped at a message width on a wide desktop window', (
    tester,
  ) async {
    await show(tester, const Size(1750, 1000));
    expect(tester.takeException(), isNull);
    expect(find.text(en.puttyNoneFoundBody), findsOneWidget);
    // The dialog's surface: the body's cap plus its padding either side.
    final surface = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    expect(
      tester.getSize(surface).width,
      lessThanOrEqualTo(Breakpoints.maxMessageWidth + 2 * Spacing.xl),
    );
  });

  testWidgets('fits a phone', (tester) async {
    await show(tester, const Size(360, 740));
    expect(tester.takeException(), isNull);
    expect(find.text(en.puttyChooseFile), findsOneWidget);
  });

  testWidgets('Cancel answers false, Choose file true', (tester) async {
    var answer = await show(tester, const Size(1280, 800));
    await tester.tap(find.text(en.actionCancel));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);

    answer = await show(tester, const Size(1280, 800));
    await tester.tap(find.text(en.puttyChooseFile));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });
}
