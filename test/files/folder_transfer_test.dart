import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/data/local_fs_service.dart';
import 'package:sshetu/features/files/domain/transfer_plan.dart';
import 'package:sshetu/features/files/file_browser_controller.dart';
import 'package:sshetu/features/files/widgets/transfer_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_sftp_service.dart';

/// Whole-folder downloads and uploads through the controller: one job, sums
/// across files, symlinks left alone, cancel keeping what finished, and the
/// conflict question asked once.
void main() {
  late Directory localRoot;
  late FakeSftpService sftp;
  late List<Object> recorded;

  const project = RemoteEntry(
    name: 'project',
    path: '/project',
    isDirectory: true,
  );

  setUp(() async {
    localRoot = await Directory.systemTemp.createTemp('folder_transfer_test');
    recorded = [];
    sftp = FakeSftpService(
      directories: {
        '/': [project],
        '/project': [
          const RemoteEntry(
            name: 'lib',
            path: '/project/lib',
            isDirectory: true,
          ),
          const RemoteEntry(
            name: 'README.md',
            path: '/project/README.md',
            isDirectory: false,
            size: 10,
          ),
          const RemoteEntry(
            name: 'current',
            path: '/project/current',
            isDirectory: false,
            isSymlink: true,
          ),
        ],
        '/project/lib': [
          const RemoteEntry(
            name: 'main.dart',
            path: '/project/lib/main.dart',
            isDirectory: false,
            size: 10,
          ),
          const RemoteEntry(
            name: 'util.dart',
            path: '/project/lib/util.dart',
            isDirectory: false,
            size: 10,
          ),
        ],
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
      recordError: (error, _) => recorded.add(error),
    );
    addTearDown(controller.dispose);
    await controller.refreshRemote();
    await controller.refreshLocal();
    return controller;
  }

  String local(String relative) =>
      p.joinAll([localRoot.path, ...relative.split('/')]);

  group('folder download', () {
    test('copies the tree as one job, skipping the symlink', () async {
      final controller = await build();

      await controller.download(project);

      expect(File(local('project/README.md')).existsSync(), isTrue);
      expect(File(local('project/lib/main.dart')).existsSync(), isTrue);
      expect(File(local('project/lib/util.dart')).existsSync(), isTrue);
      expect(File(local('project/current')).existsSync(), isFalse);
      expect(sftp.downloadedRemotePaths, isNot(contains('/project/current')));

      final job = controller.transfers.single;
      expect(job.isFolder, isTrue);
      expect(job.done, isTrue);
      expect(job.failed, isFalse);
      expect(job.filesTotal, 3);
      expect(job.filesDone, 3);
      expect(job.skipped, 1);
      expect(job.total, 30);
      expect(job.transferred, 30);
      // The local pane shows the new folder without a manual refresh.
      expect(
        controller.localEntries.value!.map((e) => e.name),
        contains('project'),
      );
    });

    test('progress is summed across files, not reset per file', () async {
      final controller = await build();
      final seen = <int>[];
      controller.addListener(() {
        final jobs = controller.transfers;
        if (jobs.isNotEmpty) seen.add(jobs.single.transferred);
      });

      await controller.download(project);

      // Never goes backwards — each file's bytes add to the running total.
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
      expect(seen.last, 30);
    });

    test(
      'cancel stops at the file in flight and keeps finished files',
      () async {
        final controller = await build();
        var calls = 0;
        sftp.beforeDownload = (path) async {
          calls++;
          // Cancel while the second file is starting; the fake then sees the
          // token and stops before writing, as the real service discards a
          // partial download.
          if (calls == 2) {
            controller.cancelTransfer(controller.transfers.single.id);
          }
        };

        await controller.download(project);

        final job = controller.transfers.single;
        expect(job.cancelled, isTrue);
        expect(job.failed, isFalse);
        expect(job.filesDone, 1);
        expect(job.filesTotal, 3);
        expect(calls, 2, reason: 'nothing after the cancelled file starts');

        final firstTarget = sftp.downloadedRemotePaths.first;
        final second = sftp.downloadedRemotePaths[1];
        String targetOf(String remote) =>
            local(remote.substring(1)); // '/project/x' -> 'project/x'
        expect(File(targetOf(firstTarget)).existsSync(), isTrue);
        expect(File(targetOf(second)).existsSync(), isFalse);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          folderStatusLine(l10n, job),
          contains('1 of 3 files transferred'),
        );
      },
    );

    test(
      'a failed file stops the job with its message and the count',
      () async {
        final controller = await build();
        sftp.beforeDownload = (path) async {
          if (path.endsWith('util.dart')) {
            throw SftpException('Could not download util.dart: failure.');
          }
        };

        await controller.download(project);

        final job = controller.transfers.single;
        expect(job.failed, isTrue);
        expect(job.error, 'Could not download util.dart: failure.');
        expect(job.filesDone, lessThan(3));
        expect(recorded, isEmpty, reason: 'an SftpException is expected');
      },
    );

    test('an unexpected error is recorded for diagnostics', () async {
      final controller = await build();
      sftp.beforeDownload = (_) async => throw StateError('bug');

      await controller.download(project);

      expect(controller.transfers.single.failed, isTrue);
      expect(recorded.single, isA<StateError>());
    });
  });

  group('conflicts', () {
    Future<void> seedExisting() async {
      await Directory(local('project/lib')).create(recursive: true);
      await File(local('project/lib/main.dart')).writeAsString('mine');
    }

    test('are asked about once, with the count', () async {
      await seedExisting();
      await File(local('project/README.md')).writeAsString('mine too');
      final controller = await build();
      final asked = <(String, int)>[];

      await controller.download(
        project,
        onConflict: (name, count) async {
          asked.add((name, count));
          return ConflictChoice.skipExisting;
        },
      );

      expect(asked, [('project', 2)]);
    });

    test('are not asked about when there are none', () async {
      final controller = await build();
      var asked = false;

      await controller.download(
        project,
        onConflict: (_, _) async {
          asked = true;
          return ConflictChoice.overwrite;
        },
      );

      expect(asked, isFalse);
      expect(controller.transfers.single.filesDone, 3);
    });

    test('skip existing leaves those files untouched', () async {
      await seedExisting();
      final controller = await build();

      await controller.download(
        project,
        onConflict: (_, _) async => ConflictChoice.skipExisting,
      );

      expect(File(local('project/lib/main.dart')).readAsStringSync(), 'mine');
      expect(
        sftp.downloadedRemotePaths,
        isNot(contains('/project/lib/main.dart')),
      );
      final job = controller.transfers.single;
      expect(job.done && !job.failed && !job.cancelled, isTrue);
      expect(job.filesTotal, 2);
      expect(job.skippedExisting, 1);
      expect(job.total, 20);
    });

    test('overwrite replaces them', () async {
      await seedExisting();
      final controller = await build();

      await controller.download(
        project,
        onConflict: (_, _) async => ConflictChoice.overwrite,
      );

      expect(
        File(local('project/lib/main.dart')).readAsStringSync(),
        'downloaded',
      );
      expect(controller.transfers.single.filesDone, 3);
    });

    test('cancel copies nothing and marks the job cancelled', () async {
      await seedExisting();
      final controller = await build();

      await controller.download(
        project,
        onConflict: (_, _) async => ConflictChoice.cancel,
      );

      expect(sftp.downloadedRemotePaths, isEmpty);
      final job = controller.transfers.single;
      expect(job.cancelled, isTrue);
      expect(job.filesDone, 0);
      expect(job.filesTotal, 3);
    });

    test(
      'without a resolver, existing files are skipped, not overwritten',
      () async {
        await seedExisting();
        final controller = await build();

        await controller.download(project);

        expect(File(local('project/lib/main.dart')).readAsStringSync(), 'mine');
      },
    );
  });

  group('folder upload', () {
    Future<LocalEntry> seedLocalTree() async {
      await Directory(local('site/assets')).create(recursive: true);
      await File(local('site/index.html')).writeAsString('<html>');
      await File(local('site/assets/app.css')).writeAsString('body{}');
      final controller = FileBrowserController(
        sftp: sftp,
        localRoot: localRoot.path,
      );
      addTearDown(controller.dispose);
      await controller.refreshLocal();
      return controller.localEntries.value!.single;
    }

    test('creates the folders and uploads every file', () async {
      sftp.missingDirectoriesFail = true;
      final site = await seedLocalTree();
      final controller = await build();

      await controller.upload(site);

      expect(sftp.mkdirPaths, ['/site', '/site/assets']);
      expect(sftp.uploadedRemotePaths.toSet(), {
        '/site/index.html',
        '/site/assets/app.css',
      });
      final job = controller.transfers.single;
      expect(job.isFolder, isTrue);
      expect(job.done && !job.failed, isTrue);
      expect(job.filesDone, 2);
      expect(
        controller.remoteEntries.value!.map((e) => e.name),
        contains('site'),
      );
    });

    test('merges into a remote folder that already exists', () async {
      sftp
        ..missingDirectoriesFail = true
        ..directories['/site'] = [
          const RemoteEntry(
            name: 'index.html',
            path: '/site/index.html',
            isDirectory: false,
            size: 1,
          ),
        ];
      final site = await seedLocalTree();
      final controller = await build();
      final asked = <int>[];

      await controller.upload(
        site,
        onConflict: (_, count) async {
          asked.add(count);
          return ConflictChoice.overwrite;
        },
      );

      expect(asked, [1]);
      expect(sftp.mkdirPaths, ['/site/assets']);
      expect(sftp.uploadedRemotePaths, contains('/site/index.html'));
      expect(controller.transfers.single.failed, isFalse);
    });
  });
}
