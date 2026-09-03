import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pinenacl/ed25519.dart';

/// A freshly generated keypair, in the forms the rest of the app needs.
class GeneratedKey {
  const GeneratedKey({
    required this.keyType,
    required this.privateKey,
    required this.publicKey,
    required this.fingerprint,
  });

  /// Always `ssh-ed25519` today.
  final String keyType;

  /// OpenSSH `openssh-key-v1` PEM, unencrypted. What goes in the vault.
  final String privateKey;

  /// The single `ssh-ed25519 AAAA… comment` line, for `authorized_keys`.
  final String publicKey;

  /// `SHA256:…`, exactly as `ssh-keygen -l` prints it.
  final String fingerprint;
}

/// Makes SSH keys on the device.
///
/// Without this the app can only use keys that already exist, which on a
/// phone means none: there is no `~/.ssh` on iOS or Android and no way to
/// make one. Every key had to be generated on a computer and carried over,
/// so the mobile app — the reason this project exists — could not get a user
/// from "installed" to "connected" on its own.
///
/// **Ed25519 only**, deliberately. It is small, fast, has no parameters to
/// get wrong, and is accepted by every server that has been updated this
/// decade. Offering RSA as well would mean offering a key size, and a key
/// size is a question that invites a wrong answer.
///
/// The private key is written in OpenSSH's own `openssh-key-v1` container,
/// unencrypted, because the passphrase this app would otherwise ask for is
/// not the thing protecting it — the key lives in the device keychain, behind
/// whatever the device locks with. A second passphrase would be one more
/// thing to lose, guarding a file nobody else can read.
abstract final class SshKeyGenerator {
  static const _type = 'ssh-ed25519';

  /// Generates an Ed25519 keypair. [comment] is written into both halves, the
  /// way `ssh-keygen` writes `user@host`.
  static GeneratedKey ed25519({String comment = ''}) {
    final signing = SigningKey.generate();
    final publicBytes = Uint8List.fromList(signing.publicKey.asTypedList);
    // OpenSSH stores seed || public as the private field, which is exactly
    // what pinenacl calls the secret.
    final privateBytes = Uint8List.fromList(signing.asTypedList);

    final publicBlob = _blob([
      _string(utf8.encode(_type)),
      _string(publicBytes),
    ]);

    return GeneratedKey(
      keyType: _type,
      privateKey: _armour(
        _privateFile(
          publicBlob: publicBlob,
          publicBytes: publicBytes,
          privateBytes: privateBytes,
          comment: comment,
        ),
      ),
      publicKey: [
        _type,
        base64.encode(publicBlob),
        if (comment.isNotEmpty) comment,
      ].join(' '),
      fingerprint: fingerprintOfBlob(publicBlob),
    );
  }

  /// `SHA256:` plus the unpadded base64 of the blob's SHA-256, which is what
  /// OpenSSH prints and therefore what a user will compare against.
  static String fingerprintOfBlob(Uint8List publicBlob) {
    final digest = sha256.convert(publicBlob).bytes;
    return 'SHA256:${base64.encode(digest).replaceAll('=', '')}';
  }

  /// The `openssh-key-v1` container, unencrypted.
  ///
  /// Laid out exactly as PROTOCOL.key describes, because `ssh-keygen`,
  /// `ssh-add` and every server-side tool will read this file and none of
  /// them are forgiving: a wrong length prefix or missing padding is not a
  /// warning, it is "invalid format" with nothing to go on.
  static Uint8List _privateFile({
    required Uint8List publicBlob,
    required Uint8List publicBytes,
    required Uint8List privateBytes,
    required String comment,
  }) {
    // The same value twice: OpenSSH uses the pair to detect a wrong
    // passphrase after decrypting. Unencrypted, they simply have to match.
    final check = Uint8List.fromList(
      SigningKey.generate().asTypedList.sublist(0, 4),
    );

    final unpadded = _blob([
      check,
      check,
      _string(utf8.encode(_type)),
      _string(publicBytes),
      _string(privateBytes),
      _string(utf8.encode(comment)),
    ]);

    // Padded to the cipher's block size with 1, 2, 3 … — "none" still counts
    // as 8 here, which is the detail most hand-written encoders get wrong.
    final padded = BytesBuilder()..add(unpadded);
    for (var i = 1; padded.length % 8 != 0; i++) {
      padded.addByte(i);
    }

    return _blob([
      utf8.encode('openssh-key-v1\x00'),
      _string(utf8.encode('none')), // cipher
      _string(utf8.encode('none')), // kdf
      _string(const []), // kdf options
      _uint32(1), // one key
      _string(publicBlob),
      _string(padded.toBytes()),
    ]);
  }

  static String _armour(Uint8List body) {
    final encoded = base64.encode(body);
    final lines = <String>[
      '-----BEGIN OPENSSH PRIVATE KEY-----',
      for (var i = 0; i < encoded.length; i += 70)
        encoded.substring(i, (i + 70).clamp(0, encoded.length)),
      '-----END OPENSSH PRIVATE KEY-----',
      '',
    ];
    return lines.join('\n');
  }

  static Uint8List _blob(List<List<int>> parts) {
    final builder = BytesBuilder();
    for (final part in parts) {
      builder.add(part);
    }
    return builder.toBytes();
  }

  /// An SSH `string`: a big-endian length, then the bytes.
  static Uint8List _string(List<int> value) =>
      _blob([_uint32(value.length), value]);

  static Uint8List _uint32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value);
}
