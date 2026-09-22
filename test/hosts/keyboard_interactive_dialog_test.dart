import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ssh/keyboard_interactive.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';
import 'package:sshetu/features/hosts/widgets/keyboard_interactive_dialog.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The dialog a server's keyboard-interactive questions are asked in.
void main() {
  const twoPrompts = KeyboardInteractiveRequest(
    address: 'deploy@bastion.example.com:22',
    canRemember: false,
    challenge: KeyboardInteractiveChallenge(
      name: 'Two-factor sign-in',
      instruction: 'Open your authenticator app.',
      round: 0,
      prompts: [
        KeyboardInteractivePrompt('Password: ', echo: false),
        KeyboardInteractivePrompt('Verification code: ', echo: true),
      ],
    ),
  );

  const passwordOnly = KeyboardInteractiveRequest(
    address: 'deploy@example.com:22',
    canRemember: true,
    challenge: KeyboardInteractiveChallenge(
      round: 0,
      prompts: [KeyboardInteractivePrompt('Password: ', echo: false)],
    ),
  );

  /// Opens the dialog from a button and records what it returned.
  Future<List<KeyboardInteractiveReply?>> open(
    WidgetTester tester,
    KeyboardInteractiveRequest request, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final results = <KeyboardInteractiveReply?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await showKeyboardInteractiveDialog(context, request),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  List<EditableText> fields(WidgetTester tester) =>
      tester.widgetList<EditableText>(find.byType(EditableText)).toList();

  for (final size in const [Size(400, 800), Size(1280, 900)]) {
    testWidgets('shows what the server said, masks only hidden prompts '
        '(${size.width.toInt()} wide)', (tester) async {
      final results = await open(tester, twoPrompts, size: size);

      expect(find.text('Two-factor sign-in'), findsOneWidget);
      expect(find.text('Open your authenticator app.'), findsOneWidget);
      expect(find.text('deploy@bastion.example.com:22'), findsOneWidget);
      expect(find.text('Password:'), findsOneWidget);
      expect(find.text('Verification code:'), findsOneWidget);

      final editable = fields(tester);
      expect(editable, hasLength(2));
      expect(editable[0].obscureText, isTrue);
      expect(editable[1].obscureText, isFalse);
      expect(editable[0].focusNode.hasFocus, isTrue, reason: 'autofocus');
      expect(find.byType(CheckboxListTile), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), 'pw');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(results.single?.answers, ['pw', '123456']);
      expect(results.single?.remember, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancel returns nothing', (tester) async {
    final results = await open(tester, twoPrompts);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('a password round offers remember and a generic title', (
    tester,
  ) async {
    final results = await open(tester, passwordOnly);

    expect(find.text('Server sign-in'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    // Enter on the last field submits.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(results.single?.answers, ['pw']);
    expect(results.single?.remember, isTrue);
  });
}
