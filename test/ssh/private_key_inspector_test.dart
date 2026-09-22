import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/key_generator.dart';
import 'package:sshetu/core/ssh/private_key_inspector.dart';

import 'fixtures/pasted_keys.dart';

/// Pasted keys: what is accepted, what is refused, and why.
void main() {
  String firstTwo(String line) => line.split(' ').take(2).join(' ');

  late PastedKey rsaPlain;
  late PastedKey rsaEnc;
  late PastedKey ecPlain;
  late PastedKey edEnc;

  setUpAll(() {
    rsaPlain = pkcs1Rsa();
    rsaEnc = pkcs1Rsa(passphrase: fixturePassphrase);
    ecPlain = sec1Ec();
    edEnc = encryptedOpenSsh();
  });

  group('accepts', () {
    test('an OpenSSH key, and derives its public half', () {
      final generated = SshKeyGenerator.ed25519(comment: 'laptop');
      final result = inspectPrivateKey(generated.privateKey);

      expect(result.isOk, isTrue, reason: '$result');
      final key = result.key!;
      expect(key.keyType, 'ssh-ed25519');
      expect(key.publicKey, generated.publicKey);
      expect(key.fingerprint, generated.fingerprint);
      expect(key.comment, 'laptop');
      expect(key.isEncrypted, isFalse);
      // Stored as pasted: dartssh2 must read back exactly what we keep.
      expect(key.pem.trim(), generated.privateKey.trim());
      expect(SSHKeyPair.fromPem(key.pem), hasLength(1));
    });

    test('ECDSA keys too', () {
      final generated = SshKeyGenerator.generate(SshKeyType.ecdsaP384);
      final result = inspectPrivateKey(generated.privateKey);
      expect(result.key?.keyType, 'ecdsa-sha2-nistp384');
      expect(result.key?.fingerprint, generated.fingerprint);
    });

    test('a PEM RSA key (PKCS#1)', () {
      final result = inspectPrivateKey(rsaPlain.pem);
      expect(result.isOk, isTrue, reason: '$result');
      expect(result.key!.keyType, 'ssh-rsa');
      expect(firstTwo(result.key!.publicKey), rsaPlain.publicKey);
    });

    test('a PEM EC key (SEC1)', () {
      final result = inspectPrivateKey(ecPlain.pem);
      expect(result.isOk, isTrue, reason: '$result');
      expect(result.key!.keyType, 'ecdsa-sha2-nistp256');
      expect(firstTwo(result.key!.publicKey), ecPlain.publicKey);
    });

    test('Windows line endings and surrounding noise', () {
      final generated = SshKeyGenerator.ed25519();
      final pasted =
          '\$ cat ~/.ssh/id_ed25519\r\n'
          '${generated.privateKey.replaceAll('\n', '\r\n')}\r\n\$ ';
      final result = inspectPrivateKey(pasted);
      expect(result.key?.fingerprint, generated.fingerprint);
      expect(result.key!.pem, isNot(contains('\r')));
      expect(result.key!.pem, isNot(contains('cat ')));
    });

    test('a key whose newlines were flattened into spaces', () {
      final generated = SshKeyGenerator.ed25519();
      final flattened = generated.privateKey.trim().replaceAll('\n', ' ');
      final result = inspectPrivateKey(flattened);
      expect(result.key?.fingerprint, generated.fingerprint);
      expect(SSHKeyPair.fromPem(result.key!.pem), hasLength(1));
    });
  });

  group('encrypted', () {
    test('an encrypted OpenSSH key asks for its passphrase first', () {
      final result = inspectPrivateKey(edEnc.pem);
      expect(result.problem, KeyProblem.needsPassphrase);
      // The type is in the clear, so the prompt can say what it unlocks.
      expect(result.keyType, 'ssh-ed25519');
    });

    test('opens with the right passphrase and stays encrypted', () {
      final result = inspectPrivateKey(
        edEnc.pem,
        passphrase: fixturePassphrase,
      );
      expect(result.isOk, isTrue, reason: '$result');
      final key = result.key!;
      expect(key.isEncrypted, isTrue);
      expect(firstTwo(key.publicKey), edEnc.publicKey);
      expect(key.comment, 'fixture@test');
      // What is stored is still the sealed key, not a decrypted copy.
      expect(SSHKeyPair.isEncryptedPem(key.pem), isTrue);
      expect(key.pem.trim(), edEnc.pem.trim());
    });

    test('refuses a wrong passphrase', () {
      final result = inspectPrivateKey(edEnc.pem, passphrase: 'nope');
      expect(result.problem, KeyProblem.wrongPassphrase);
    });

    test('a passphrase-protected PEM RSA key, right and wrong', () {
      expect(inspectPrivateKey(rsaEnc.pem).problem, KeyProblem.needsPassphrase);
      final ok = inspectPrivateKey(rsaEnc.pem, passphrase: fixturePassphrase);
      expect(ok.isOk, isTrue, reason: '$ok');
      expect(ok.key!.isEncrypted, isTrue);
      expect(firstTwo(ok.key!.publicKey), rsaEnc.publicKey);

      expect(
        inspectPrivateKey(rsaEnc.pem, passphrase: 'wrong').problem,
        KeyProblem.wrongPassphrase,
      );
    });

    test('a key this app generated with a passphrase', () {
      final generated = SshKeyGenerator.generate(
        SshKeyType.ecdsaP256,
        passphrase: 'mine',
        rounds: 2,
      );
      expect(
        inspectPrivateKey(
          generated.privateKey,
          passphrase: 'mine',
        ).key?.fingerprint,
        generated.fingerprint,
      );
    });

    test('in the background, too', () async {
      final result = await inspectPrivateKeyInBackground(
        edEnc.pem,
        passphrase: fixturePassphrase,
      );
      expect(result.isOk, isTrue);
    });
  });

  group('rejects', () {
    test('nothing', () {
      expect(inspectPrivateKey('  \n ').problem, KeyProblem.empty);
    });

    test('a public key pasted by mistake', () {
      final generated = SshKeyGenerator.ed25519(comment: 'me');
      for (final text in [
        generated.publicKey,
        rsaPlain.publicKey,
        ecPlain.publicKey,
        'no-pty,from="10.0.0.1" ${generated.publicKey}',
        '---- BEGIN SSH2 PUBLIC KEY ----\nAAAA\n---- END SSH2 PUBLIC KEY ----',
        '-----BEGIN PUBLIC KEY-----\nMIIB\n-----END PUBLIC KEY-----',
      ]) {
        expect(
          inspectPrivateKey(text).problem,
          KeyProblem.publicKey,
          reason: text,
        );
      }
    });

    test('garbage', () {
      for (final text in [
        'hunter2',
        'ssh-ed25519',
        '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----',
      ]) {
        expect(inspectPrivateKey(text).problem, KeyProblem.notAKey);
      }
    });

    test('a truncated key', () {
      final lines = SshKeyGenerator.ed25519().privateKey.trim().split('\n');
      lines.removeAt(2);
      expect(inspectPrivateKey(lines.join('\n')).problem, KeyProblem.damaged);
    });

    test('formats the client cannot use', () {
      expect(inspectPrivateKey(pkcs8Pem).problem, KeyProblem.unsupportedFormat);
      expect(
        inspectPrivateKey(
          'PuTTY-User-Key-File-3: ssh-ed25519\nEncryption: none\n',
        ).problem,
        KeyProblem.unsupportedFormat,
      );
    });

    test('never quotes the key back', () {
      final lines = SshKeyGenerator.ed25519().privateKey.trim().split('\n');
      final secretLine = lines[2];
      lines.removeAt(3);
      final result = inspectPrivateKey(lines.join('\n'));
      expect('$result', isNot(contains(secretLine)));
      expect('${inspectPrivateKey(rsaPlain.pem)}', isNot(contains('MII')));
    });
  });
}
