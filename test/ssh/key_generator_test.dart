@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/key_generator.dart';

/// Generated keys, checked against OpenSSH itself.
///
/// A key format is not something to be confident about. `openssh-key-v1` is a
/// container with lengths, a block-padded inner section and a check-int pair,
/// and every one of those is a silent failure: `ssh-keygen` says "invalid
/// format" and a server says "permission denied", neither of which tells you
/// which byte is wrong. So the test is not "does it look right" — it is
/// whether the tools that will actually read this file accept it.
///
/// Tagged `live` because it shells out to the real ssh-keygen.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('sshetu-keygen'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, String contents, {bool private = false}) {
    final file = File('${dir.path}/$name')..writeAsStringSync(contents);
    if (!private) return file;
    if (Platform.isWindows) {
      // Windows OpenSSH gates on the ACL, not mode bits, and refuses a key
      // any other principal can read. A temp directory inherits whatever
      // its parent grants — on this machine a sandbox group — so inheritance
      // is cut and only the current user is left. The check ssh-keygen makes
      // is unchanged; the file is simply made as private as a real key is.
      final user = Platform.environment['USERNAME'];
      final result = Process.runSync('icacls', [
        file.path,
        '/inheritance:r',
        '/grant:r',
        '$user:F',
      ]);
      expect(result.exitCode, 0, reason: 'icacls: ${result.stdout}');
    } else {
      Process.runSync('chmod', ['600', file.path]);
    }
    return file;
  }

  String firstTwo(String line) => line.trim().split(' ').take(2).join(' ');

  for (final type in SshKeyType.values) {
    test('ssh-keygen reads the ${type.name} private key we wrote', () {
      final key = SshKeyGenerator.generate(type, comment: 'dlohani@sshetu');
      final file = write('id_${type.name}', key.privateKey, private: true);

      final result = Process.runSync('ssh-keygen', ['-y', '-f', file.path]);

      expect(
        result.exitCode,
        0,
        reason: 'ssh-keygen refused it: ${result.stderr}',
      );
      // -y prints the public key derived from the private half. It matching
      // ours proves the two halves belong together, which a hand-written
      // encoder can very easily get wrong while still producing a valid file.
      expect(firstTwo(result.stdout as String), firstTwo(key.publicKey));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('ssh-keygen opens a passphrase-protected key with the passphrase', () {
    final key = SshKeyGenerator.generate(
      SshKeyType.ed25519,
      comment: 'sealed',
      passphrase: 'correct horse',
    );
    final file = write('id_sealed', key.privateKey, private: true);

    final right = Process.runSync('ssh-keygen', [
      '-y',
      '-P',
      'correct horse',
      '-f',
      file.path,
    ]);
    expect(right.exitCode, 0, reason: 'refused: ${right.stderr}');
    expect(firstTwo(right.stdout as String), firstTwo(key.publicKey));

    // And it really is sealed: the wrong passphrase must not open it.
    final wrong = Process.runSync('ssh-keygen', [
      '-y',
      '-P',
      'battery staple',
      '-f',
      file.path,
    ]);
    expect(wrong.exitCode, isNot(0));
  });

  test('ssh-keygen opens a passphrase-protected ECDSA key too', () {
    final key = SshKeyGenerator.generate(
      SshKeyType.ecdsaP384,
      passphrase: 'p384',
    );
    final file = write('id_sealed_ec', key.privateKey, private: true);
    final result = Process.runSync('ssh-keygen', [
      '-y',
      '-P',
      'p384',
      '-f',
      file.path,
    ]);
    expect(result.exitCode, 0, reason: 'refused: ${result.stderr}');
    expect(firstTwo(result.stdout as String), firstTwo(key.publicKey));
  });

  test('the fingerprint matches what ssh-keygen prints', () {
    // The string a user compares by eye against their server. If ours is
    // computed differently, every comparison they make is meaningless.
    for (final type in [SshKeyType.ed25519, SshKeyType.ecdsaP256]) {
      final key = SshKeyGenerator.generate(type, comment: 'test');
      final file = write('${type.name}.pub', key.publicKey);

      final result = Process.runSync('ssh-keygen', ['-lf', file.path]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect((result.stdout as String), contains(key.fingerprint));
    }
  });

  test('a key with no comment is still valid', () {
    final key = SshKeyGenerator.ed25519();
    final file = write('id_ed25519', key.privateKey, private: true);

    final result = Process.runSync('ssh-keygen', ['-y', '-f', file.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });
}
