import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/files/file_browser_controller.dart';
import 'package:sshetu/features/files/widgets/path_bar.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// Submitting a typed path with the keyboard's Done key — what a phone sends.
///
/// Found on an Android emulator: the default completion unfocused the field
/// before the submit's answer came back, so the focus listener closed the
/// field, and a rejected path showed no error at all — nothing appeared to
/// happen.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget wrap(Future<PathSubmitResult> Function(String) onSubmit) =>
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PathBar(
            currentPath: '/',
            segments: const ['/'],
            labelOf: (p) => p,
            onTap: (_) {},
            onSubmit: onSubmit,
          ),
        ),
      );

  Future<void> startEditing(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10n.filesPathEdit));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  }

  testWidgets('a rejected path keeps the field open with its error', (
    tester,
  ) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      wrap((input) async {
        submitted.add(input);
        return PathSubmitResult.notFound;
      }),
    );
    await startEditing(tester);

    await tester.enterText(find.byType(TextField), '/nope');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submitted, ['/nope']);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(l10n.filesPathNotFound), findsOneWidget);
  });

  testWidgets('an accepted path closes the field', (tester) async {
    await tester.pumpWidget(wrap((_) async => PathSubmitResult.ok));
    await startEditing(tester);

    await tester.enterText(find.byType(TextField), '/etc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });
}
