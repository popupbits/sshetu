import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/domain/transfer_plan.dart';
import 'package:sshetu/features/files/file_browser_controller.dart';
import 'package:sshetu/features/files/widgets/conflict_dialog.dart';
import 'package:sshetu/features/files/widgets/entry_name_dialog.dart';
import 'package:sshetu/features/files/widgets/local_pane.dart';
import 'package:sshetu/features/files/widgets/remote_pane.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_sftp_service.dart';

/// The rename / new-folder entry points on both panes, at a phone width and a
/// desktop width, plus the two dialogs they open.
void main() {
  late Directory localRoot;
  late FakeSftpService sftp;
  late AppLocalizations l10n;

  const fileA = RemoteEntry(
    name: 'a.txt',
    path: '/a.txt',
    isDirectory: false,
    size: 1,
  );
  const dirB = RemoteEntry(name: 'b', path: '/b', isDirectory: true);

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    localRoot = await Directory.systemTemp.createTemp('rename_ui_test');
    sftp = FakeSftpService(
      directories: {
        '/': [dirB, fileA],
      },
    );
  });

  tearDown(() {
    if (localRoot.existsSync()) localRoot.deleteSync(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  /// Rebuilds [build] whenever the controller notifies, the way the screen's
  /// own `ListenableBuilder` does.
  Widget listening(FileBrowserController controller, Widget Function() build) =>
      wrap(
        ListenableBuilder(listenable: controller, builder: (_, _) => build()),
      );

  void setWidth(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Built, and its first listings loaded, outside the fake clock: the local
  /// pane lists a real directory, and real I/O never completes inside it.
  Future<FileBrowserController> controllerFor(WidgetTester tester) async {
    final controller = (await tester.runAsync(() async {
      final c = FileBrowserController(
        sftp: sftp,
        localRoot: localRoot.path,
        recordError: (_, _) {},
      );
      await c.refreshRemote();
      await c.refreshLocal();
      return c;
    }))!;
    addTearDown(controller.dispose);
    return controller;
  }

  FilledButton confirmButton(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  group('compact width', () {
    const phone = Size(390, 844);

    testWidgets('New folder validates inline, then creates', (tester) async {
      setWidth(tester, phone);
      final controller = await controllerFor(tester);
      await tester.pumpWidget(
        listening(controller, () => RemotePane(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip(l10n.filesNewFolder));
      await tester.pumpAndSettle();

      // Empty to start with, but not scolded for it yet.
      expect(find.text(l10n.filesNameEmpty), findsNothing);
      expect(confirmButton(tester, l10n.filesCreate).onPressed, isNull);

      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), 'b');
      await tester.pump();
      expect(find.text(l10n.filesNameExists('b')), findsOneWidget);
      expect(confirmButton(tester, l10n.filesCreate).onPressed, isNull);

      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), 'x/y');
      await tester.pump();
      expect(find.text(l10n.filesNameSeparator), findsOneWidget);

      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), '..');
      await tester.pump();
      expect(find.text(l10n.filesNameReserved), findsOneWidget);

      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), '');
      await tester.pump();
      expect(find.text(l10n.filesNameEmpty), findsOneWidget);

      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), 'logs');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, l10n.filesCreate));
      await tester.pumpAndSettle();

      expect(sftp.mkdirPaths, ['/logs']);
      expect(find.text('logs'), findsOneWidget);
    });

    testWidgets('Rename from the row menu renames the entry', (tester) async {
      setWidth(tester, phone);
      final controller = await controllerFor(tester);
      await tester.pumpWidget(
        listening(controller, () => RemotePane(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Touch platform in tests: long-press opens the row's action sheet.
      await tester.longPress(find.text('a.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.filesRename));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(EntryNameDialog.fieldKey),
      );
      expect(field.controller!.text, 'a.txt');
      // The stem is preselected, so typing replaces "a" and keeps ".txt".
      expect(field.controller!.selection.textInside('a.txt'), 'a');

      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), 'c.txt');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, l10n.filesRename));
      await tester.pumpAndSettle();

      expect(sftp.renameCalls, [('/a.txt', '/c.txt')]);
      expect(find.text('c.txt'), findsOneWidget);
    });

    testWidgets('a server refusal is shown as a toast', (tester) async {
      setWidth(tester, phone);
      sftp.mkdirError = SftpException(
        'Could not create logs: permission denied.',
        kind: SftpFailureKind.permissionDenied,
      );
      final controller = await controllerFor(tester);
      await tester.pumpWidget(
        listening(controller, () => RemotePane(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.filesNewFolder));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), 'logs');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        find.text('Could not create logs: permission denied.'),
        findsOneWidget,
      );
    });

    testWidgets('the local pane offers New folder too', (tester) async {
      setWidth(tester, phone);
      final controller = await controllerFor(tester);
      await tester.pumpWidget(
        listening(controller, () => LocalPane(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip(l10n.filesNewFolder));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(EntryNameDialog.fieldKey), 'made');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, l10n.filesCreate));
      // The controller does real I/O, whose completions only reach this
      // zone when it pumps: alternate real time and pumps until the new
      // folder is listed (bounded, so a regression fails instead of hanging).
      // A ListTile, not bare text: the dialog's own field also shows "made"
      // until it has animated away.
      final row = find.widgetWithText(ListTile, 'made');
      for (var i = 0; i < 50 && row.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(Directory(p.join(localRoot.path, 'made')).existsSync(), isTrue);
      expect(row, findsOneWidget);
    });
  });

  group('expanded width', () {
    testWidgets('both panes lay out side by side with their actions', (
      tester,
    ) async {
      setWidth(tester, const Size(1280, 800));
      final controller = await controllerFor(tester);
      await tester.pumpWidget(
        listening(
          controller,
          () => Row(
            children: [
              Expanded(child: RemotePane(controller: controller)),
              const VerticalDivider(width: 1),
              Expanded(child: LocalPane(controller: controller)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip(l10n.filesNewFolder), findsNWidgets(2));

      await tester.longPress(find.text('b'));
      await tester.pumpAndSettle();
      // Folders can be renamed and downloaded, not just files.
      expect(find.text(l10n.filesRename), findsOneWidget);
      expect(find.text(l10n.filesDownload), findsOneWidget);
    });
  });

  group('conflict dialog', () {
    testWidgets('returns the choice, and cancel when dismissed', (
      tester,
    ) async {
      ConflictChoice? result;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showConflictDialog(
                context,
                folderName: 'project',
                count: 3,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.filesConflictBody(3, 'project')), findsOneWidget);
      await tester.tap(find.text(l10n.filesConflictSkip));
      await tester.pumpAndSettle();
      expect(result, ConflictChoice.skipExisting);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.filesConflictOverwrite));
      await tester.pumpAndSettle();
      expect(result, ConflictChoice.overwrite);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4)); // the barrier
      await tester.pumpAndSettle();
      expect(result, ConflictChoice.cancel);
    });
  });
}
