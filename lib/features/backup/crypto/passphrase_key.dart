import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Turning a passphrase people can remember into a key that resists guessing.
///
/// A backup file is the hardest thing this app has to protect. Everything else
/// lives behind a device unlock or a running process; a backup sits in a cloud
/// folder or an email for years, and whoever ends up with it can attack it at
/// their own pace on their own hardware. The passphrase is all that stands
/// there, and people choose passphrases badly.
///
/// **Argon2id, not PBKDF2.** PBKDF2 is a hash in a loop, and a GPU runs
/// thousands of those loops at once — it costs an attacker almost nothing to
/// parallelise. Argon2id has to fill 64 MiB per guess, which is the part
/// hardware cannot multiply cheaply. On this machine it is also *faster* than
/// PBKDF2 at OWASP's recommended 600k iterations (about 0.5s against 1.7s),
/// so the memory hardness is free.
///
/// The cost lives in the file, not in this constant: an old backup opens with
/// the parameters it was written with, so these can rise as hardware does
/// without stranding anything already saved.
typedef KeyDerivation = Future<Uint8List> Function({
  required String passphrase,
  required Uint8List salt,
  int memoryKib,
  int iterations,
  int parallelism,
});

abstract final class PassphraseKey {
  /// 64 MiB. Comfortably above OWASP's 19 MiB floor, and still under a second.
  static const int memoryKib = 64 * 1024;

  static const int iterations = 3;
  static const int parallelism = 1;

  /// 16 bytes, so two backups of the same data under the same passphrase do
  /// not produce the same key — and so a precomputed table is worthless.
  static const int saltBytes = 16;

  static const int keyBytes = 32;

  /// A fresh salt from the platform's cryptographic generator.
  ///
  /// [Random.secure] and nothing else: `Random()` here would be seeded well
  /// enough to look random in a test and be predictable to an attacker.
  static Uint8List newSalt() {
    final random = Random.secure();
    return Uint8List.fromList([
      for (var i = 0; i < saltBytes; i++) random.nextInt(256),
    ]);
  }

  /// Derives the key for [passphrase], off this isolate.
  ///
  /// The work is deliberately slow, which on the UI isolate is the definition
  /// of a frozen window — so it happens somewhere else and the screen stays
  /// live enough to show that something is happening.
  static Future<Uint8List> derive({
    required String passphrase,
    required Uint8List salt,
    int memoryKib = memoryKib,
    int iterations = iterations,
    int parallelism = parallelism,
  }) => Isolate.run(
    () => _derive(passphrase, salt, memoryKib, iterations, parallelism),
  );

  /// The same derivation, on the calling isolate.
  ///
  /// For widget tests, which cannot use the isolate at all: `Isolate.run`
  /// completes from a real port message, and a future created inside the test
  /// binding's fake-time zone never hears it — the test simply hangs. Nothing
  /// in the app calls this.
  static Future<Uint8List> deriveHere({
    required String passphrase,
    required Uint8List salt,
    int memoryKib = memoryKib,
    int iterations = iterations,
    int parallelism = parallelism,
  }) => _derive(passphrase, salt, memoryKib, iterations, parallelism);

  static Future<Uint8List> _derive(
    String passphrase,
    Uint8List salt,
    int memoryKib,
    int iterations,
    int parallelism,
  ) async {
    final key = await Argon2id(
      memory: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: keyBytes,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }
}
