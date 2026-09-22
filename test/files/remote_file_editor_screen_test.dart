import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/files/editor/code_editor_field.dart';
import 'package:sshetu/features/files/editor/open_remote_editor.dart';
import 'package:sshetu/features/files/editor/remote_file_editor_controller.dart';
import 'package:sshetu/features/files/editor/remote_file_editor_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_sftp_service.dart';

void main() {
  late FakeSftpService sftp;
  late AppLocalizations l10n;
  const path = '/etc/motd';

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    sftp = FakeSftpService();
    sftp.putFile(path, text: 'line one\r\nline two\r\n');
  });

  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<RemoteFileEditorController> controller() async {
    final c = RemoteFileEditorController(sftp: sftp, path: path);
    addTearDown(c.dispose);
    await c.load();
    return c;
  }

  Future<void> pressSave(WidgetTester tester, {bool shift = false}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  IconButton button(WidgetTester tester, Key key) =>
      tester.widget<IconButton>(find.byKey(key));

  for (final (label, size, embedded) in [
    ('phone', const Size(360, 740), false),
    ('desktop tab', const Size(1280, 800), true),
  ]) {
    group(label, () {
      testWidgets('shows the file with line numbers and its encoding', (
        tester,
      ) async {
        setSize(tester, size);
        final c = await controller();
        await tester.pumpWidget(
          app(RemoteFileEditorScreen(controller: c, embedded: embedded)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('motd'), findsOneWidget);
        expect(find.text('1\n2\n3'), findsOneWidget);
        expect(find.textContaining(l10n.editorCrlf), findsOneWidget);
        expect(find.byKey(RemoteFileEditorScreen.dirtyKey), findsNothing);
        expect(
          button(tester, RemoteFileEditorScreen.saveKey).onPressed,
          isNull,
        );
      });

      testWidgets('an edit marks it unsaved; Ctrl+S saves it', (tester) async {
        setSize(tester, size);
        final c = await controller();
        await tester.pumpWidget(
          app(RemoteFileEditorScreen(controller: c, embedded: embedded)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(CodeEditorField.fieldKey),
          'line one\nchanged\n',
        );
        await tester.pump();
        expect(find.byKey(RemoteFileEditorScreen.dirtyKey), findsOneWidget);
        expect(
          button(tester, RemoteFileEditorScreen.saveKey).onPressed,
          isNotNull,
        );

        // Ctrl+Shift+S belongs to the snippet picker, never to Save.
        await pressSave(tester, shift: true);
        expect(c.isDirty, isTrue);

        await pressSave(tester);
        expect(c.isDirty, isFalse);
        expect(sftp.textOf(path), 'line one\r\nchanged\r\n');
        expect(find.text(l10n.editorSaved('motd')), findsOneWidget);
        expect(find.byKey(RemoteFileEditorScreen.dirtyKey), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('revert puts the saved text back', (tester) async {
        setSize(tester, size);
        final c = await controller();
        await tester.pumpWidget(
          app(RemoteFileEditorScreen(controller: c, embedded: embedded)),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(CodeEditorField.fieldKey), 'oops');
        await tester.pump();

        await tester.tap(find.byKey(RemoteFileEditorScreen.revertKey));
        await tester.pump();
        expect(c.text.text, 'line one\nline two\n');
        expect(find.byKey(RemoteFileEditorScreen.dirtyKey), findsNothing);
      });
    });
  }

  testWidgets('a change on the server asks before overwriting', (tester) async {
    setSize(tester, const Size(1280, 800));
    final c = await controller();
    await tester.pumpWidget(
      app(RemoteFileEditorScreen(controller: c, embedded: true)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CodeEditorField.fieldKey), 'mine\n');
    await tester.pump();
    sftp.changeBehindTheScenes(path, 'theirs\n');

    await tester.tap(find.byKey(RemoteFileEditorScreen.saveKey));
    // Not pumpAndSettle: the save button spins while the question is open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.editorConflictTitle), findsOneWidget);

    await tester.tap(find.text(l10n.editorConflictOverwrite));
    await tester.pumpAndSettle();
    expect(sftp.textOf(path), 'mine\r\n');
    expect(c.isDirty, isFalse);
  });

  testWidgets('a binary file says so instead of opening', (tester) async {
    sftp.putFile(path, bytes: [0, 1, 2, 3]);
    final c = await controller();
    await tester.pumpWidget(app(RemoteFileEditorScreen(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.editorBinaryTitle), findsOneWidget);
    expect(find.byKey(CodeEditorField.fieldKey), findsNothing);
  });

  testWidgets('on a phone, backing out of unsaved edits asks first', (
    tester,
  ) async {
    setSize(tester, const Size(360, 740));
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RemoteEditorRoute(
                    create: () => RemoteFileEditorController(
                      sftp: sftp,
                      path: path,
                      ownsSftp: false,
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CodeEditorField.fieldKey), 'edited');
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text(l10n.editorDiscardTitle), findsOneWidget);

    await tester.tap(find.text(l10n.actionCancel));
    await tester.pumpAndSettle();
    expect(find.byKey(CodeEditorField.fieldKey), findsOneWidget);

    await navigator.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editorDiscard));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(sftp.textOf(path), 'line one\r\nline two\r\n');
  });
}
