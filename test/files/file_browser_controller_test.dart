import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/core/util/sort_entries.dart';
import 'package:sshetu/features/files/file_browser_controller.dart';

import 'fake_sftp_service.dart';

/// The controller against a fake SFTP service and a real temporary
/// directory for the local pane — no server, no socket, but the local half
/// is real `dart:io` so a bug in how a transfer path is computed shows up as
/// a missing file, not as an assertion on a mock's call log.
void main() {
  late Directory localRoot;
  late FakeSftpService sftp;

  const fileA = RemoteEntry(
    name: 'a.txt',
    path: '/a.txt',
    isDirectory: false,
    size: 42,
  );
  const dirA = RemoteEntry(
    name: 'projects',
    path: '/projects',
    isDirectory: true,
  );
  const nestedFile = RemoteEntry(
    name: 'main.dart',
    path: '/projects/main.dart',
    isDirectory: false,
    size: 7,
  );

  setUp(() async {
    localRoot = await Directory.systemTemp.createTemp('file_browser_test');
    sftp = FakeSftpService(
      directories: {
        '/': [dirA, fileA],
        '/projects': [nestedFile],
      },
    );
  });

  tearDown(() async {
    if (localRoot.existsSync()) localRoot.deleteSync(recursive: true);
  });

  FileBrowserController build() =>
      FileBrowserController(sftp: sftp, localRoot: localRoot.path);

  test('loads both panes on construction', () async {
    final controller = build();
    await controller.refreshRemote();
    await controller.refreshLocal();

    expect(controller.remoteEntries.value?.map((e) => e.name), [
      'projects',
      'a.txt',
    ]);
    expect(controller.localEntries.value, isEmpty);
  });

  test('opening a remote directory updates the path and its listing', () async {
    final controller = build();
    await controller.openRemote('/projects');

    expect(controller.remotePath, '/projects');
    expect(controller.remoteEntries.value?.single.name, 'main.dart');
  });

  test('going up from the remote root is a no-op, not an error', () async {
    // The edge case this guards against: SFTP has no parent of "/", and a
    // naive dirname() implementation can loop or throw there instead of
    // just staying put.
    final controller = build();
    await controller.refreshRemote();
    expect(controller.canGoUpRemote, isFalse);

    await controller.upRemote();
    expect(controller.remotePath, '/');
  });

  test('up from a nested remote directory returns to its parent', () async {
    final controller = build();
    await controller.openRemote('/projects');
    await controller.upRemote();
    expect(controller.remotePath, '/');
  });

  test(
    'a listing error becomes AsyncValue.error, not a thrown exception',
    () async {
      // The controller runs inside a ChangeNotifier a widget listens to — a
      // thrown exception here would crash the build instead of letting
      // `ErrorView` show it with a retry button.
      sftp.failListPath = '/broken';
      final controller = build();

      await controller.openRemote('/broken');

      expect(controller.remoteEntries, isA<AsyncError<List<RemoteEntry>>>());
    },
  );

  test(
    'download writes the file locally and marks the transfer done',
    () async {
      final controller = build();
      await controller.refreshLocal();

      await controller.download(fileA);

      expect(sftp.downloadedRemotePaths, [fileA.path]);
      expect(File('${localRoot.path}/a.txt').existsSync(), isTrue);
      final job = controller.transfers.single;
      expect(job.done, isTrue);
      expect(job.failed, isFalse);
      expect(job.transferred, 10);
    },
  );

  test(
    'a failed download surfaces on the transfer, not as a thrown exception',
    () async {
      sftp.downloadError = SftpException('connection lost');
      final controller = build();

      // Must not throw: a caller that fires this off from a tap handler has
      // nothing to catch it with.
      await controller.download(fileA);

      final job = controller.transfers.single;
      expect(job.done, isTrue);
      expect(job.failed, isTrue);
      expect(job.error, contains('connection lost'));
    },
  );

  test('a directory downloads whole, as a single folder job', () async {
    // Used to be skipped outright; see `folder_transfer_test.dart` for
    // the folder behaviour in depth.
    final controller = build();
    await controller.download(dirA);
    final job = controller.transfers.single;
    expect(job.isFolder, isTrue);
    expect(job.done, isTrue);
    expect(sftp.downloadedRemotePaths, [nestedFile.path]);
    expect(File('${localRoot.path}/projects/main.dart').existsSync(), isTrue);
  });

  test(
    'upload sends the file and the remote pane picks it up on refresh',
    () async {
      final localFile = File('${localRoot.path}/photo.jpg');
      await localFile.writeAsBytes(List.filled(10, 0));

      final controller = build();
      await controller.refreshLocal();
      final localEntry = controller.localEntries.value!.single;

      await controller.upload(localEntry);

      expect(sftp.uploadedRemotePaths, ['/photo.jpg']);
      expect(
        controller.remoteEntries.value?.map((e) => e.name),
        contains('photo.jpg'),
      );
    },
  );

  test('deleting a remote entry removes it after the refresh', () async {
    final controller = build();
    await controller.refreshRemote();

    await controller.deleteRemote(fileA);

    expect(sftp.deletedPaths, [fileA.path]);
    expect(
      controller.remoteEntries.value?.map((e) => e.name),
      isNot(contains('a.txt')),
    );
  });

  test('selecting a pane updates activePane and notifies listeners', () {
    final controller = build();
    var notified = false;
    controller.addListener(() => notified = true);

    controller.selectPane(BrowserPane.local);

    expect(controller.activePane, BrowserPane.local);
    expect(notified, isTrue);
  });

  test('dispose closes the SFTP channel but nothing else', () async {
    final controller = build();
    controller.dispose();
    // `close()` runs unawaited from dispose(); give it a turn to complete.
    await Future<void>.delayed(Duration.zero);
    expect(sftp.closeCallCount, 1);
  });

  group('remote path entry', () {
    test('an absolute path navigates directly', () async {
      final controller = build();
      final result = await controller.submitRemotePath('/projects');
      expect(result, PathSubmitResult.ok);
      expect(controller.remotePath, '/projects');
    });

    test('a relative path is rejected before any network call', () async {
      // The bug this guards against: resolving "projects" against whichever
      // directory happens to be open is a silent guess, and the fix has to
      // reject it client-side rather than send it to the server and hope the
      // server's own relative-path handling matches what the user meant.
      final controller = build();
      final result = await controller.submitRemotePath('projects');

      expect(result, PathSubmitResult.notAbsolute);
      expect(controller.remotePath, '/');
      expect(sftp.resolveCalls, isEmpty);
    });

    test('~ is expanded by the server before navigating', () async {
      // dartssh2's `absolute()` (SSH_FXP_REALPATH) is the only thing that
      // knows a *remote* user's home directory — the client cannot expand
      // `~` on its own, unlike the local pane where `$HOME` is available
      // directly.
      sftp
        ..resolveOverrides['~'] = '/home/test'
        ..directories['/home/test'] = [nestedFile];

      final controller = build();
      final result = await controller.submitRemotePath('~');

      expect(result, PathSubmitResult.ok);
      expect(controller.remotePath, '/home/test');
    });

    test('a path that does not exist reports notFound', () async {
      final controller = build();
      final result = await controller.submitRemotePath('/nowhere');
      expect(result, PathSubmitResult.notFound);
      // The path bar must not navigate on a rejected submission.
      expect(controller.remotePath, '/');
    });

    test(
      'a path that is a file, not a directory, reports notADirectory',
      () async {
        final controller = build();
        final result = await controller.submitRemotePath('/a.txt');
        expect(result, PathSubmitResult.notADirectory);
        expect(controller.remotePath, '/');
      },
    );
  });

  group('local path entry', () {
    test('an absolute path to a real directory navigates directly', () async {
      final controller = build();
      final result = await controller.submitLocalPath(localRoot.path);
      expect(result, PathSubmitResult.ok);
      expect(controller.localPath, localRoot.path);
    });

    test('a relative path is rejected', () async {
      final controller = build();
      final result = await controller.submitLocalPath('Documents');
      expect(result, PathSubmitResult.notAbsolute);
    });

    test('a path that does not exist reports notFound', () async {
      final controller = build();
      final result = await controller.submitLocalPath(
        '${localRoot.path}/nowhere',
      );
      expect(result, PathSubmitResult.notFound);
    });

    test(
      'a path that is a file, not a directory, reports notADirectory',
      () async {
        final file = File('${localRoot.path}/note.txt');
        await file.writeAsString('x');
        final controller = build();
        final result = await controller.submitLocalPath(file.path);
        expect(result, PathSubmitResult.notADirectory);
      },
    );
  });

  group('hidden files', () {
    test('a dotfile is filtered out of the listing by default', () async {
      sftp.directories['/'] = [
        fileA,
        const RemoteEntry(name: '.ssh', path: '/.ssh', isDirectory: true),
      ];
      final controller = build();
      await controller.refreshRemote();

      expect(
        controller.remoteEntries.value?.map((e) => e.name),
        isNot(contains('.ssh')),
      );
    });

    test('toggling show-hidden reveals it', () async {
      sftp.directories['/'] = [
        fileA,
        const RemoteEntry(name: '.ssh', path: '/.ssh', isDirectory: true),
      ];
      final controller = build();
      await controller.refreshRemote();

      controller.toggleRemoteShowHidden();

      expect(
        controller.remoteEntries.value?.map((e) => e.name),
        contains('.ssh'),
      );
    });
  });

  group('sorting', () {
    test('choosing a field twice reverses direction instead of a no-op', () {
      final controller = build();
      expect(controller.remoteSortAscending, isTrue);

      controller.setRemoteSort(SortField.size);
      expect(controller.remoteSortField, SortField.size);
      expect(controller.remoteSortAscending, isTrue);

      controller.setRemoteSort(SortField.size);
      expect(
        controller.remoteSortAscending,
        isFalse,
        reason: 'the same field again should flip direction, not reset it',
      );
    });

    test('choosing a different field resets to ascending', () {
      final controller = build();
      controller.setRemoteSort(SortField.size);
      controller.setRemoteSort(SortField.size); // now descending
      controller.setRemoteSort(SortField.modified);
      expect(controller.remoteSortAscending, isTrue);
    });
  });

  group('multi-select transfers', () {
    test('downloadSelected fires a job for every selected file', () async {
      final controller = build();
      await controller.refreshRemote();
      controller.toggleRemoteSelectionMode();
      controller.toggleRemoteSelected(fileA.path);

      await controller.downloadSelected();

      expect(sftp.downloadedRemotePaths, [fileA.path]);
      expect(controller.transfers.single.done, isTrue);
      // The batch leaves selection mode once it finishes.
      expect(controller.remoteSelectionMode, isFalse);
    });

    test(
      'a batch delete collects every failure instead of stopping at the first',
      () async {
        // The bug this guards against: a naive loop that lets the first
        // exception escape would leave the rest of the batch untouched, with
        // no way for the caller to learn what succeeded and what did not.
        final other = RemoteEntry(
          name: 'b.txt',
          path: '/b.txt',
          isDirectory: false,
          size: 1,
        );
        sftp.directories['/'] = [fileA, other];
        sftp.deleteFailPath = fileA.path;
        final controller = build();
        await controller.refreshRemote();
        controller.toggleRemoteSelectionMode();
        controller.toggleRemoteSelected(fileA.path);
        controller.toggleRemoteSelected(other.path);

        final failures = await controller.deleteSelectedRemote();

        // The failing entry is reported, but the other one still went
        // through — a naive loop that let the exception escape would have
        // stopped before ever attempting `other`.
        expect(failures, hasLength(1));
        expect(sftp.deletedPaths, [other.path]);
        expect(
          controller.remoteEntries.value?.map((e) => e.path),
          contains(fileA.path),
          reason: 'the entry that failed to delete must still be listed',
        );
      },
    );

    test('selectAllRemote selects files but not directories', () async {
      final controller = build();
      await controller.refreshRemote();
      controller.toggleRemoteSelectionMode();

      controller.selectAllRemote();

      expect(controller.remoteSelection, {fileA.path});
    });
  });

  group('cancelling a transfer', () {
    test('marks the job cancelled, not failed', () async {
      // The distinction the UI depends on: a cancelled row must not read
      // like something broke, so `error` stays null and `cancelled` alone
      // tells the story.
      sftp.downloadError = const SftpCancelledException();
      final controller = build();

      await controller.download(fileA);

      final job = controller.transfers.single;
      expect(job.done, isTrue);
      expect(job.cancelled, isTrue);
      expect(job.failed, isFalse);
      expect(job.error, isNull);
    });

    test('cancelTransfer calls the job\'s own cancel token', () async {
      final controller = build();
      // A download that hangs until told to stop, so there is a live job to
      // cancel when `cancelTransfer` runs.
      final gate = Completer<void>();
      sftp.downloadGate = gate.future;

      final future = controller.download(fileA);
      await Future<void>.delayed(Duration.zero);
      final job = controller.transfers.single;
      expect(job.canCancel, isTrue);

      controller.cancelTransfer(job.id);
      gate.complete();
      await future;

      expect(controller.transfers.single.cancelled, isTrue);
    });
  });

  group('chmod', () {
    test('chmodRemote applies the mode and refreshes the pane', () async {
      final controller = build();
      await controller.refreshRemote();

      await controller.chmodRemote(fileA, 0x1ED); // 755

      expect(sftp.chmodCalls[fileA.path], 0x1ED);
      final updated = controller.remoteEntries.value!.firstWhere(
        (e) => e.path == fileA.path,
      );
      expect(updated.permissions, 0x1ED);
    });
  });
}
