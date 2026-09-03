/// What kind of secret a [SecretRef] points at.
///
/// The kind is part of the stored key, so a password can never be read back
/// where a private key is expected even if two ids collided.
enum SecretKind {
  /// A host's login password. Only present when the user chose to save one.
  hostPassword('password'),

  /// PEM (or OpenSSH) private key material for an identity.
  identityPrivateKey('private'),

  /// The passphrase protecting an identity's private key.
  identityPassphrase('passphrase');

  const SecretKind(this.slot);

  /// The trailing path segment used in the storage key.
  final String slot;
}

/// A stable, opaque address for one secret.
///
/// Nothing outside `core/secrets/` builds storage keys by hand. Every secret
/// in the app is named by one of these, which is what makes it possible to
/// state — and to test — that a given id's secrets were all removed when the
/// row was deleted.
///
/// The value is deliberately *not* the secret and is safe to log: it contains
/// an id and a kind, never material.
class SecretRef {
  const SecretRef._(this.ownerId, this.kind);

  /// The password saved for host [hostId], if any.
  const SecretRef.hostPassword(String hostId)
    : this._(hostId, SecretKind.hostPassword);

  /// Private key material for identity [identityId].
  const SecretRef.identityPrivateKey(String identityId)
    : this._(identityId, SecretKind.identityPrivateKey);

  /// The passphrase protecting identity [identityId]'s private key.
  const SecretRef.identityPassphrase(String identityId)
    : this._(identityId, SecretKind.identityPassphrase);

  /// The id of the row this secret belongs to.
  final String ownerId;

  final SecretKind kind;

  /// The storage key. Namespaced by kind so two rows sharing an id — a host
  /// and an identity created from the same import, say — cannot collide.
  String get storageKey => switch (kind) {
    SecretKind.hostPassword => 'host/$ownerId/${kind.slot}',
    SecretKind.identityPrivateKey ||
    SecretKind.identityPassphrase => 'identity/$ownerId/${kind.slot}',
  };

  /// Every secret an identity can own. Used to purge on delete: forgetting one
  /// slot leaves key material behind after the user believed it was gone.
  static List<SecretRef> forIdentity(String identityId) => [
    SecretRef.identityPrivateKey(identityId),
    SecretRef.identityPassphrase(identityId),
  ];

  /// Every secret a host can own.
  static List<SecretRef> forHost(String hostId) => [
    SecretRef.hostPassword(hostId),
  ];

  @override
  bool operator ==(Object other) =>
      other is SecretRef && other.ownerId == ownerId && other.kind == kind;

  @override
  int get hashCode => Object.hash(ownerId, kind);

  /// Safe to log: the address, never the secret.
  @override
  String toString() => 'SecretRef($storageKey)';
}
