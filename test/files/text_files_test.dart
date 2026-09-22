import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/files/domain/text_files.dart';

void main() {
  test('config and source files are text', () {
    for (final name in [
      'nginx.conf',
      'app.YAML',
      'docker-compose.yml',
      'main.py',
      'notes.md',
      'Dockerfile',
      'authorized_keys',
      '.bashrc',
      '.env',
    ]) {
      expect(isLikelyTextFile(name), isTrue, reason: name);
    }
  });

  test('binaries, archives and unknown names are not', () {
    for (final name in ['photo.jpg', 'backup.tar.gz', 'a.out', 'data', 'x.']) {
      expect(isLikelyTextFile(name), isFalse, reason: name);
    }
  });
}
