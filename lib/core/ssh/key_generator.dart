import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as nacl;
import 'package:pointycastle/export.dart'
    show
        ECCurve_secp256r1,
        ECCurve_secp384r1,
        ECDomainParameters,
        ECKeyGenerator,
        ECKeyGeneratorParameters,
        FortunaRandom,
        KeyParameter,
        ParametersWithRandom,
        RSAKeyGenerator,
        RSAKeyGeneratorParameters,
        SecureRandom;

/// The kinds of key this app can make.
///
/// Every one of them is a type dartssh2 4.0.0 can **authenticate with**, not
/// merely parse: `OpenSSHKeyPairs.getPrivateKeys` decodes each into a key pair
/// whose `sign` the client uses for `publickey` auth — Ed25519, ECDSA over the
/// NIST curves, and RSA signing with `rsa-sha2-256`. Offering a type the
/// client could store but never sign with would be a key that silently fails
/// at the one moment it matters.
///
/// P-521 is left out on purpose rather than for want of support: it adds a
/// third ECDSA choice that no server requires and nobody asks for, and every
/// extra option on this sheet is a question the user has to answer.
enum SshKeyType {
  /// The default and the recommendation.
  ed25519('ssh-ed25519'),
  ecdsaP256('ecdsa-sha2-nistp256'),
  ecdsaP384('ecdsa-sha2-nistp384'),
  rsa3072('ssh-rsa'),
  rsa4096('ssh-rsa');

  const SshKeyType(this.wireName);

  /// The algorithm name OpenSSH writes at the start of the public key line.
  final String wireName;

  /// Whether making one takes long enough that the user must be told to wait.
  ///
  /// RSA only. Finding two 1500–2000-bit primes in pure Dart takes seconds on
  /// a desktop and longer on a phone; everything else is instant.
  bool get isSlow => this == rsa3072 || this == rsa4096;
}

/// A freshly generated keypair, in the forms the rest of the app needs.
///
/// Plain strings only, so it crosses an isolate boundary as it is.
class GeneratedKey {
  const GeneratedKey({
    required this.keyType,
    required this.privateKey,
    required this.publicKey,
    required this.fingerprint,
    this.isEncrypted = false,
  });

  /// `ssh-ed25519`, `ecdsa-sha2-nistp256`, `ssh-rsa`, …
  final String keyType;

  /// OpenSSH `openssh-key-v1` PEM. What goes in the vault.
  final String privateKey;

  /// The single `type AAAA… comment` line, for `authorized_keys`.
  final String publicKey;

  /// `SHA256:…`, exactly as `ssh-keygen -l` prints it.
  final String fingerprint;

  /// Whether [privateKey] is sealed with a passphrase.
  final bool isEncrypted;

  /// Never the private key.
  @override
  String toString() => 'GeneratedKey($keyType, $fingerprint)';
}

/// Makes SSH keys on the device.
///
/// Without this the app can only use keys that already exist, which on a
/// phone means none: there is no `~/.ssh` on iOS or Android and no way to
/// make one. Every key had to be generated on a computer and carried over,
/// so the mobile app — the reason this project exists — could not get a user
/// from "installed" to "connected" on its own.
///
/// **Ed25519 is the default**, and the sheet says so. It is small, fast, has
/// no parameters to get wrong, and is accepted by every server updated this
/// decade. ECDSA and RSA exist for the servers and policies that are not:
/// older appliances, FIPS-minded estates, a compliance document that says
/// "RSA 4096". RSA sizes stop at the two still worth choosing.
///
/// The private key is written in OpenSSH's own `openssh-key-v1` container,
/// through dartssh2's encoder — the same code that will later decode it to
/// connect. Unencrypted by default, because the key lives in the device
/// keychain, behind whatever the device locks with. A passphrase is offered
/// for people who want the key useless even to someone holding an unlocked
/// device; the key is then sealed exactly as `ssh-keygen` seals it —
/// `aes256-ctr` with key and IV from `bcrypt_pbkdf` — so the same file works
/// in OpenSSH if it is ever carried off the device.
abstract final class SshKeyGenerator {
  /// bcrypt_pbkdf rounds for a passphrase-protected key.
  ///
  /// dartssh2's default, and what current `ssh-keygen` writes. The cost is
  /// paid again every time the key is unlocked to connect, so this is a
  /// balance, not a dial to turn up.
  static const bcryptRounds = OpenSSHKeyPairs.defaultBcryptRounds;

  /// Generates an Ed25519 keypair. [comment] is written into both halves, the
  /// way `ssh-keygen` writes `user@host`.
  static GeneratedKey ed25519({String comment = '', String? passphrase}) =>
      generate(SshKeyType.ed25519, comment: comment, passphrase: passphrase);

  /// Generates a key of [type], on the calling isolate.
  ///
  /// RSA, and any passphrase, make this slow: UI code wants
  /// [generateInBackground]. A null or empty [passphrase] writes the key
  /// unencrypted.
  static GeneratedKey generate(
    SshKeyType type, {
    String comment = '',
    String? passphrase,
    int rounds = bcryptRounds,
  }) {
    final random = _secureRandom();
    final OpenSSHKeyPair pair = switch (type) {
      SshKeyType.ed25519 => _ed25519(comment),
      SshKeyType.ecdsaP256 => _ecdsa(
        'nistp256',
        ECCurve_secp256r1(),
        comment,
        random,
      ),
      SshKeyType.ecdsaP384 => _ecdsa(
        'nistp384',
        ECCurve_secp384r1(),
        comment,
        random,
      ),
      SshKeyType.rsa3072 => _rsa(3072, comment, random),
      SshKeyType.rsa4096 => _rsa(4096, comment, random),
    };

    final encrypt = passphrase != null && passphrase.isNotEmpty;
    final publicBlob = pair.toPublicKey().encode();

    return GeneratedKey(
      keyType: type.wireName,
      privateKey: pair.toPem(
        passphrase: encrypt ? passphrase : null,
        rounds: rounds,
      ),
      publicKey: publicKeyLine(type.wireName, publicBlob, comment),
      fingerprint: fingerprintOfBlob(publicBlob),
      isEncrypted: encrypt,
    );
  }

  /// [generate], off the UI isolate.
  ///
  /// RSA 4096 takes seconds and a frame is sixteen milliseconds. Run on the
  /// UI isolate it would freeze the sheet — spinner included — for the whole
  /// time, which reads as a crash.
  static Future<GeneratedKey> generateInBackground(
    SshKeyType type, {
    String comment = '',
    String? passphrase,
  }) => Isolate.run(
    () => generate(type, comment: comment, passphrase: passphrase),
  );

  /// `type base64 [comment]`, the `authorized_keys` form.
  static String publicKeyLine(
    String type,
    Uint8List publicBlob,
    String comment,
  ) => [
    type,
    base64.encode(publicBlob),
    if (comment.trim().isNotEmpty) comment.trim(),
  ].join(' ');

  /// `SHA256:` plus the unpadded base64 of the blob's SHA-256, which is what
  /// OpenSSH prints and therefore what a user will compare against.
  static String fingerprintOfBlob(Uint8List publicBlob) {
    final digest = sha256.convert(publicBlob).bytes;
    return 'SHA256:${base64.encode(digest).replaceAll('=', '')}';
  }

  static OpenSSHEd25519KeyPair _ed25519(String comment) {
    final signing = nacl.SigningKey.generate();
    // OpenSSH stores seed || public as the private field, which is exactly
    // what pinenacl calls the secret.
    return OpenSSHEd25519KeyPair(
      Uint8List.fromList(signing.publicKey.asTypedList),
      Uint8List.fromList(signing.asTypedList),
      comment,
    );
  }

  static OpenSSHEcdsaKeyPair _ecdsa(
    String curveId,
    ECDomainParameters curve,
    String comment,
    SecureRandom random,
  ) {
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(curve), random));
    final pair = generator.generateKeyPair();
    final public = pair.publicKey;
    final private = pair.privateKey;
    // Uncompressed SEC1 point, 0x04 || X || Y with fixed-width coordinates:
    // the form RFC 5656 puts in an SSH key.
    return OpenSSHEcdsaKeyPair(
      curveId,
      public.Q!.getEncoded(false),
      private.d!,
      comment,
    );
  }

  static OpenSSHRsaKeyPair _rsa(int bits, String comment, SecureRandom random) {
    final e = BigInt.from(65537);
    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          // 64 Miller–Rabin rounds: a composite surviving that is far rarer
          // than anything else that could go wrong with this key.
          RSAKeyGeneratorParameters(e, bits, 64),
          random,
        ),
      );
    final private = generator.generateKeyPair().privateKey;
    final p = private.p!;
    final q = private.q!;
    // PROTOCOL.key's field order: n, e, d, iqmp, p, q — with iqmp = q⁻¹ mod p.
    return OpenSSHRsaKeyPair(
      private.modulus!,
      e,
      private.privateExponent!,
      q.modInverse(p),
      p,
      q,
      comment,
    );
  }

  /// Fortuna seeded from the platform CSPRNG.
  ///
  /// pointycastle's generators draw from a `SecureRandom` of their own, and
  /// its default constructor looks one up in a registry. Seeding explicitly
  /// from `Random.secure()` keeps where the entropy comes from obvious.
  static SecureRandom _secureRandom() {
    final seed = Random.secure();
    return FortunaRandom()..seed(
      KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => seed.nextInt(256))),
      ),
    );
  }
}
