import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/domain/transfer_plan.dart';

/// The folder-transfer planner against an in-memory tree: what a walk turns
/// into, which entries it refuses to follow, and how a conflict choice
/// narrows the file list — all without a server or a filesystem.
void main() {
  WalkEntry file(String path, [int? size]) => WalkEntry(
    name: p.posix.basename(path),
    path: path,
    isDirectory: false,
    size: size,
  );
  WalkEntry dir(String path) =>
      WalkEntry(name: p.posix.basename(path), path: path, isDirectory: true);
  WalkEntry link(String path, {bool toDir = false}) => WalkEntry(
    name: p.posix.basename(path),
    path: path,
    isDirectory: toDir,
    isSymlink: true,
  );

  /// A lister over [tree] that records every path it was asked for, so a test
  /// can prove a symlinked or too-deep directory was never even opened.
  (DirectoryLister, List<String>) listerOf(Map<String, List<WalkEntry>> tree) {
    final calls = <String>[];
    Future<List<WalkEntry>> list(String path) async {
      calls.add(path);
      final entries = tree[path];
      if (entries == null) throw SftpException('missing $path');
      return entries;
    }

    return (list, calls);
  }

  Future<TransferPlan> plan(
    Map<String, List<WalkEntry>> tree, {
    String source = '/src',
    String target = '/dst',
    int maxDepth = kMaxTransferDepth,
    bool Function()? isCancelled,
  }) => planFolderTransfer(
    sourceRoot: source,
    targetRoot: target,
    listSource: listerOf(tree).$1,
    joinTarget: p.posix.join,
    maxDepth: maxDepth,
    isCancelled: isCancelled,
  );

  group('planFolderTransfer', () {
    test('turns a nested tree into directories and file copies', () async {
      final result = await plan({
        '/src': [dir('/src/lib'), file('/src/README.md', 10)],
        '/src/lib': [dir('/src/lib/util'), file('/src/lib/main.dart', 20)],
        '/src/lib/util': [file('/src/lib/util/x.dart', 5)],
      });

      // Parents strictly before children — the order they must be created.
      expect(result.directories.map((d) => d.target), [
        '/dst',
        '/dst/lib',
        '/dst/lib/util',
      ]);
      expect(result.directories.map((d) => d.parent), [
        null,
        '/dst',
        '/dst/lib',
      ]);
      expect(
        {for (final f in result.files) f.source: f.target},
        {
          '/src/lib/util/x.dart': '/dst/lib/util/x.dart',
          '/src/lib/main.dart': '/dst/lib/main.dart',
          '/src/README.md': '/dst/README.md',
        },
      );
      expect(result.totalBytes, 35);
      expect(result.skipped, 0);
    });

    test('an empty folder still plans its own directory', () async {
      final result = await plan({'/src': []});
      expect(result.directories.single.target, '/dst');
      expect(result.files, isEmpty);
    });

    test('symlinks are skipped, counted, and never followed', () async {
      final (lister, calls) = listerOf({
        '/src': [
          link('/src/loop', toDir: true),
          link('/src/shortcut.txt'),
          file('/src/real.txt', 1),
        ],
        // What following `loop` would have walked into.
        '/src/loop': [file('/src/loop/secret', 1)],
      });

      final result = await planFolderTransfer(
        sourceRoot: '/src',
        targetRoot: '/dst',
        listSource: lister,
        joinTarget: p.posix.join,
      );

      expect(result.files.map((f) => f.name), ['real.txt']);
      expect(result.skippedSymlinks, 2);
      expect(result.skipped, 2);
      expect(calls, ['/src'], reason: 'the linked directory must not be read');
    });

    test('directories past the depth limit are skipped and counted', () async {
      final (lister, calls) = listerOf({
        '/src': [dir('/src/a'), file('/src/top', 1)],
        '/src/a': [dir('/src/a/b'), file('/src/a/mid', 1)],
        '/src/a/b': [dir('/src/a/b/c'), file('/src/a/b/deep', 1)],
        '/src/a/b/c': [file('/src/a/b/c/too-deep', 1)],
      });

      final result = await planFolderTransfer(
        sourceRoot: '/src',
        targetRoot: '/dst',
        listSource: lister,
        joinTarget: p.posix.join,
        maxDepth: 2,
      );

      expect(result.files.map((f) => f.name), ['deep', 'mid', 'top']);
      expect(result.skippedTooDeep, 1);
      expect(calls, isNot(contains('/src/a/b/c')));
    });

    test('the default depth limit is finite and generous', () {
      expect(kMaxTransferDepth, greaterThanOrEqualTo(16));
      expect(kMaxTransferDepth, lessThanOrEqualTo(64));
    });

    test('a target with a different separator is joined with it', () async {
      final result = await planFolderTransfer(
        sourceRoot: '/src',
        targetRoot: r'C:\dst',
        listSource: listerOf({
          '/src': [file('/src/a.txt', 1)],
        }).$1,
        joinTarget: p.windows.join,
      );
      expect(result.files.single.target, r'C:\dst\a.txt');
    });

    test('cancelling stops the walk with SftpCancelledException', () async {
      await expectLater(
        plan({'/src': []}, isCancelled: () => true),
        throwsA(isA<SftpCancelledException>()),
      );
    });
  });

  group('conflicts', () {
    late TransferPlan tree;

    setUp(() async {
      tree = await plan({
        '/src': [dir('/src/sub'), file('/src/a.txt', 1), file('/src/b.txt', 2)],
        '/src/sub': [file('/src/sub/c.txt', 4)],
      });
    });

    test('a destination that does not exist costs one listing', () async {
      final (lister, calls) = listerOf({});
      final existing = await scanExistingNames(tree, lister);

      expect(existing, isEmpty);
      expect(calls, ['/dst'], reason: 'nothing under a missing folder exists');
      expect(findConflicts(tree, existing), isEmpty);
    });

    test('files already at the destination are found, per folder', () async {
      final (lister, _) = listerOf({
        '/dst': [file('/dst/a.txt'), file('/dst/unrelated')],
        '/dst/sub': [file('/dst/sub/c.txt')],
      });
      final existing = await scanExistingNames(tree, lister);

      expect(existing.keys, containsAll(['/dst', '/dst/sub']));
      expect(findConflicts(tree, existing).map((f) => f.target), [
        '/dst/sub/c.txt',
        '/dst/a.txt',
      ]);
    });

    test('overwrite keeps every file', () {
      final conflicts = [tree.files.first];
      expect(
        applyConflictChoice(tree, conflicts, ConflictChoice.overwrite),
        tree.files,
      );
    });

    test('skip existing drops exactly the conflicting files', () {
      final conflicts = tree.files.where((f) => f.name != 'b.txt').toList();
      final kept = applyConflictChoice(
        tree,
        conflicts,
        ConflictChoice.skipExisting,
      );
      expect(kept.map((f) => f.name), ['b.txt']);
      expect(TransferPlan.bytesOf(kept), 2);
    });

    test('cancel copies nothing', () {
      expect(
        applyConflictChoice(tree, [tree.files.first], ConflictChoice.cancel),
        isEmpty,
      );
    });
  });
}
