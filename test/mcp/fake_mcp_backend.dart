import 'package:sshetu/features/mcp/domain/mcp_backend.dart';
import 'package:sshetu/features/mcp/domain/mcp_tool.dart';

/// An [McpBackend] with no app behind it: fixed data, and a record of every
/// act call so a test can prove what ran — and what did not.
class FakeMcpBackend implements McpBackend {
  FakeMcpBackend({
    List<HostSummary>? hosts,
    List<SessionSummary>? sessions,
    List<TunnelSummary>? tunnels,
    List<SnippetSummary>? snippets,
  }) : hostList = hosts ?? [webHost, dbHost],
       sessionList = sessions ?? [liveSession, closedSession],
       tunnelList = tunnels ?? [webTunnel],
       snippetList = snippets ?? [restartSnippet];

  static const webHost = HostSummary(
    id: 'h-web',
    label: 'web-1',
    hostname: '10.0.0.4',
    port: 22,
    username: 'deploy',
    group: 'Production',
    tags: ['prod', 'web'],
  );

  static const dbHost = HostSummary(
    id: 'h-db',
    label: 'db',
    hostname: 'db.internal',
    port: 2222,
    username: 'root',
    tags: ['prod'],
  );

  static const liveSession = SessionSummary(
    id: 's-1',
    title: 'web-1',
    hostId: 'h-web',
    hostname: '10.0.0.4',
    username: 'deploy',
    port: 22,
    status: 'running',
    isActive: true,
  );

  static const closedSession = SessionSummary(
    id: 's-2',
    title: 'db',
    hostId: 'h-db',
    hostname: 'db.internal',
    username: 'root',
    port: 2222,
    status: 'closed',
    isActive: false,
  );

  static const webTunnel = TunnelSummary(
    id: 't-1',
    label: 'Postgres',
    hostId: 'h-db',
    hostLabel: 'db',
    kind: 'local',
    mapping: '127.0.0.1:5432 → localhost:5432',
    autoStart: false,
    state: 'stopped',
  );

  static const restartSnippet = SnippetSummary(
    id: 'sn-1',
    label: 'Restart a service',
    body: 'sudo systemctl restart {{service}} # on {{host}} {{level:info}}',
    tags: ['ops'],
  );

  final List<HostSummary> hostList;
  final List<SessionSummary> sessionList;
  final List<TunnelSummary> tunnelList;
  final List<SnippetSummary> snippetList;

  /// Every act call, in order: `typeLines s-1 ls`, `openSession h-web`…
  final calls = <String>[];

  String output = 'output\n';
  String screen = 'line 1\nline 2\n\$ ';

  @override
  Future<List<HostSummary>> hosts() async => hostList;

  @override
  List<SessionSummary> sessions() => sessionList;

  SessionSummary _session(String id) => sessionList.firstWhere(
    (s) => s.id == id,
    orElse: () => throw McpToolException('no session $id'),
  );

  @override
  String terminalTail(String sessionId, int lines) {
    _session(sessionId);
    final all = screen.split('\n');
    return all.skip(all.length > lines ? all.length - lines : 0).join('\n');
  }

  @override
  Future<Map<String, Object?>> serverInfo(String sessionId) async => {
    'hostname': 'web-1',
    'cpu_count': 4,
  };

  @override
  Future<List<TunnelSummary>> tunnels() async => tunnelList;

  @override
  Future<List<SnippetSummary>> snippets() async => snippetList;

  @override
  Future<String> typeLines(String sessionId, String text, Duration wait) async {
    calls.add('typeLines $sessionId $text ${wait.inSeconds}');
    return output;
  }

  @override
  Future<String> sendRaw(String sessionId, String data, Duration wait) async {
    calls.add('sendRaw $sessionId $data');
    return output;
  }

  @override
  Future<SessionSummary> openSession(String hostId) async {
    calls.add('openSession $hostId');
    return liveSession;
  }

  @override
  Future<TunnelSummary> startTunnel(String tunnelId) async {
    calls.add('startTunnel $tunnelId');
    return webTunnel;
  }

  @override
  Future<TunnelSummary> stopTunnel(String tunnelId) async {
    calls.add('stopTunnel $tunnelId');
    return webTunnel;
  }

  @override
  Future<TransferSummary> download({
    required String sessionId,
    required String remotePath,
    required String localPath,
    required bool overwrite,
  }) async {
    calls.add('download $sessionId $remotePath $localPath $overwrite');
    return TransferSummary(
      remotePath: remotePath,
      localPath: localPath,
      bytes: 3,
    );
  }

  @override
  Future<TransferSummary> upload({
    required String sessionId,
    required String localPath,
    required String remotePath,
    required bool overwrite,
  }) async {
    calls.add('upload $sessionId $localPath $remotePath $overwrite');
    return TransferSummary(
      remotePath: remotePath,
      localPath: localPath,
      bytes: 3,
    );
  }
}
