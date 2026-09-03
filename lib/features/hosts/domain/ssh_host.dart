import '../../../core/ssh/ssh_target.dart';

/// A saved server.
///
/// This is **configuration**, not a secret store: it holds the address, the
/// account and *which* identity to use — never a password, never a passphrase,
/// never key material. Those live in the `SecretVault`, addressed by [id].
class SshHost {
  const SshHost({
    required this.id,
    required this.label,
    required this.hostname,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
    this.groupId,
    this.port = 22,
    this.authMethod = SshAuthMethod.publicKey,
    this.identityId,
    this.jumpHostId,
    this.allowLegacyAlgorithms = false,
    this.startupCommand,
    this.keepaliveSeconds = 30,
    this.terminalTheme,
    this.fontSize,
    this.notes,
    this.tags = const [],
    this.lastConnectedAt,
  });

  final String id;
  final String? groupId;

  /// What the user calls it. Distinct from [hostname], which is where it is.
  final String label;

  final String hostname;
  final int port;
  final String username;
  final SshAuthMethod authMethod;
  final String? identityId;

  /// The saved host to reach this one through (`ProxyJump`).
  final String? jumpHostId;

  final bool allowLegacyAlgorithms;

  /// Run once the shell opens. The obvious use is `tmux new -A -s main`,
  /// which is also the best answer to a phone killing a backgrounded session.
  final String? startupCommand;

  final int keepaliveSeconds;
  final String? terminalTheme;
  final double? fontSize;
  final String? notes;
  final List<String> tags;
  final DateTime? lastConnectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `user@host:port`. Carries no secret.
  String get address => '$username@$hostname${port == 22 ? '' : ':$port'}';

  /// Whether [query] matches this host, for the search field.
  ///
  /// Deliberately searches the address and tags too, not just the label:
  /// people remember "the box on 10.0.0.4" as often as they remember what
  /// they named it.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label.toLowerCase().contains(needle) ||
        hostname.toLowerCase().contains(needle) ||
        username.toLowerCase().contains(needle) ||
        tags.any((t) => t.toLowerCase().contains(needle));
  }

  /// The transport's view of this host, with [jumpTarget] already resolved.
  ///
  /// Resolving the chain is the repository's job, not the model's: it needs
  /// to look other rows up, and a model that reaches into a database is a
  /// model you cannot construct in a test.
  SshTarget toTarget({SshTarget? jumpTarget}) => SshTarget(
    hostname: hostname,
    port: port,
    username: username,
    authMethod: authMethod,
    identityId: identityId,
    // The host's own id, so the credential source can find this host's saved
    // password. It addresses secrets; it carries none.
    credentialId: id,
    jumpTarget: jumpTarget,
    allowLegacyAlgorithms: allowLegacyAlgorithms,
    keepaliveInterval: Duration(seconds: keepaliveSeconds),
  );

  SshHost copyWith({
    String? label,
    String? hostname,
    int? port,
    String? username,
    String? groupId,
    bool clearGroupId = false,
    SshAuthMethod? authMethod,
    String? identityId,
    bool clearIdentityId = false,
    String? jumpHostId,
    bool clearJumpHostId = false,
    bool? allowLegacyAlgorithms,
    String? startupCommand,
    bool clearStartupCommand = false,
    int? keepaliveSeconds,
    String? terminalTheme,
    double? fontSize,
    String? notes,
    List<String>? tags,
    DateTime? lastConnectedAt,
    DateTime? updatedAt,
  }) => SshHost(
    id: id,
    label: label ?? this.label,
    hostname: hostname ?? this.hostname,
    port: port ?? this.port,
    username: username ?? this.username,
    groupId: clearGroupId ? null : (groupId ?? this.groupId),
    authMethod: authMethod ?? this.authMethod,
    identityId: clearIdentityId ? null : (identityId ?? this.identityId),
    jumpHostId: clearJumpHostId ? null : (jumpHostId ?? this.jumpHostId),
    allowLegacyAlgorithms: allowLegacyAlgorithms ?? this.allowLegacyAlgorithms,
    startupCommand: clearStartupCommand
        ? null
        : (startupCommand ?? this.startupCommand),
    keepaliveSeconds: keepaliveSeconds ?? this.keepaliveSeconds,
    terminalTheme: terminalTheme ?? this.terminalTheme,
    fontSize: fontSize ?? this.fontSize,
    notes: notes ?? this.notes,
    tags: tags ?? this.tags,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Deliberately prints the address only — never the identity id.
  @override
  String toString() => 'SshHost($id, $label, $address)';
}
