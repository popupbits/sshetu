import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/data/local_fs_service.dart';
import 'package:sshetu/features/files/domain/pane_drag.dart';
import 'package:sshetu/features/files/domain/transfer_plan.dart';
import 'package:sshetu/features/files/file_browser_controller.dart';
import 'package:sshetu/features/files/widgets/local_pane.dart';
import 'package:sshetu/features/files/widgets/pane_drop_target.dart';
import 'package:sshetu/features/files/widgets/remote_pane.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_sftp_service.dart';

/// Drops — from the other pane, or from the operating system — end in the
/// same transfer jobs the menus start.
void main() {
  late Directory localRoot;
  late FakeSftpService sftp;

  const remoteFile = RemoteEntry(
    name: 'server.log',
    path: '/server.log',
    isDirectory: false,
    size: 10,
  );
  const remoteDir = RemoteEntry(name: 'site', path: '/site', isDirectory: true);
  const existingRemote = RemoteEntry(
    name: 'notes.txt',
    path: '/notes.txt',
    isDirectory: false,
    size: 3,
  );

  setUp(() async {
    localRoot = await Directory.systemTemp.createTemp('drag_drop_test');
    sftp = FakeSftpService(
      directories: {
        '/': [remoteDir, existingRemote, remoteFile],
        '/site': [
          const RemoteEntry(
            name: 'index.html',
            path: '/site/index.html',
            isDirectory: false,
            size: 5,
          ),
        ],
      },
    );
  });

  tearDown(() {
    if (localRoot.existsSync()) localRoot.deleteSync(recursive: true);
  });

  FileBrowserController build() => FileBrowserController(
    sftp: sftp,
    localRoot: localRoot.path,
    recordError: (_, _) {},
  );

  LocalEntry localFile(String name, {String content = 'x'}) {
    final path = p.join(localRoot.path, name);
    File(path).writeAsStringSync(content);
    return LocalEntry(name: name, path: path, isDirectory: false);
  }

  group('routing', () {
    test('a local row dropped on the remote pane uploads it', () async {
      final c = build();
      addTearDown(c.dispose);
      await c.refreshRemote();
      final entry = localFile('a.txt');

      expect(c.remoteAccepts(LocalDrag([entry])), isTrue);
      await c.dropOnRemote(LocalDrag([entry]));
      expect(sftp.uploadedRemotePaths, ['/a.txt']);
      expect(c.transfers.single.direction, TransferDirection.upload);
    });

    test('a remote row dropped on the local pane downloads it', () async {
      final c = build();
      addTearDown(c.dispose);
      await c.refreshRemote();

      expect(c.localAccepts(const RemoteDrag([remoteFile])), isTrue);
      await c.dropOnLocal(const RemoteDrag([remoteFile]));
      expect(sftp.downloadedRemotePaths, ['/server.log']);
      expect(File(p.join(localRoot.path, 'server.log')).existsSync(), isTrue);
    });

    test('a row dropped back on its own pane is not a transfer', () async {
      final c = build();
      addTearDown(c.dispose);
      expect(c.remoteAccepts(const RemoteDrag([remoteFile])), isFalse);
      expect(c.localAccepts(LocalDrag([localFile('b.txt')])), isFalse);

      await c.dropOnRemote(const RemoteDrag([remoteFile]));
      await c.dropOnLocal(LocalDrag([localFile('c.txt')]));
      expect(sftp.uploadedRemotePaths, isEmpty);
      expect(sftp.downloadedRemotePaths, isEmpty);
      expect(c.transfers, isEmpty);
    });

    test('a folder goes as one folder job', () async {
      final c = build();
      addTearDown(c.dispose);
      await c.dropOnLocal(const RemoteDrag([remoteDir]));
      expect(c.transfers.single.isFolder, isTrue);
      expect(sftp.downloadedRemotePaths, ['/site/index.html']);
    });

    test('dragging a selected row carries the whole selection', () async {
      final c = build();
      addTearDown(c.dispose);
      await c.refreshRemote();
      c
        ..toggleRemoteSelectionMode()
        ..toggleRemoteSelected(remoteFile.path)
        ..toggleRemoteSelected(existingRemote.path);

      expect(c.remoteDragFor(remoteFile).entries.map((e) => e.name), {
        'notes.txt',
        'server.log',
      });
      // A row outside the selection drags alone.
      expect(c.remoteDragFor(remoteDir).entries, [remoteDir]);
    });
  });

  group('OS drops', () {
    test('files and folders by path, each to its own job', () async {
      final c = build();
      addTearDown(c.dispose);
      final file = localFile('drop.txt');
      final dir = Directory(p.join(localRoot.path, 'bundle'))..createSync();
      File(p.join(dir.path, 'inner.txt')).writeAsStringSync('i');

      await c.uploadLocalPaths([
        file.path,
        dir.path,
        p.join(localRoot.path, 'vanished.txt'),
      ]);
      expect(sftp.uploadedRemotePaths, ['/drop.txt', '/bundle/inner.txt']);
      expect(c.transfers.map((t) => t.isFolder), [false, true]);
    });

    test('loose files that already exist are asked about once', () async {
      final c = build();
      addTearDown(c.dispose);
      final clash = localFile('notes.txt');
      final fresh = localFile('fresh.txt');
      final asked = <(String, int)>[];

      await c.uploadLocalPaths(
        [clash.path, fresh.path],
        onConflict: (folder, count) async {
          asked.add((folder, count));
          return ConflictChoice.skipExisting;
        },
      );
      expect(asked, [('/', 1)]);
      expect(sftp.uploadedRemotePaths, ['/fresh.txt']);
    });

    test('overwrite sends them all; cancel sends nothing', () async {
      final c = build();
      addTearDown(c.dispose);
      final clash = localFile('notes.txt');
      final fresh = localFile('fresh.txt');

      await c.uploadLocalPaths([
        clash.path,
        fresh.path,
      ], onConflict: (_, _) async => ConflictChoice.cancel);
      expect(sftp.uploadedRemotePaths, isEmpty);

      await c.uploadLocalPaths([
        clash.path,
        fresh.path,
      ], onConflict: (_, _) async => ConflictChoice.overwrite);
      expect(sftp.uploadedRemotePaths, ['/notes.txt', '/fresh.txt']);
    });

    test('without anyone to ask, existing files are kept', () async {
      final c = build();
      addTearDown(c.dispose);
      await c.uploadLocalPaths([localFile('notes.txt').path]);
      expect(sftp.uploadedRemotePaths, isEmpty);
    });
  });

  group('panes', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    Widget wrap(FileBrowserController c, {required bool wide}) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListenableBuilder(
          listenable: c,
          builder: (_, _) => wide
              ? Row(
                  children: [
                    Expanded(child: RemotePane(controller: c, allowDrag: true)),
                    Expanded(child: LocalPane(controller: c, allowDrag: true)),
                  ],
                )
              : RemotePane(controller: c),
        ),
      ),
    );

    void setSize(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<FileBrowserController> ready(WidgetTester tester) async {
      final c = (await tester.runAsync(() async {
        final c = build();
        await c.refreshRemote();
        await c.refreshLocal();
        return c;
      }))!;
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('at 1280, dragging a remote row onto the local pane '
        'highlights it, then downloads', (tester) async {
      setSize(tester, const Size(1280, 800));
      final c = await ready(tester);
      await tester.pumpWidget(wrap(c, wide: true));
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.text('server.log'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(const Offset(960, 400));
      await tester.pump();
      expect(find.byKey(PaneDropTarget.highlightKey), findsOneWidget);
      expect(
        find.text(l10n.filesDropDownload(c.localLabel(c.localPath))),
        findsOneWidget,
      );

      await gesture.up();
      // The drop lists and writes the real local folder; real I/O only
      // completes outside the fake clock.
      bool finished() =>
          c.transfers.isNotEmpty &&
          c.transfers.every((t) => t.done) &&
          !c.localEntries.isLoading;
      for (var i = 0; i < 200 && !finished(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pump();
      expect(sftp.downloadedRemotePaths, ['/server.log']);
      expect(find.byKey(PaneDropTarget.highlightKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a vertical drag is a scroll, not a transfer', (tester) async {
      setSize(tester, const Size(1280, 800));
      final c = await ready(tester);
      await tester.pumpWidget(wrap(c, wide: true));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('server.log')),
      );
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(PaneDropTarget.highlightKey), findsNothing);
      expect(sftp.downloadedRemotePaths, isEmpty);
    });

    testWidgets('at 360 there is one pane and nothing to drag', (tester) async {
      setSize(tester, const Size(360, 740));
      final c = await ready(tester);
      await tester.pumpWidget(wrap(c, wide: false));
      await tester.pumpAndSettle();
      expect(find.byType(Draggable<PaneDragData>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
