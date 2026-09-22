import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'key_generator.dart';
import 'openssh_import.dart';

/// Why a pasted key was not accepted.
enum KeyProblem {
  /// Nothing was pasted.
  empty,

  /// A **public** key — the `.pub`, or an `authorized_keys` line. The most
  /// common mistake there is, and one that deserves its own message: the
  /// user has the right key in hand, just the wrong half of it.
  publicKey,

  /// Not a key at all.
  notAKey,

  /// A private key in a format the SSH client cannot use: PKCS#8
  /// (`BEGIN PRIVATE KEY`), PuTTY's `.ppk`, DSA, an encrypted SEC1 EC key.
  /// Accepting one would store a key that fails at connect time.
  unsupportedFormat,

  /// Encrypted, and no passphrase given yet.
  needsPassphrase,

  /// Encrypted, and the passphrase did not open it.
  wrongPassphrase,

  /// Looks like a private key but does not decode — truncated, a missing
  /// line, a mangled paste.
  damaged,
}

/// A private key that was read successfully.
///
/// [pem] is the key exactly as it will be stored — the pasted text, trimmed
/// and with its line endings normalised, **still encrypted if it was**. The
/// passphrase used to read it is not kept anywhere.
class InspectedKey {
  const InspectedKey({
    required this.keyType,
    required this.publicKey,
    required this.fingerprint,
    required this.isEncrypted,
    required this.pem,
    this.comment = '',
  });

  /// `ssh-ed25519`, `ecdsa-sha2-nistp256`, `ssh-rsa`, …
  final String keyType;

  /// The `authorized_keys` line derived from the private half.
  final String publicKey;

  /// `SHA256:…`, as `ssh-keygen -l` prints it.
  final String fingerprint;

  final bool isEncrypted;

  /// The comment stored inside the key, when the format has one.
  final String comment;

  final String pem;

  /// Never the material.
  @override
  String toString() => 'InspectedKey($keyType, $fingerprint)';
}

/// The verdict on some pasted text: a key, or the reason it is not one.
class KeyInspection {
  const KeyInspection.ok(InspectedKey this.key)
    : problem = null,
      keyType = null;

  const KeyInspection.rejected(KeyProblem this.problem, {this.keyType})
    : key = null;

  final InspectedKey? key;
  final KeyProblem? problem;

  /// The algorithm, when it could be read without the passphrase — so the
  /// passphrase prompt can say what it is unlocking.
  final String? keyType;

  bool get isOk => key != null;

  @override
  String toString() => isOk ? 'KeyInspection($key)' : 'KeyInspection($problem)';
}

/// Reads a private key someone pasted, and derives its public half.
///
/// Built on the same detection the file import uses ([OpenSshScanner]), then
/// goes further than it can: the key is actually **decoded by dartssh2**, the
/// client that will use it. A paste is the least reliable way a key arrives —
/// a line lost off the end, a chat app that swallowed the newlines — and the
/// time to find out is now, with the text still on screen, not at the first
/// connection weeks later.
///
/// Never throws and never echoes the input. Decoders put the bytes they choke
/// on into their messages, and those bytes are key material; every failure
/// here is mapped to a [KeyProblem] and the exception itself is dropped.
///
/// Encrypted keys are opened with [passphrase] only to prove it and derive
/// the public key. bcrypt_pbkdf makes that take a noticeable fraction of a
/// second, so UI code wants [inspectPrivateKeyInBackground].
KeyInspection inspectPrivateKey(String text, {String? passphrase}) {
  final normalised = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalised.isEmpty) return const KeyInspection.rejected(KeyProblem.empty);

  if (_looksLikePublicKey(normalised)) {
    return const KeyInspection.rejected(KeyProblem.publicKey);
  }
  if (normalised.startsWith('PuTTY-User-Key-File')) {
    return const KeyInspection.rejected(KeyProblem.unsupportedFormat);
  }

  final pem = _extractPem(normalised);
  if (pem == null || !OpenSshScanner.looksLikePrivateKey(pem.text)) {
    return const KeyInspection.rejected(KeyProblem.notAKey);
  }

  const readable = {'OPENSSH PRIVATE KEY', 'RSA PRIVATE KEY', 'EC PRIVATE KEY'};
  if (!readable.contains(pem.type)) {
    return const KeyInspection.rejected(KeyProblem.unsupportedFormat);
  }

  final bool encrypted;
  try {
    encrypted = SSHKeyPair.isEncryptedPem(pem.text);
  } on Object {
    return const KeyInspection.rejected(KeyProblem.damaged);
  }

  // Readable without the passphrase, from the unencrypted public half of an
  // OpenSSH container — so the prompt can name the key it is asking about.
  final knownType = OpenSshScanner.keyTypeOf(null, pem.text);

  if (encrypted && pem.type == 'EC PRIVATE KEY') {
    // dartssh2 cannot decrypt a legacy encrypted EC key; storing one would
    // be a key that never connects.
    return const KeyInspection.rejected(KeyProblem.unsupportedFormat);
  }
  if (encrypted && (passphrase == null || passphrase.isEmpty)) {
    return KeyInspection.rejected(
      KeyProblem.needsPassphrase,
      keyType: knownType == 'unknown' ? null : knownType,
    );
  }

  final List<SSHKeyPair> pairs;
  try {
    pairs = SSHKeyPair.fromPem(pem.text, encrypted ? passphrase : null);
  } on UnsupportedError {
    // An OpenSSH container holding a type the client has no signer for —
    // DSA, a security-key type — or a cipher it cannot undo.
    return const KeyInspection.rejected(KeyProblem.unsupportedFormat);
  } on Object {
    // Encrypted: a wrong passphrase decrypts to noise, and noise fails
    // wherever the decoder first trips on it — the check ints, the ASN.1.
    return KeyInspection.rejected(
      encrypted ? KeyProblem.wrongPassphrase : KeyProblem.damaged,
      keyType: knownType == 'unknown' ? null : knownType,
    );
  }
  if (pairs.isEmpty) return const KeyInspection.rejected(KeyProblem.damaged);

  final pair = pairs.first;
  final Uint8List blob;
  try {
    blob = pair.toPublicKey().encode();
  } on Object {
    return const KeyInspection.rejected(KeyProblem.damaged);
  }

  // An OpenSSH container also carries the public key in the clear. If it
  // disagrees with the one derived from the private half, the file has been
  // tampered with or spliced, and it is not the key it claims to be.
  if (pem.type == 'OPENSSH PRIVATE KEY') {
    try {
      final stored = OpenSSHKeyPairs.decode(SSHPem.decode(pem.text).content)
          .publicKeys
          .first;
      if (!_sameBytes(stored, blob)) {
        return const KeyInspection.rejected(KeyProblem.damaged);
      }
    } on Object {
      return const KeyInspection.rejected(KeyProblem.damaged);
    }
  }

  // OpenSSH keys carry one; PKCS#1 and SEC1 have nowhere to put it.
  final comment = pair.comment?.trim() ?? '';

  return KeyInspection.ok(
    InspectedKey(
      keyType: pair.name,
      publicKey: SshKeyGenerator.publicKeyLine(pair.name, blob, comment),
      fingerprint: SshKeyGenerator.fingerprintOfBlob(blob),
      isEncrypted: encrypted,
      comment: comment,
      pem: '${pem.text}\n',
    ),
  );
}

/// [inspectPrivateKey], off the UI isolate — bcrypt_pbkdf on an encrypted
/// OpenSSH key takes about half a second on a desktop and longer on a phone.
Future<KeyInspection> inspectPrivateKeyInBackground(
  String text, {
  String? passphrase,
}) => Isolate.run(() => inspectPrivateKey(text, passphrase: passphrase));

final _publicKeyLine = RegExp(
  r'^(?:\S+\s+)?(?:ssh-(?:ed25519|rsa|dss)|ecdsa-sha2-\S+|sk-\S+|\S+-cert-v01@openssh\.com)\s+AAAA',
);

bool _looksLikePublicKey(String text) =>
    _publicKeyLine.hasMatch(text) ||
    text.contains('BEGIN SSH2 PUBLIC KEY') ||
    text.contains('BEGIN PUBLIC KEY') ||
    text.contains('BEGIN RSA PUBLIC KEY') ||
    text.contains('BEGIN OPENSSH PUBLIC KEY');

class _Pem {
  const _Pem(this.type, this.text);

  final String type;
  final String text;
}

final _pemBlock = RegExp(
  r'-----BEGIN ([A-Z0-9 ]+)-----([\s\S]*?)-----END \1-----',
);

/// The PEM block inside [text], tidied.
///
/// Tolerates what pasting does to a key: text before or after it (a shell
/// prompt, `cat id_ed25519`), and a body whose newlines were turned into
/// spaces or removed. The body is rewrapped only when it has no PEM headers
/// (`Proc-Type:`), which cannot be recovered once their line breaks are gone.
_Pem? _extractPem(String text) {
  final match = _pemBlock.firstMatch(text);
  if (match == null) return null;
  final type = match.group(1)!;
  final body = match.group(2)!;

  final String rebuilt;
  if (body.contains(':')) {
    rebuilt = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  } else {
    final base64 = body.replaceAll(RegExp(r'\s+'), '');
    final width = type == 'OPENSSH PRIVATE KEY' ? 70 : 64;
    rebuilt = [
      for (var i = 0; i < base64.length; i += width)
        base64.substring(
          i,
          i + width > base64.length ? base64.length : i + width,
        ),
    ].join('\n');
  }
  return _Pem(type, '-----BEGIN $type-----\n$rebuilt\n-----END $type-----');
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
