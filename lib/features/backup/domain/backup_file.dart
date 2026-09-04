import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pinenacl/x25519.dart' show SecretBox, EncryptedMessage;

import '../../transfer/domain/transfer_payload.dart';
import '../crypto/passphrase_key.dart';

/// A backup that could not be read, in words a dialog can show.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// What a backup holds, shown before any of it is written.
///
/// Read out of the *decrypted* body rather than the header, so a file lying
/// around says nothing about how many servers someone runs. The counts are
/// only knowable by whoever can already open it.
class BackupContents {
  const BackupContents({
    required this.hosts,
    required this.identities,
    required this.tunnels,
    required this.knownHosts,
    required this.includesSecrets,
    required this.created,
    required this.appVersion,
  });

  final int hosts;
  final int identities;
  final int tunnels;
  final int knownHosts;

  /// Whether private keys and passwords are inside. The difference between a
  /// list of addresses and the keys to every one of them.
  final bool includesSecrets;

  final DateTime created;
  final String appVersion;
}

/// The `.sshetu-backup` file: a readable envelope around a sealed body.
///
/// **Why the envelope is plaintext.** Everything needed to *attempt* a
/// decryption has to be readable, or the file cannot be opened at all — the
/// salt and the Argon2 cost are inputs to the key, not secrets. Writing them
/// down is also what lets today's parameters change tomorrow without
/// stranding a backup written this year.
///
/// **Why the header is still authenticated.** A plaintext header that nothing
/// checks is a header anyone can rewrite. XSalsa20-Poly1305 has no associated
/// data to bind it with, so a hash of the exact header bytes travels *inside*
/// the sealed body and is compared after opening — the same move the transfer
/// channel makes with its sequence numbers. Edit a single byte of the header
/// and the file is refused rather than quietly opened as something else.
class BackupFile {
  const BackupFile._();

  /// Names the file for what it is, so a future version can refuse politely
  /// rather than throwing a parse error at someone.
  static const String magic = 'sshetu.backup';

  static const int version = 1;

  static const String cipher = 'xsalsa20-poly1305';

  /// The extension the save dialog offers.
  static const String extension = 'sshetu-backup';

  /// Seals [payload] under [passphrase].
  ///
  /// Returns the bytes to write. Pretty-printed: a backup is a file people
  /// keep for years and may one day open in a text editor to work out what it
  /// is, and the few hundred wasted bytes buy exactly that.
  static Future<Uint8List> write({
    required TransferPayload payload,
    required String passphrase,
    required String appVersion,
    DateTime? createdAt,
    KeyDerivation? derive,
  }) async {
    if (passphrase.isEmpty) {
      throw const BackupException('A backup needs a passphrase.');
    }

    final salt = PassphraseKey.newSalt();
    final key = await (derive ?? PassphraseKey.derive)(
      passphrase: passphrase,
      salt: salt,
    );

    final header = <String, Object?>{
      'format': magic,
      'version': version,
      'created': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
      'app': appVersion,
      'cipher': cipher,
      'kdf': {
        'name': 'argon2id',
        'memory': PassphraseKey.memoryKib,
        'iterations': PassphraseKey.iterations,
        'parallelism': PassphraseKey.parallelism,
        'salt': base64.encode(salt),
      },
    };

    final body = <String, Object?>{
      // What the header deliberately does not say.
      'counts': {
        'hosts': payload.hostCount,
        'identities': payload.identityCount,
        'tunnels': payload.tunnelCount,
        'knownHosts': payload.knownHostCount,
      },
      'secrets': payload.secrets.isNotEmpty,
      'header': _fingerprint(header),
      'payload': payload.toJson(),
    };

    final sealed = SecretBox(key)
        .encrypt(Uint8List.fromList(utf8.encode(jsonEncode(body))));

    return Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ')
            .convert({...header, 'body': base64.encode(sealed)}),
      ),
    );
  }

  /// Opens [bytes] with [passphrase].
  ///
  /// Every failure that could be a wrong passphrase reports as one. The
  /// alternative — "authentication failed" versus "bad padding" — tells an
  /// attacker which half of their guess was right, and tells the person who
  /// mistyped nothing they can use.
  static Future<({TransferPayload payload, BackupContents contents})> read({
    required Uint8List bytes,
    required String passphrase,
    KeyDerivation? derive,
  }) async {
    final header = _parseHeader(bytes);

    final kdf = header['kdf'];
    if (kdf is! Map) throw const BackupException(_damaged);
    final salt = _decodeSalt(kdf['salt']);

    final key = await (derive ?? PassphraseKey.derive)(
      passphrase: passphrase,
      salt: salt,
      memoryKib: _positiveInt(kdf['memory']) ?? PassphraseKey.memoryKib,
      iterations: _positiveInt(kdf['iterations']) ?? PassphraseKey.iterations,
      parallelism:
          _positiveInt(kdf['parallelism']) ?? PassphraseKey.parallelism,
    );

    final rawBody = header['body'];
    if (rawBody is! String) throw const BackupException(_damaged);

    final Map<String, Object?> body;
    try {
      final opened = SecretBox(key)
          .decrypt(EncryptedMessage.fromList(base64.decode(rawBody)));
      body = jsonDecode(utf8.decode(opened)) as Map<String, Object?>;
    } on Object {
      throw const BackupException('That passphrase does not open this backup.');
    }

    // The header is only trustworthy now. Anything read from it before this
    // point was used to *try* a key, which a wrong value simply fails.
    final expected = {...header}..remove('body');
    if (body['header'] != _fingerprint(expected)) {
      throw const BackupException(
        'This backup has been altered since it was written, so it will not '
        'be restored.',
      );
    }

    final rawPayload = body['payload'];
    if (rawPayload is! Map<String, Object?>) {
      throw const BackupException(_damaged);
    }

    final counts = body['counts'];
    return (
      payload: TransferPayload.fromJson(rawPayload),
      contents: BackupContents(
        hosts: _count(counts, 'hosts'),
        identities: _count(counts, 'identities'),
        tunnels: _count(counts, 'tunnels'),
        knownHosts: _count(counts, 'knownHosts'),
        includesSecrets: body['secrets'] == true,
        created:
            DateTime.tryParse(header['created'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        appVersion: header['app'] as String? ?? '',
      ),
    );
  }

  static const String _damaged =
      'This file is not a readable SSHetu backup. It may be damaged or '
      'incomplete.';

  /// Reads the envelope, refusing anything that is not ours before a
  /// passphrase is even asked for.
  static Map<String, Object?> _parseHeader(Uint8List bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const BackupException(_damaged);
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupException(_damaged);
    }
    if (decoded['format'] != magic) {
      throw const BackupException(_damaged);
    }

    final found = decoded['version'];
    if (found is! int) throw const BackupException(_damaged);
    if (found > version) {
      // Named in both directions, because "update the app" is only actionable
      // if you can tell how far behind you are.
      throw BackupException(
        'This backup was written by a newer version of SSHetu (format $found; '
        'this build reads $version). Update SSHetu and try again.',
      );
    }
    if (decoded['cipher'] != cipher) {
      throw const BackupException(_damaged);
    }
    return decoded;
  }

  /// SHA-256 of the header in a fixed key order, so the comparison does not
  /// depend on how any particular JSON encoder happens to order a map.
  static String _fingerprint(Map<String, Object?> header) {
    final keys = header.keys.toList()..sort();
    final canonical = <String, Object?>{
      for (final key in keys)
        key: header[key] is Map
            ? _sorted(header[key]! as Map<String, Object?>)
            : header[key],
    };
    return base64.encode(
      sha256.convert(utf8.encode(jsonEncode(canonical))).bytes,
    );
  }

  static Map<String, Object?> _sorted(Map<String, Object?> map) {
    final keys = map.keys.toList()..sort();
    return {for (final key in keys) key: map[key]};
  }

  static Uint8List _decodeSalt(Object? raw) {
    if (raw is! String) throw const BackupException(_damaged);
    try {
      return Uint8List.fromList(base64.decode(raw));
    } on Object {
      throw const BackupException(_damaged);
    }
  }

  /// Rejects zero and negative costs rather than passing them to Argon2,
  /// which would throw something less explicable.
  static int? _positiveInt(Object? raw) => raw is int && raw > 0 ? raw : null;

  static int _count(Object? counts, String key) =>
      counts is Map && counts[key] is int ? counts[key]! as int : 0;
}
