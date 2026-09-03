/// A saved SSH port forward, mirroring the `tunnels` table.
///
/// This is configuration, the same as [SshHost] — no secret lives here.
/// Starting one still needs the host's credentials, but those are resolved
/// through the same connection layer a terminal session uses.
class Tunnel {
  const Tunnel({
    required this.id,
    required this.hostId,
    required this.label,
    required this.kind,
    required this.listenPort,
    required this.createdAt,
    required this.updatedAt,
    this.listenHost = defaultListenHost,
    this.targetHost,
    this.targetPort,
    this.autoStart = false,
  });

  final String id;
  final String hostId;
  final String label;
  final TunnelKind kind;

  /// Defaults to loopback. Binding `0.0.0.0` puts the forward on the whole
  /// network, so the editor must make that an explicit, warned choice — never
  /// what a blank field quietly becomes.
  final String listenHost;
  final int listenPort;

  /// Null for [TunnelKind.socks], which resolves a target per-connection
  /// instead of forwarding to one fixed place.
  final String? targetHost;
  final int? targetPort;

  final bool autoStart;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const String defaultListenHost = '127.0.0.1';

  static const Set<String> _loopbackHosts = {'127.0.0.1', 'localhost', '::1'};

  /// Whether [listenHost] is confined to this device.
  bool get isListenLoopback => isLoopbackHost(listenHost);

  /// Standalone so the editor can warn about a host string as the user types
  /// it, before there is a [Tunnel] to ask.
  static bool isLoopbackHost(String host) => _loopbackHosts.contains(host);

  /// `listen → target`, in a form that lines up in a monospace column: the
  /// tile and the editor's preview line both use it, and a forward with no
  /// fixed target (SOCKS) says so instead of printing `null:null`.
  String get mapping {
    final listen = '$listenHost:$listenPort';
    if (!kind.requiresTarget) return listen;
    return '$listen → $targetHost:$targetPort';
  }

  /// A port is only ever wrong for one reason here: SSH channels and TCP
  /// sockets both use the 1–65535 range, and `0` ("assign one for me") is
  /// excluded on purpose — a forward the user cannot see the port of is not
  /// one they can point a client at.
  static bool isValidPort(int? port) =>
      port != null && port >= 1 && port <= 65535;

  Tunnel copyWith({
    String? label,
    TunnelKind? kind,
    String? listenHost,
    int? listenPort,
    String? targetHost,
    bool clearTargetHost = false,
    int? targetPort,
    bool clearTargetPort = false,
    bool? autoStart,
    DateTime? updatedAt,
  }) => Tunnel(
    id: id,
    hostId: hostId,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    listenHost: listenHost ?? this.listenHost,
    listenPort: listenPort ?? this.listenPort,
    targetHost: clearTargetHost ? null : (targetHost ?? this.targetHost),
    targetPort: clearTargetPort ? null : (targetPort ?? this.targetPort),
    autoStart: autoStart ?? this.autoStart,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() => 'Tunnel($id, $label, ${kind.storageValue}, $mapping)';
}

/// How a forward moves bytes. Matches `ssh -L` / `-R` / `-D`.
enum TunnelKind {
  /// Bind here, forward to the target through the SSH connection — `ssh -L`.
  local,

  /// Ask the server to bind, forward back to the target from here —
  /// `ssh -R`.
  remote,

  /// A local SOCKS5 proxy with no fixed target — `ssh -D`.
  ///
  /// Named `socks` rather than `dynamic`: the latter is a reserved word in
  /// Dart and cannot be an enum member, and "SOCKS" is what OpenSSH itself
  /// calls a `-D` forward, so [storageValue] is the only place the schema's
  /// own word ("dynamic") needs to appear.
  socks;

  /// The value persisted in `tunnels.kind`.
  String get storageValue => switch (this) {
    TunnelKind.local => 'local',
    TunnelKind.remote => 'remote',
    TunnelKind.socks => 'dynamic',
  };

  static TunnelKind fromStorage(String value) => switch (value) {
    'remote' => TunnelKind.remote,
    'dynamic' => TunnelKind.socks,
    // A value written by a newer version of the app must not crash an older
    // one; 'local' is the safe reading — it is the only kind that cannot
    // reach further into the network than the user already configured.
    _ => TunnelKind.local,
  };

  /// Whether this kind forwards to one fixed place, and so needs
  /// [Tunnel.targetHost] / [Tunnel.targetPort].
  bool get requiresTarget => this != TunnelKind.socks;
}
