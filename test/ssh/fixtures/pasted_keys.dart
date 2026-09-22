/// Keys in the formats a user might paste, made fresh for each test run.
///
/// Built at runtime rather than checked in: a private key literal in the
/// repository — even a throwaway one — is exactly what secret scanners are
/// right to flag, and a fixture nobody can tell apart from a leaked key is a
/// fixture that trains people to ignore the warning.
///
/// Each builder starts from a key this app generates and re-encodes it in the
/// legacy format under test, so the expected public key is known exactly.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/export.dart'
    show AESEngine, CBCBlockCipher, KeyParameter, ParametersWithIV;
import 'package:sshetu/core/ssh/key_generator.dart';

const fixturePassphrase = 'fixture-pass';

/// A pasted key and the `type base64` public key it must derive to.
class PastedKey {
  const PastedKey(this.pem, this.publicKey);

  final String pem;
  final String publicKey;
}

String _typeAndBlob(String line) => line.split(' ').take(2).join(' ');

/// A PKCS#1 `RSA PRIVATE KEY`, optionally sealed the way `ssh-keygen -m PEM`
/// and OpenSSL seal one: AES-128-CBC, key from MD5(passphrase || salt).
PastedKey pkcs1Rsa({String? passphrase}) {
  final generated = SshKeyGenerator.generate(SshKeyType.rsa3072);
  final pair =
      SSHKeyPair.fromPem(generated.privateKey).single as OpenSSHRsaKeyPair;
  final pem = RsaPrivateKey(
    BigInt.zero,
    pair.n,
    pair.e,
    pair.d,
    pair.p,
    pair.q,
    pair.d % (pair.p - BigInt.one),
    pair.d % (pair.q - BigInt.one),
    pair.iqmp,
  ).toPem();
  return PastedKey(
    passphrase == null
        ? pem
        : _sealPkcs1(SSHPem.decode(pem).content, passphrase),
    _typeAndBlob(generated.publicKey),
  );
}

String _sealPkcs1(Uint8List der, String passphrase) {
  final random = Random.secure();
  final iv = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  // EVP_BytesToKey with MD5, one round: one digest is the whole AES-128 key.
  final key = Uint8List.fromList(
    md5.convert([...utf8.encode(passphrase), ...iv.sublist(0, 8)]).bytes,
  );

  final padLength = 16 - der.length % 16;
  final padded = Uint8List.fromList([
    ...der,
    ...List.filled(padLength, padLength),
  ]);
  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(key), iv));
  final sealed = Uint8List(padded.length);
  for (var offset = 0; offset < padded.length; offset += 16) {
    cipher.processBlock(padded, offset, sealed, offset);
  }

  final hexIv = iv
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  final body = base64.encode(sealed);
  return [
    '-----BEGIN RSA PRIVATE KEY-----',
    'Proc-Type: 4,ENCRYPTED',
    'DEK-Info: AES-128-CBC,$hexIv',
    '',
    for (var i = 0; i < body.length; i += 64)
      body.substring(i, min(i + 64, body.length)),
    '-----END RSA PRIVATE KEY-----',
    '',
  ].join('\n');
}

/// A SEC1 `EC PRIVATE KEY` on P-256, as `ssh-keygen -m PEM -t ecdsa` writes.
PastedKey sec1Ec() {
  final generated = SshKeyGenerator.generate(SshKeyType.ecdsaP256);
  final pair =
      SSHKeyPair.fromPem(generated.privateKey).single as OpenSSHEcdsaKeyPair;

  final d = pair.d.toRadixString(16).padLeft(64, '0');
  final dBytes = [
    for (var i = 0; i < 64; i += 2) int.parse(d.substring(i, i + 2), radix: 16),
  ];
  // prime256v1, 1.2.840.10045.3.1.7
  const oid = [0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07];

  List<int> tlv(int tag, List<int> value) {
    assert(value.length < 128, 'short-form DER lengths only');
    return [tag, value.length, ...value];
  }

  final der = tlv(0x30, [
    ...tlv(0x02, [1]),
    ...tlv(0x04, dBytes),
    ...tlv(0xa0, oid),
    ...tlv(0xa1, tlv(0x03, [0, ...pair.q])),
  ]);
  final pem = SSHPem('EC PRIVATE KEY', {}, Uint8List.fromList(der)).encode();
  return PastedKey(pem, _typeAndBlob(generated.publicKey));
}

/// An OpenSSH key sealed with a passphrase, with a comment inside.
///
/// Written by this app's own encoder; that `ssh-keygen` opens the same
/// container is proved by the live test in `key_generator_test.dart`.
PastedKey encryptedOpenSsh() {
  final generated = SshKeyGenerator.generate(
    SshKeyType.ed25519,
    comment: 'fixture@test',
    passphrase: fixturePassphrase,
    rounds: 4,
  );
  return PastedKey(generated.privateKey, _typeAndBlob(generated.publicKey));
}

/// A PKCS#8 header around a body that is not a key at all, which is all the
/// inspector needs to refuse it: the format is recognised by name, before
/// the body is ever decoded.
const pkcs8Pem =
    '-----BEGIN PRIVATE KEY-----\n'
    'bm90IGEgcmVhbCBrZXk=\n'
    '-----END PRIVATE KEY-----\n';
