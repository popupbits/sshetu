import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/data/local_fs_service.dart';
import 'package:sshetu/features/files/domain/entry_name.dart';
import 'package:sshetu/features/files/file_browser_controller.dart';

import 'fake_sftp_service.dart';

/// Rename and new folder on both panes: the remote side against the fake
/// service, the local side against a real temporary directory.
void main() {
  late Directory localRoot;
  late FakeSftpService sftp;

  const fileA = RemoteEntry(
    name: 'a.txt',
    path: '/srv/a.txt',
    isDirectory: false,
    size: 1,
  );
  const hidden = RemoteEntry(
    name: '.env',
    path: '/srv/.env',
    isDirectory: false,
    size: 1,
  );
  const dirB = RemoteEntry(name: 'b', path: '/srv/b', isDirectory: true);

  setUp(() async {
    localRoot = await Directory.systemTemp.createTemp('rename_test');
    sftp = FakeSftpService(
      directories: {
        '/srv': [dirB, fileA, hidden],
        '/srv/b': [],
      },
    );
  });

  tearDown(() async {
    if (localRoot.existsSync()) localRoot.deleteSync(recursive: true);
  });

  Future<FileBrowserController> build() async {
    final controller = FileBrowserController(
      sftp: sftp,
      localRoot: localRoot.path,
      remoteRoot: '/srv',
    );
    addTearDown(controller.dispose);
    await controller.refreshRemote();
    await controller.refreshLocal();
    return controller;
  }

  group('remote rename', () {
    test('renames within the same folder and reloads the listing', () async {
      final controller = await build();

      await controller.renameRemote(fileA, 'renamed.txt');

      expect(sftp.renameCalls, [('/srv/a.txt', '/srv/renamed.txt')]);
      expect(
        controller.remoteEntries.value!.map((e) => e.name),
        contains('renamed.txt'),
      );
      expect(
        controller.remoteEntries.value!.map((e) => e.name),
        isNot(contains('a.txt')),
      );
    });

    test('surrounding whitespace is trimmed from the new name', () async {
      final controller = await build();
      await controller.renameRemote(fileA, '  c.txt ');
      expect(sftp.renameCalls.single.$2, '/srv/c.txt');
    });

    test('a name a sibling already has is refused before the server', () async {
      final controller = await build();

      await expectLater(
        controller.renameRemote(fileA, 'b'),
        throwsA(
          isA<InvalidEntryNameException>().having(
            (e) => e.error,
            'error',
            EntryNameError.exists,
          ),
        ),
      );
      expect(sftp.renameCalls, isEmpty);
    });

    test(
      'a hidden sibling counts even while hidden files are not shown',
      () async {
        final controller = await build();
        expect(controller.remoteShowHidden, isFalse);

        expect(
          controller.validateRemoteName('.env', current: 'a.txt'),
          EntryNameError.exists,
        );
      },
    );

    test('renaming to the same name does nothing', () async {
      final controller = await build();
      await controller.renameRemote(fileA, 'a.txt');
      expect(sftp.renameCalls, isEmpty);
    });

    test('a server refusal propagates, and the pane still reloads', () async {
      sftp.renameError = SftpException(
        'Could not rename a.txt: permission denied.',
        kind: SftpFailureKind.permissionDenied,
      );
      final controller = await build();
      sftp.directories['/srv']!.add(
        const RemoteEntry(name: 'new', path: '/srv/new', isDirectory: false),
      );

      await expectLater(
        controller.renameRemote(fileA, 'x.txt'),
        throwsA(isA<SftpException>()),
      );
      expect(
        controller.remoteEntries.value!.map((e) => e.name),
        contains('new'),
        reason: 'a failed rename refreshes the listing too',
      );
    });

    test('the old path leaves the selection', () async {
      final controller = await build();
      controller
        ..toggleRemoteSelectionMode()
        ..toggleRemoteSelected(fileA.path);

      await controller.renameRemote(fileA, 'z.txt');

      expect(controller.remoteSelection, isEmpty);
    });
  });

  group('remote new folder', () {
    test('creates the folder in the current directory', () async {
      final controller = await build();

      await controller.createRemoteFolder('logs');

      expect(sftp.mkdirPaths, ['/srv/logs']);
      expect(
        controller.remoteEntries.value!.map((e) => e.name),
        contains('logs'),
      );
    });

    test('invalid names are refused before the server', () async {
      final controller = await build();
      for (final bad in ['', '..', 'a/b', 'b']) {
        await expectLater(
          controller.createRemoteFolder(bad),
          throwsA(isA<InvalidEntryNameException>()),
          reason: bad,
        );
      }
      expect(sftp.mkdirPaths, isEmpty);
    });
  });

  group('local rename and new folder', () {
    test('renames a real file and reloads the pane', () async {
      await File(p.join(localRoot.path, 'old.txt')).writeAsString('x');
      final controller = await build();
      final entry = controller.localEntries.value!.single;

      await controller.renameLocal(entry, 'new.txt');

      expect(File(p.join(localRoot.path, 'new.txt')).existsSync(), isTrue);
      expect(File(p.join(localRoot.path, 'old.txt')).existsSync(), isFalse);
      expect(controller.localEntries.value!.single.name, 'new.txt');
    });

    test('renames a real folder', () async {
      await Directory(p.join(localRoot.path, 'dir')).create();
      final controller = await build();

      await controller.renameLocal(
        controller.localEntries.value!.single,
        'folder',
      );

      expect(Directory(p.join(localRoot.path, 'folder')).existsSync(), isTrue);
    });

    test('refuses a name taken by a sibling', () async {
      await File(p.join(localRoot.path, 'a.txt')).writeAsString('a');
      await File(p.join(localRoot.path, 'b.txt')).writeAsString('b');
      final controller = await build();
      final a = controller.localEntries.value!.firstWhere(
        (e) => e.name == 'a.txt',
      );

      await expectLater(
        controller.renameLocal(a, 'b.txt'),
        throwsA(isA<InvalidEntryNameException>()),
      );
      expect(File(p.join(localRoot.path, 'b.txt')).readAsStringSync(), 'b');
    });

    test('creates a folder', () async {
      final controller = await build();

      await controller.createLocalFolder('made');

      expect(Directory(p.join(localRoot.path, 'made')).existsSync(), isTrue);
      expect(controller.localEntries.value!.single.name, 'made');
    });
  });

  group('rename shortcut target', () {
    test('needs exactly one selected entry', () async {
      final controller = await build();
      expect(controller.renameShortcutPane(bothPanesVisible: true), isNull);

      controller
        ..toggleRemoteSelectionMode()
        ..toggleRemoteSelected(fileA.path);
      expect(controller.singleSelectedRemote?.path, fileA.path);
      expect(
        controller.renameShortcutPane(bothPanesVisible: true),
        BrowserPane.remote,
      );

      controller.toggleRemoteSelected(dirB.path);
      expect(controller.singleSelectedRemote, isNull);
      expect(controller.renameShortcutPane(bothPanesVisible: true), isNull);
    });

    test('with one pane showing, only that pane counts', () async {
      await File(p.join(localRoot.path, 'l.txt')).writeAsString('l');
      final controller = await build();
      final local = controller.localEntries.value!.single;
      controller
        ..toggleLocalSelectionMode()
        ..toggleLocalSelected(local.path);

      // The remote pane is the one showing on a phone by default.
      expect(controller.renameShortcutPane(bothPanesVisible: false), isNull);
      expect(
        controller.renameShortcutPane(bothPanesVisible: true),
        BrowserPane.local,
      );

      controller.selectPane(BrowserPane.local);
      expect(
        controller.renameShortcutPane(bothPanesVisible: false),
        BrowserPane.local,
      );
    });

    test('the active pane breaks a tie', () async {
      await File(p.join(localRoot.path, 'l.txt')).writeAsString('l');
      final controller = await build();
      controller
        ..toggleRemoteSelectionMode()
        ..toggleRemoteSelected(fileA.path)
        ..toggleLocalSelectionMode()
        ..toggleLocalSelected(controller.localEntries.value!.single.path);

      expect(
        controller.renameShortcutPane(bothPanesVisible: true),
        BrowserPane.remote,
      );
      controller.selectPane(BrowserPane.local);
      expect(
        controller.renameShortcutPane(bothPanesVisible: true),
        BrowserPane.local,
      );
    });
  });

  group('LocalFsService', () {
    const service = LocalFsService();

    test('mkdir refuses a name that already exists', () async {
      final path = p.join(localRoot.path, 'x');
      await Directory(path).create();
      await expectLater(service.mkdir(path), throwsA(isA<LocalFsException>()));
    });

    test('rename refuses to replace an existing file', () async {
      final from = p.join(localRoot.path, 'a');
      final to = p.join(localRoot.path, 'b');
      await File(from).writeAsString('a');
      await File(to).writeAsString('b');

      await expectLater(
        service.rename(from, to),
        throwsA(isA<LocalFsException>()),
      );
      expect(File(to).readAsStringSync(), 'b');
    });

    test(
      'ensureDirectory accepts an existing folder, refuses a file',
      () async {
        final dir = p.join(localRoot.path, 'd');
        await Directory(dir).create();
        await service.ensureDirectory(dir);

        final file = p.join(localRoot.path, 'f');
        await File(file).writeAsString('f');
        await expectLater(
          service.ensureDirectory(file),
          throwsA(isA<LocalFsException>()),
        );
      },
    );
  });
}
