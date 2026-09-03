import 'package:flutter_test/flutter_test.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/features/files/domain/file_icons.dart';

void main() {
  test('a directory always gets the folder icon, extension or not', () {
    // The bug this guards against: a directory named "archive.zip" is a
    // directory, and looking up its "extension" before checking
    // `isDirectory` would show an archive icon on a folder.
    expect(
      fileIcon(isDirectory: true, name: 'archive.zip'),
      PiconsRegular.folder,
    );
  });

  test('a known extension resolves to its mapped icon', () {
    expect(
      fileIcon(isDirectory: false, name: 'photo.png'),
      PiconsRegular.fileImage,
    );
    expect(
      fileIcon(isDirectory: false, name: 'archive.zip'),
      PiconsRegular.fileZip,
    );
    expect(
      fileIcon(isDirectory: false, name: 'main.dart'),
      PiconsRegular.fileCode,
    );
  });

  test('lookup is case-insensitive', () {
    expect(
      fileIcon(isDirectory: false, name: 'PHOTO.PNG'),
      PiconsRegular.fileImage,
    );
  });

  test('an unrecognised extension falls back to the generic file icon', () {
    // The bug this guards against: an unmapped extension must not fall
    // through to whatever the last table entry happened to be — it gets the
    // deliberate default, not an accidental one.
    expect(
      fileIcon(isDirectory: false, name: 'data.xyz123'),
      PiconsRegular.file,
    );
  });

  test('no extension at all falls back to the generic file icon', () {
    expect(fileIcon(isDirectory: false, name: 'README'), PiconsRegular.file);
  });

  test('a dotfile with no further extension is not treated as one', () {
    // The bug this guards against: `lastIndexOf('.')` on ".bashrc" returns 0,
    // and naively substringing from `dot + 1` would look up "bashrc" as if
    // it were an extension named after the whole file.
    expect(fileIcon(isDirectory: false, name: '.bashrc'), PiconsRegular.file);
  });

  test('a dotfile that does have an extension still resolves it', () {
    expect(
      fileIcon(isDirectory: false, name: '.env.json'),
      PiconsRegular.fileCode,
    );
  });
}
