/// Where an identity came from.
enum IdentityOrigin {
  /// Generated in this app.
  generated,

  /// Pasted in or read from a file the user chose.
  imported,

  /// Found by scanning the machine's own `~/.ssh`.
  sshConfig,
}

/// An SSH keypair the user owns.
///
/// The **private key is not here.** It lives in the `SecretVault` under this
/// [id], with its passphrase in a separate slot. What this holds is the public
/// half and its fingerprint, which are not secret — and keeping them in the
/// clear is what lets the app show a key, copy it to the clipboard, and offer
/// to install it on a server without unlocking anything.
class SshIdentity {
  const SshIdentity({
    required this.id,
    required this.label,
    required this.keyType,
    required this.createdAt,
    required this.updatedAt,
    this.publicKey,
    this.fingerprint,
    this.hasPassphrase = false,
    this.origin = IdentityOrigin.imported,
  });

  final String id;

  /// What the user calls it — `laptop`, `work.pem`.
  final String label;

  /// `ssh-ed25519`, `ssh-rsa`, … or `unknown` when an encrypted key was
  /// imported without its `.pub` and the algorithm could not be read.
  final String keyType;

  /// The OpenSSH single-line public key, safe to display and to paste into
  /// `authorized_keys`.
  final String? publicKey;

  /// `SHA256:<base64>`, the form `ssh-keygen -lf` prints.
  final String? fingerprint;

  /// Whether the private key needs a passphrase.
  ///
  /// Recorded so the app can say so in the list, and ask at the right moment,
  /// rather than discovering it mid-handshake.
  final bool hasPassphrase;

  final IdentityOrigin origin;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// A short, comparable form of the fingerprint for a dense list row.
  String get shortFingerprint {
    final value = fingerprint;
    if (value == null) return '';
    return value.length <= 22 ? value : '${value.substring(0, 22)}…';
  }

  SshIdentity copyWith({
    String? label,
    String? keyType,
    String? publicKey,
    String? fingerprint,
    bool? hasPassphrase,
    IdentityOrigin? origin,
    DateTime? updatedAt,
  }) => SshIdentity(
    id: id,
    label: label ?? this.label,
    keyType: keyType ?? this.keyType,
    publicKey: publicKey ?? this.publicKey,
    fingerprint: fingerprint ?? this.fingerprint,
    hasPassphrase: hasPassphrase ?? this.hasPassphrase,
    origin: origin ?? this.origin,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Prints the label and fingerprint. There is no key material to leak here,
  /// but the habit is worth keeping.
  @override
  String toString() => 'SshIdentity($id, $label, $keyType)';
}
