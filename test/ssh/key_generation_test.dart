import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/key_generator.dart';

/// Every key type the generator offers, read back by the client that has to
/// use it.
///
/// "Parses" is not the bar. A key dartssh2 can decode but not sign with, or
/// one whose public line belongs to a different private half, passes a
/// format check and fails at the server with "permission denied" — so each
/// key here is decoded, its public half compared byte for byte, and a
/// signature made with it verified against the public key we would install.
void main() {
  final fingerprintShape = RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$');

  Uint8List blobOf(String publicLine) =>
      base64.decode(publicLine.split(' ')[1]);

  void expectUsable(GeneratedKey key, {String? passphrase}) {
    final pairs = SSHKeyPair.fromPem(key.privateKey, passphrase);
    expect(pairs, hasLength(1));
    final pair = pairs.single;

    expect(pair.name, key.keyType);
    expect(key.publicKey.split(' ').first, key.keyType);
    expect(
      pair.toPublicKey().encode(),
      blobOf(key.publicKey),
      reason: 'the public line must belong to this private key',
    );
    expect(key.fingerprint, matches(fingerprintShape));
    expect(
      key.fingerprint,
      SshKeyGenerator.fingerprintOfBlob(blobOf(key.publicKey)),
    );

    // The client authenticates by signing; the server checks with the public
    // key from authorized_keys. Do exactly that.
    final data = Uint8List.fromList(utf8.encode('session identifier'));
    final signature = pair.sign(data);
    // dartssh2 does not export its concrete public-key classes, but every
    // one of them has `verify(message, signature)` — the call its own server
    // side makes. Dynamic rather than a src/ import.
    final dynamic public = pair.toPublicKey();
    expect(
      public.verify(data, signature) as bool,
      isTrue,
      reason: 'signature must verify',
    );
  }

  group('each type', () {
    for (final type in [
      SshKeyType.ed25519,
      SshKeyType.ecdsaP256,
      SshKeyType.ecdsaP384,
    ]) {
      test('${type.name} generates a key dartssh2 can sign with', () {
        final key = SshKeyGenerator.generate(type, comment: 'me@phone');
        expect(key.isEncrypted, isFalse);
        expect(key.publicKey, endsWith(' me@phone'));
        expect(
          key.privateKey,
          startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
        );
        expectUsable(key);
      });
    }

    test('ECDSA keys carry the right curve', () {
      final p256 = SshKeyGenerator.generate(SshKeyType.ecdsaP256);
      final p384 = SshKeyGenerator.generate(SshKeyType.ecdsaP384);
      expect(p256.keyType, 'ecdsa-sha2-nistp256');
      expect(p384.keyType, 'ecdsa-sha2-nistp384');
      // 0x04 || X || Y: 65 bytes on P-256, 97 on P-384.
      final p256Pair =
          SSHKeyPair.fromPem(p256.privateKey).single as OpenSSHEcdsaKeyPair;
      final p384Pair =
          SSHKeyPair.fromPem(p384.privateKey).single as OpenSSHEcdsaKeyPair;
      expect(p256Pair.q, hasLength(65));
      expect(p384Pair.q, hasLength(97));
    });

    test('RSA 3072, off the UI isolate', () async {
      final key = await SshKeyGenerator.generateInBackground(
        SshKeyType.rsa3072,
        comment: 'rsa',
      );
      expect(key.keyType, 'ssh-rsa');
      final pair =
          SSHKeyPair.fromPem(key.privateKey).single as OpenSSHRsaKeyPair;
      expect(pair.n.bitLength, 3072);
      expect(pair.e, BigInt.from(65537));
      expect((pair.q * pair.iqmp) % pair.p, BigInt.one);
      expectUsable(key);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('RSA 4096, off the UI isolate', () async {
      final key = await SshKeyGenerator.generateInBackground(
        SshKeyType.rsa4096,
      );
      final pair =
          SSHKeyPair.fromPem(key.privateKey).single as OpenSSHRsaKeyPair;
      expect(pair.n.bitLength, 4096);
      expectUsable(key);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('only RSA is flagged slow', () {
      expect(SshKeyType.values.where((t) => t.isSlow), [
        SshKeyType.rsa3072,
        SshKeyType.rsa4096,
      ]);
    });

    test('every key is a different key', () {
      final keys = List.generate(6, (_) => SshKeyGenerator.ed25519());
      final ec = List.generate(
        3,
        (_) => SshKeyGenerator.generate(SshKeyType.ecdsaP256),
      );
      expect([...keys, ...ec].map((k) => k.fingerprint).toSet(), hasLength(9));
    });

    test('a key with no comment has a two-field public line', () {
      final key = SshKeyGenerator.ed25519();
      expect(key.publicKey.split(' '), hasLength(2));
      expectUsable(key);
    });

    test('toString never carries the private key', () {
      final key = SshKeyGenerator.ed25519();
      expect('$key', isNot(contains('PRIVATE')));
    });
  });

  group('passphrase', () {
    // Few rounds: this checks the container, not bcrypt's cost, and the
    // default 24 would make the suite pay for it several times.
    const rounds = 2;

    test('is sealed the way ssh-keygen seals it', () {
      final key = SshKeyGenerator.generate(
        SshKeyType.ed25519,
        passphrase: 'correct horse',
        rounds: rounds,
      );
      expect(key.isEncrypted, isTrue);
      expect(SSHKeyPair.isEncryptedPem(key.privateKey), isTrue);

      final body = SSHPem.decode(key.privateKey).content;
      final container = OpenSSHKeyPairs.decode(body);
      expect(container.cipherName, 'aes256-ctr');
      expect(container.kdfName, 'bcrypt');
      final kdf = container.kdfOptions! as OpenSSHBcryptKdfOptions;
      expect(kdf.salt, hasLength(16));
      expect(kdf.rounds, rounds);
    });

    for (final type in [
      SshKeyType.ed25519,
      SshKeyType.ecdsaP256,
      SshKeyType.ecdsaP384,
    ]) {
      test('${type.name} round-trips through dartssh2', () {
        final key = SshKeyGenerator.generate(
          type,
          comment: 'sealed',
          passphrase: 'pässwörd ✓',
          rounds: rounds,
        );
        expectUsable(key, passphrase: 'pässwörd ✓');
      });
    }

    test('RSA round-trips through dartssh2', () async {
      final key = await Future(
        () => SshKeyGenerator.generate(
          SshKeyType.rsa3072,
          passphrase: 'rsa pass',
          rounds: rounds,
        ),
      );
      expectUsable(key, passphrase: 'rsa pass');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a wrong passphrase is refused, not mis-decoded', () {
      final key = SshKeyGenerator.generate(
        SshKeyType.ed25519,
        passphrase: 'right',
        rounds: rounds,
      );
      expect(
        () => SSHKeyPair.fromPem(key.privateKey, 'wrong'),
        throwsA(isA<SSHKeyDecryptError>()),
      );
      expect(
        () => SSHKeyPair.fromPem(key.privateKey),
        throwsA(isA<SSHKeyDecryptError>()),
      );
    });

    test('an empty passphrase means unencrypted', () {
      final key = SshKeyGenerator.ed25519(passphrase: '');
      expect(key.isEncrypted, isFalse);
      expectUsable(key);
    });

    test('the default rounds are what a real key gets', () {
      final key = SshKeyGenerator.ed25519(passphrase: 'default');
      final container = OpenSSHKeyPairs.decode(
        SSHPem.decode(key.privateKey).content,
      );
      expect(
        (container.kdfOptions! as OpenSSHBcryptKdfOptions).rounds,
        SshKeyGenerator.bcryptRounds,
      );
      expectUsable(key, passphrase: 'default');
    });
  });
}
