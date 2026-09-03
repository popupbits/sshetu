import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ssh_navigator/features/files/data/local_fs_service.dart';

/// Against a real temporary directory, the same way
/// `test/import/import_controller_test.dart` exercises real files on disk —
/// `dart:io` behaves the same in a `flutter test` run as it does in the app,
/// so there is nothing a fake would catch that the real filesystem would not.
void main() {
  late Directory root;
  const service = LocalFsService();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('local_fs_service_test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('lists files and directories, sorted directories-first', () async {
    await File('${root.path}/notes.txt').writeAsString('hi');
    await Directory('${root.path}/Archive').create();

    final entries = await service.list(root.path);

    expect(entries.map((e) => e.name), ['Archive', 'notes.txt']);
    expect(entries.first.isDirectory, isTrue);
    expect(entries.last.isDirectory, isFalse);
  });

  test('reports a file size but leaves a directory size null', () async {
    await File('${root.path}/data.bin').writeAsBytes(List.filled(128, 0));
    await Directory('${root.path}/sub').create();

    final entries = await service.list(root.path);

    final file = entries.firstWhere((e) => e.name == 'data.bin');
    final dir = entries.firstWhere((e) => e.name == 'sub');
    expect(file.size, 128);
    expect(dir.size, isNull);
  });

  test(
    'reading a directory that does not exist throws LocalFsException',
    () async {
      // The bug this guards against: a raw FileSystemException reaching the UI
      // would show a path and an errno the user cannot act on.
      await expectLater(
        service.list('${root.path}/does-not-exist'),
        throwsA(isA<LocalFsException>()),
      );
    },
  );

  test('delete removes a file from disk', () async {
    final file = File('${root.path}/gone.txt');
    await file.writeAsString('bye');
    final entries = await service.list(root.path);

    await service.delete(entries.single);

    expect(file.existsSync(), isFalse);
  });

  test(
    'deleting a non-empty directory reports why, not a bare failure',
    () async {
      // The bug this guards against: `Directory.delete()` without
      // `recursive: true` throws ENOTEMPTY, and an un-wrapped
      // FileSystemException reaching the UI would show a raw errno instead
      // of a sentence a user can act on.
      final dir = Directory('${root.path}/not-empty')..createSync();
      await File('${dir.path}/inside.txt').writeAsString('x');
      final entries = await service.list(root.path);

      await expectLater(
        service.delete(entries.single),
        throwsA(
          isA<LocalFsException>().having(
            (e) => e.message,
            'message',
            contains('Could not delete'),
          ),
        ),
      );
    },
    // ENOTEMPTY is POSIX; Windows reports the same *situation* under a
    // different errno this test does not attempt to pin.
    skip: Platform.isWindows ? 'POSIX-specific errno' : null,
  );

  group('resolveLocalPath', () {
    test('~ alone expands to the home directory', () {
      expect(
        service.resolveLocalPath('~', homeDir: '/Users/test'),
        '/Users/test',
      );
    });

    test('~/rest expands under the home directory', () {
      // The bug this guards against: naive substring handling of "~/x"
      // could either drop the leading slash (producing "/Users/testx") or
      // keep a doubled one ("/Users/test//x") — either reads as a different,
      // wrong path.
      expect(
        service.resolveLocalPath('~/Documents', homeDir: '/Users/test'),
        p.join('/Users/test', 'Documents'),
      );
    });

    test('an already-absolute path passes through unchanged', () {
      expect(
        service.resolveLocalPath('/etc/hosts', homeDir: '/Users/test'),
        '/etc/hosts',
      );
    });
  });

  group('statPath', () {
    test('an existing directory reports LocalPathKind.directory', () async {
      expect(await service.statPath(root.path), LocalPathKind.directory);
    });

    test('an existing file reports LocalPathKind.file', () async {
      final file = File('${root.path}/a.txt');
      await file.writeAsString('x');
      expect(await service.statPath(file.path), LocalPathKind.file);
    });

    test('a path that does not exist reports LocalPathKind.missing', () async {
      // The bug this guards against: the path-entry field needs to tell
      // "not found" apart from "that's a file" *before* trying to open it as
      // a directory, and both have to come from one clean stat rather than
      // parsing a thrown exception's text.
      expect(
        await service.statPath('${root.path}/does-not-exist'),
        LocalPathKind.missing,
      );
    });
  });

  test(
    'a directory this process cannot read reports LocalFsFailureKind.permissionDenied',
    () async {
      // The bug this guards against: a permission failure surfacing as the
      // same generic "other" state as a vanished directory or a full disk —
      // three situations the file browser needs to render differently must
      // not collapse into one because the wrapper did not bother to look at
      // errno.
      final locked = Directory('${root.path}/locked')..createSync();
      await Process.run('chmod', ['000', locked.path]);
      addTearDown(() => Process.runSync('chmod', ['755', locked.path]));

      await expectLater(
        service.list(locked.path),
        throwsA(
          isA<LocalFsException>().having(
            (e) => e.kind,
            'kind',
            LocalFsFailureKind.permissionDenied,
          ),
        ),
      );
    },
    // Root (common in a CI container) ignores directory permission bits
    // entirely, so this assertion cannot hold there — this is a property of
    // the account running the test, not of the code under test.
    skip: Platform.isWindows
        ? 'POSIX-specific errno'
        : (Platform.environment['USER'] == 'root'
              ? 'root ignores permission bits'
              : null),
  );
}
