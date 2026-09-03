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

  File write(String name, String contents, {int? mode}) {
    final file = File('${dir.path}/$name')..writeAsStringSync(contents);
    if (mode != null) {
      Process.runSync('chmod', [mode.toRadixString(8), file.path]);
    }
    return file;
  }

  test('ssh-keygen reads the private key we wrote', () {
    final key = SshKeyGenerator.ed25519(comment: 'dlohani@sshetu');
    final file = write('id_ed25519', key.privateKey, mode: 0x180); // 0600

    final result = Process.runSync('ssh-keygen', ['-y', '-f', file.path]);

    expect(
      result.exitCode,
      0,
      reason: 'ssh-keygen refused it: ${result.stderr}',
    );
    // -y prints the public key derived from the private half. It matching
    // ours proves the two halves belong together, which a hand-written
    // encoder can very easily get wrong while still producing a valid file.
    expect(
      (result.stdout as String).trim().split(' ').take(2).join(' '),
      key.publicKey.split(' ').take(2).join(' '),
    );
  });

  test('the fingerprint matches what ssh-keygen prints', () {
    // The string a user compares by eye against their server. If ours is
    // computed differently, every comparison they make is meaningless.
    final key = SshKeyGenerator.ed25519(comment: 'test');
    final file = write('id_ed25519.pub', key.publicKey);

    final result = Process.runSync('ssh-keygen', ['-lf', file.path]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect((result.stdout as String), contains(key.fingerprint));
  });

  test('every key is a different key', () {
    // A generator seeded wrongly — a fixed seed, a clock, a broken RNG —
    // produces files that all look fine and are all the same key.
    final keys = List.generate(8, (_) => SshKeyGenerator.ed25519());
    expect(keys.map((k) => k.fingerprint).toSet(), hasLength(8));
  });

  test('a key with no comment is still valid', () {
    final key = SshKeyGenerator.ed25519();
    final file = write('id_ed25519', key.privateKey, mode: 0x180);

    final result = Process.runSync('ssh-keygen', ['-y', '-f', file.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });
}
