import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
