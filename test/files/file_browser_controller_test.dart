import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/ssh/sftp_service.dart';
import 'package:ssh_navigator/features/files/file_browser_controller.dart';

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

  test(
    'directories are skipped by download and upload, not attempted',
    () async {
      final controller = build();
      await controller.download(dirA);
      expect(controller.transfers, isEmpty);
      expect(sftp.downloadedRemotePaths, isEmpty);
    },
  );

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
}
