/// How to authenticate to a host.
enum SshAuthMethod {
  /// A private key held in the vault, optionally passphrase-protected.
  publicKey,

  /// A password. Supplied per connection unless the user chose to save one.
  password,

  /// A key held by the OS ssh-agent. Not implemented yet; declared so the
  /// stored value and the UI can exist before the transport does.
  agent,
}

/// Everything the transport needs to open one connection, and nothing else.
///
/// Deliberately **not** the host record. `SshHost` carries a label, a group, a
/// colour, tags, notes, sync bookkeeping — none of which the connection layer
/// has any business seeing. Keeping the transport's input this narrow is what
/// lets the same code be driven by a saved host, by a one-off "quick connect",
/// or by an entry parsed out of `~/.ssh/config` without any of them knowing
/// about each other.
///
/// It holds **no secret**. [identityId] and the password are looked up through
/// the `SecretVault` at connect time, by the layer above.
class SshTarget {
  const SshTarget({
    required this.hostname,
    required this.username,
    this.port = 22,
    this.authMethod = SshAuthMethod.publicKey,
    this.identityId,
    this.credentialId,
    this.jumpTarget,
    this.allowLegacyAlgorithms = false,
    this.keepaliveInterval = const Duration(seconds: 30),
  });

  final String hostname;
  final int port;
  final String username;
  final SshAuthMethod authMethod;

  /// The identity whose private key authenticates this connection. The key
  /// itself lives in the vault under this id, never here.
  final String? identityId;

  /// An opaque id used to address **this target's own** saved secrets — in
  /// practice the host row's id.
  ///
  /// Deliberately not the host record, and deliberately nullable: a one-off
  /// "quick connect" has no saved secrets, so it carries no id and is always
  /// prompted. Nothing reads this except the credential source; it is an
  /// address, not data.
  final String? credentialId;

  /// The bastion to reach this host through (`ProxyJump`).
  ///
  /// A target, not an id: a chain is a chain of the same thing, so a jump host
  /// gets identical credential handling rather than a parallel, weaker
  /// implementation. Recursive by construction, so `a -> b -> c` works without
  /// special-casing the length.
  final SshTarget? jumpTarget;

  /// Re-enable the algorithms dartssh2 4.0 dropped from its defaults — SHA-1
  /// key exchange, `ssh-rsa` host keys, CBC ciphers.
  ///
  /// Off unless the user turned it on for this host. Old switches, routers and
  /// embedded boxes genuinely offer nothing else and would otherwise be
  /// unreachable, but every one of these weakens the connection, so it is
  /// never a global setting and never a silent fallback: a host that needs it
  /// fails first and says so.
  final bool allowLegacyAlgorithms;

  /// How often to send a keepalive; [Duration.zero] disables it.
  ///
  /// Mobile carriers drop idle TCP connections aggressively — this is what
  /// keeps a session alive in a pocket rather than dying silently and only
  /// being discovered on the next keystroke.
  final Duration keepaliveInterval;

  /// [keepaliveInterval] as dartssh2 wants it: null, not zero, for "off".
  ///
  /// dartssh2 disables keepalives only on null. Handed [Duration.zero] it
  /// builds a zero-period `Timer.periodic` and pings the server as fast as the
  /// event loop turns — the opposite of what "0 = off" promised.
  Duration? get keepaliveOrNull =>
      keepaliveInterval > Duration.zero ? keepaliveInterval : null;

  /// `user@host:port`. Carries no secret and is safe to log.
  String get address => '$username@$hostname:$port';

  /// The chain from the outermost bastion to this target, in dial order.
  ///
  /// `a` reached through `b` through `c` dials c, then b, then a.
  List<SshTarget> get chain => [...?jumpTarget?.chain, this];

  SshTarget copyWith({
    String? hostname,
    int? port,
    String? username,
    SshAuthMethod? authMethod,
    String? identityId,
    bool clearIdentityId = false,
    String? credentialId,
    SshTarget? jumpTarget,
    bool clearJumpTarget = false,
    bool? allowLegacyAlgorithms,
    Duration? keepaliveInterval,
  }) => SshTarget(
    hostname: hostname ?? this.hostname,
    port: port ?? this.port,
    username: username ?? this.username,
    authMethod: authMethod ?? this.authMethod,
    identityId: clearIdentityId ? null : (identityId ?? this.identityId),
    credentialId: credentialId ?? this.credentialId,
    jumpTarget: clearJumpTarget ? null : (jumpTarget ?? this.jumpTarget),
    allowLegacyAlgorithms: allowLegacyAlgorithms ?? this.allowLegacyAlgorithms,
    keepaliveInterval: keepaliveInterval ?? this.keepaliveInterval,
  );

  @override
  bool operator ==(Object other) =>
      other is SshTarget &&
      other.hostname == hostname &&
      other.port == port &&
      other.username == username &&
      other.authMethod == authMethod &&
      other.identityId == identityId &&
      other.credentialId == credentialId &&
      other.jumpTarget == jumpTarget &&
      other.allowLegacyAlgorithms == allowLegacyAlgorithms &&
      other.keepaliveInterval == keepaliveInterval;

  @override
  int get hashCode => Object.hash(
    hostname,
    port,
    username,
    authMethod,
    identityId,
    credentialId,
    jumpTarget,
    allowLegacyAlgorithms,
    keepaliveInterval,
  );

  /// Prints the address only — never the identity, never a credential.
  @override
  String toString() => 'SshTarget($address)';
}
