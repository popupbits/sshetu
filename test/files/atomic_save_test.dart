import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/domain/atomic_save.dart';

import 'fake_sftp_service.dart';

void main() {
  late FakeSftpService sftp;
  const path = '/etc/app/app.conf';
  const temp = '/etc/app/.app.conf.sshetu-abc.tmp';
  final bytes = Uint8List.fromList(utf8.encode('new=1\n'));

  setUp(() {
    sftp = FakeSftpService();
    sftp.putFile(path, text: 'old=1\n', mode: 416); // 0640
  });

  Future<SaveMethod> save() async => saveRemoteFile(
    sftp,
    path,
    bytes,
    original: await sftp.stat(path),
    tempSuffix: () => 'abc',
  );

  test('temp file, same permissions, then rename over the original', () async {
    final original = await sftp.stat(path);
    sftp.fileOps.clear();
    final method = await saveRemoteFile(
      sftp,
      path,
      bytes,
      original: original,
      tempSuffix: () => 'abc',
    );

    expect(method, SaveMethod.atomic);
    expect(sftp.fileOps, [
      'lstat $path',
      'create $temp',
      'chmod $temp 640',
      'stat $temp',
      'rename $temp -> $path',
    ]);
    expect(sftp.textOf(path), 'new=1\n');
    expect(sftp.fileStats[path]!.permissions, 416);
    expect(sftp.files.containsKey(temp), isFalse);
  });

  test('no posix-rename: writes the original directly', () async {
    sftp.atomicRenameSupported = false;
    final original = await sftp.stat(path);
    sftp.fileOps.clear();
    final method = await saveRemoteFile(sftp, path, bytes, original: original);

    expect(method, SaveMethod.direct);
    expect(sftp.fileOps, ['write $path']);
    expect(sftp.textOf(path), 'new=1\n');
    expect(sftp.fileStats[path]!.permissions, 416);
  });

  test('a directory it cannot create files in: falls back', () async {
    sftp.failWriteFor = (p) => p == temp;
    expect(await save(), SaveMethod.direct);
    expect(sftp.textOf(path), 'new=1\n');
    expect(sftp.fileOps.last, 'write $path');
  });

  test('a failed rename removes the temp file, then falls back', () async {
    sftp.atomicRenameError = SftpException('Could not save: failure.');
    expect(await save(), SaveMethod.direct);
    expect(sftp.fileOps, contains('remove $temp'));
    expect(sftp.files.containsKey(temp), isFalse);
    expect(sftp.textOf(path), 'new=1\n');
  });

  test('a symlink is written through, never replaced', () async {
    sftp.symlinks.add(path);
    expect(await save(), SaveMethod.direct);
    expect(sftp.fileOps.where((op) => op.startsWith('create')), isEmpty);
    expect(sftp.symlinks, contains(path));
  });

  test('another owner: the temp file is given the same owner', () async {
    sftp.putFile(path, text: 'old', uid: 0, gid: 33);
    expect(await save(), SaveMethod.atomic);
    expect(sftp.fileOps, contains('chown $temp 0:33'));
    expect(sftp.fileStats[path]!.userId, 0);
    expect(sftp.fileStats[path]!.groupId, 33);
  });

  test('another owner that cannot be copied: direct, temp removed', () async {
    sftp
      ..putFile(path, text: 'old', uid: 0, gid: 33)
      ..setOwnerRefused = true;
    expect(await save(), SaveMethod.direct);
    expect(sftp.files.containsKey(temp), isFalse);
    // Written in place, so the owner never changed.
    expect(sftp.fileStats[path]!.userId, 0);
    expect(sftp.textOf(path), 'new=1\n');
  });

  test('a file deleted since loading is recreated atomically', () async {
    final original = await sftp.stat(path);
    await sftp.removeFile(path);
    final method = await saveRemoteFile(
      sftp,
      path,
      bytes,
      original: original,
      tempSuffix: () => 'abc',
    );
    expect(method, SaveMethod.atomic);
    expect(sftp.textOf(path), 'new=1\n');
  });

  test(
    'when even the direct write fails, the error reaches the caller',
    () async {
      sftp
        ..atomicRenameSupported = false
        ..failWriteFor = (_) => true;
      await expectLater(save(), throwsA(isA<SftpException>()));
    },
  );

  test('tempPathFor is hidden and beside the original', () {
    expect(tempPathFor('/a/b.txt', 'x1'), '/a/.b.txt.sshetu-x1.tmp');
    expect(tempPathFor('/b.txt', 'x1'), '/.b.txt.sshetu-x1.tmp');
  });
}
