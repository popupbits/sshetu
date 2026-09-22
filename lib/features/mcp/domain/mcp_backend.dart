/// What the MCP tools need from the rest of the app, and nothing more.
///
/// The tools talk to this, never to providers, so each one is tested against
/// a fake. The real one (`data/riverpod_mcp_backend.dart`) calls the same
/// repositories, session manager, tunnel runners and SFTP service the UI
/// does — no logic is duplicated for the integration.
///
/// **No secrets cross this line.** Every summary here is built from
/// configuration a list row already shows: no password, key, passphrase,
/// vault content, host notes (people keep passwords in notes) or known-hosts
/// pin appears in any of them.
library;

class HostSummary {
  const HostSummary({
    required this.id,
    required this.label,
    required this.hostname,
    required this.port,
    required this.username,
    this.group,
    this.tags = const [],
  });

  final String id;
  final String label;
  final String hostname;
  final int port;
  final String username;
  final String? group;
  final List<String> tags;

  String get address => '$username@$hostname:$port';

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'address': address,
    'hostname': hostname,
    'port': port,
    'username': username,
    'group': group,
    'tags': tags,
  };
}

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.title,
    required this.hostId,
    required this.hostname,
    required this.username,
    required this.port,
    required this.status,
    required this.isActive,
    this.error,
  });

  final String id;

  /// The tab's title — the host's label.
  final String title;
  final String hostId;
  final String hostname;
  final String username;
  final int port;

  /// `connecting`, `running`, `closed` or `failed`.
  final String status;

  /// Whether this is the tab the window is showing.
  final bool isActive;
  final String? error;

  bool get isLive => status == 'running';
  String get address => '$username@$hostname:$port';

  /// How an approval dialog names this session: label, address, id.
  String get describe => '$title — $address (session $id)';

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'host_id': hostId,
    'address': address,
    'status': status,
    'active': isActive,
    'error': ?error,
  };
}

class TunnelSummary {
  const TunnelSummary({
    required this.id,
    required this.label,
    required this.hostId,
    required this.hostLabel,
    required this.kind,
    required this.mapping,
    required this.autoStart,
    required this.state,
    this.boundPort,
    this.connections,
    this.error,
  });

  final String id;
  final String label;
  final String hostId;
  final String hostLabel;

  /// `local`, `remote` or `dynamic`.
  final String kind;

  /// `listen → target`, as the Tunnels screen shows it.
  final String mapping;
  final bool autoStart;

  /// `stopped`, `starting`, `running` or `failed`.
  final String state;
  final int? boundPort;
  final int? connections;
  final String? error;

  String get describe => '$label — $kind $mapping via $hostLabel';

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'host_id': hostId,
    'host': hostLabel,
    'kind': kind,
    'mapping': mapping,
    'auto_start': autoStart,
    'state': state,
    'bound_port': ?boundPort,
    'connections': ?connections,
    'error': ?error,
  };
}

class SnippetVariableSummary {
  const SnippetVariableSummary(this.name, {this.defaultValue});

  final String name;
  final String? defaultValue;

  Map<String, Object?> toJson() => {'name': name, 'default': ?defaultValue};
}

class SnippetSummary {
  const SnippetSummary({
    required this.id,
    required this.label,
    required this.body,
    this.description,
    this.tags = const [],
  });

  final String id;
  final String label;
  final String body;
  final String? description;
  final List<String> tags;
}

/// A transfer that finished.
class TransferSummary {
  const TransferSummary({
    required this.remotePath,
    required this.localPath,
    required this.bytes,
  });

  final String remotePath;
  final String localPath;
  final int bytes;

  Map<String, Object?> toJson() => {
    'remote_path': remotePath,
    'local_path': localPath,
    'bytes': bytes,
  };
}

/// Throws `McpToolException` for anything the client should be told —
/// an unknown id, a session that is not connected.
abstract interface class McpBackend {
  Future<List<HostSummary>> hosts();

  List<SessionSummary> sessions();

  /// The last [lines] lines of [sessionId]'s terminal buffer, as plain text.
  String terminalTail(String sessionId, int lines);

  /// One sample of the server-info panel's stats, over the session's own
  /// connection.
  Future<Map<String, Object?>> serverInfo(String sessionId);

  Future<List<TunnelSummary>> tunnels();

  Future<List<SnippetSummary>> snippets();

  /// Types [text] into [sessionId] line by line, each followed by Enter —
  /// the snippet Run path — then collects output for up to [wait].
  Future<String> typeLines(String sessionId, String text, Duration wait);

  /// Sends [data] to [sessionId]'s shell exactly as given, then collects
  /// output for up to [wait].
  Future<String> sendRaw(String sessionId, String data, Duration wait);

  /// Opens a new tab to [hostId] through the ordinary connect flow, with its
  /// host-key and password dialogs.
  Future<SessionSummary> openSession(String hostId);

  Future<TunnelSummary> startTunnel(String tunnelId);

  Future<TunnelSummary> stopTunnel(String tunnelId);

  Future<TransferSummary> download({
    required String sessionId,
    required String remotePath,
    required String localPath,
    required bool overwrite,
  });

  Future<TransferSummary> upload({
    required String sessionId,
    required String localPath,
    required String remotePath,
    required bool overwrite,
  });
}
