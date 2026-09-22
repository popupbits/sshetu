import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/providers.dart';
import '../../../core/ssh/sftp_service.dart';
import '../../../core/terminal/terminal_session.dart';
import '../../server_info/data/server_exec.dart';
import '../../server_info/data/server_info_service.dart';
import '../../server_info/domain/stats_math.dart';
import '../../sessions/session_manager.dart';
import '../../snippets/snippet_delivery.dart';
import '../../tunnels/domain/tunnel.dart';
import '../../tunnels/tunnels_controller.dart';
import '../domain/mcp_backend.dart';
import '../domain/mcp_tool.dart';
import '../domain/output_capture.dart';
import '../mcp_ui_bridge.dart';
import 'terminal_text.dart' as screen;

/// [McpBackend] over the app's own providers: the host and tunnel
/// repositories, the session manager, the tunnel runners, the server-info
/// service, snippet delivery and the SFTP service. Nothing here re-implements
/// what those already do.
class RiverpodMcpBackend implements McpBackend {
  RiverpodMcpBackend(this._ref, this._slot);

  final Ref _ref;
  final McpUiBridgeSlot _slot;

  SessionManager get _manager => _ref.read(sessionManagerProvider.notifier);

  TerminalSession _session(String id) =>
      _manager.byId(id) ??
      (throw McpToolException('No open session with id "$id".'));

  TerminalSession _liveSession(String id) {
    final session = _session(id);
    if (!session.isLive) {
      throw McpToolException('Session "$id" is not connected.');
    }
    return session;
  }

  McpUiBridge get _bridge =>
      _slot.current ??
      (throw const McpToolException(
        'SSHetu\'s window is not ready, so this cannot be done now.',
      ));

  @override
  Future<List<HostSummary>> hosts() async {
    final groups = {
      for (final group in await _ref.read(hostGroupRepositoryProvider).all())
        group.id: group.name,
    };
    return [
      for (final host in await _ref.read(hostRepositoryProvider).all())
        HostSummary(
          id: host.id,
          label: host.label,
          hostname: host.hostname,
          port: host.port,
          username: host.username,
          group: groups[host.groupId],
          tags: host.tags,
        ),
    ];
  }

  SessionSummary _summary(TerminalSession session, String? activeId) =>
      SessionSummary(
        id: session.id,
        title: session.title,
        hostId: session.hostId,
        hostname: session.target.hostname,
        username: session.target.username,
        port: session.target.port,
        status: session.status.name,
        isActive: session.id == activeId,
        error: session.error,
      );

  @override
  List<SessionSummary> sessions() {
    final active = _manager.activeId;
    return [
      for (final session in _ref.read(sessionManagerProvider))
        _summary(session, active),
    ];
  }

  @override
  String terminalTail(String sessionId, int lines) =>
      screen.terminalTail(_session(sessionId).terminal, lines);

  @override
  Future<Map<String, Object?>> serverInfo(String sessionId) async {
    final session = _liveSession(sessionId);
    final service = ServerInfoService(ConnectionExec(session.connection));
    // Two samples a second apart: CPU use is a difference, not a reading.
    final first = await service.sample();
    await Future<void>.delayed(const Duration(seconds: 1));
    final sample = await service.sample();
    final cpu = cpuPercentBetween(first.cpu, sample.cpu);
    final identity = sample.identity;
    final memory = sample.memory;
    final load = sample.load;
    return {
      'hostname': ?identity.hostname,
      'os': ?identity.osName,
      'kernel': ?[
        identity.kernelName,
        identity.kernelRelease,
      ].whereType<String>().join(' ').nullIfEmpty,
      'cpu_count': ?identity.cpuCount,
      'cpu_percent': ?cpu == null ? null : double.parse(cpu.toStringAsFixed(1)),
      if (memory != null)
        'memory': {
          'total_bytes': memory.totalBytes,
          'used_bytes': memory.usedBytes,
          'available_bytes': memory.availableBytes,
          'swap_total_bytes': ?memory.swapTotalBytes,
          'swap_used_bytes': ?memory.swapUsedBytes,
        },
      if (load != null)
        'load_average': {'1m': load.one, '5m': load.five, '15m': load.fifteen},
      'uptime_seconds': ?sample.uptime?.inSeconds,
      'process_count': ?sample.processCount,
      if (sample.filesystems case final filesystems?)
        'filesystems': [
          for (final fs in filesystems)
            {
              'mount': fs.mountPoint,
              'source': fs.source,
              'total_bytes': fs.totalBytes,
              'used_bytes': fs.usedBytes,
              'available_bytes': fs.availableBytes,
            },
        ],
      if (sample.isLimited)
        'note': 'This server reported little about its resources.',
    };
  }

  @override
  Future<List<TunnelSummary>> tunnels() async {
    final labels = {
      for (final host in await _ref.read(hostRepositoryProvider).all())
        host.id: host.label,
    };
    final runners = _ref.read(tunnelRunnersProvider.notifier);
    return [
      for (final tunnel in await _ref.read(tunnelRepositoryProvider).all())
        _tunnelSummary(tunnel, labels[tunnel.hostId], runners),
    ];
  }

  TunnelSummary _tunnelSummary(
    Tunnel tunnel,
    String? hostLabel,
    TunnelRunnerManager runners,
  ) {
    final status = runners.statusFor(tunnel.id);
    return TunnelSummary(
      id: tunnel.id,
      label: tunnel.label,
      hostId: tunnel.hostId,
      hostLabel: hostLabel ?? tunnel.hostId,
      kind: tunnel.kind.storageValue,
      mapping: tunnel.mapping,
      autoStart: tunnel.autoStart,
      state: status.state.name,
      boundPort: status.boundPort,
      connections: status.connections,
      error: status.error,
    );
  }

  Future<TunnelSummary> _tunnelSummaryFor(Tunnel tunnel) async {
    final host = await _ref.read(hostRepositoryProvider).byId(tunnel.hostId);
    return _tunnelSummary(
      tunnel,
      host?.label,
      _ref.read(tunnelRunnersProvider.notifier),
    );
  }

  @override
  Future<List<SnippetSummary>> snippets() async => [
    for (final snippet in await _ref.read(snippetRepositoryProvider).all())
      SnippetSummary(
        id: snippet.id,
        label: snippet.label,
        body: snippet.body,
        description: snippet.description,
        tags: snippet.tags,
      ),
  ];

  Future<String> _capturing(
    TerminalSession session,
    Duration wait,
    void Function() send,
  ) async {
    final capture = OutputCapture();
    session.addOutputListener(capture.add);
    try {
      send();
      return await capture.settle(max: wait);
    } finally {
      session.removeOutputListener(capture.add);
    }
  }

  @override
  Future<String> typeLines(String sessionId, String text, Duration wait) {
    final session = _liveSession(sessionId);
    return _capturing(session, wait, () {
      // Typed into this session only. With "type in all panes" on, the
      // tab's broadcast listens on onInput and would carry the command to
      // panes the user never approved it for.
      final broadcast = session.onInput;
      session.onInput = null;
      final SnippetDeliveryResult result;
      try {
        result = deliverSnippet(
          SnippetTarget.fromSession(session),
          text,
          SnippetAction.run,
        );
      } finally {
        session.onInput = broadcast;
      }
      switch (result) {
        case SnippetDeliveryResult.sent:
          return;
        case SnippetDeliveryResult.notLive:
          throw McpToolException('Session "$sessionId" is not connected.');
        case SnippetDeliveryResult.empty:
        case SnippetDeliveryResult.multilineNeedsBracketedPaste:
          throw const McpToolException(
            'Nothing was left to type once control characters were removed.',
          );
      }
    });
  }

  @override
  Future<String> sendRaw(String sessionId, String data, Duration wait) {
    final session = _liveSession(sessionId);
    return _capturing(session, wait, () => session.send(data));
  }

  @override
  Future<SessionSummary> openSession(String hostId) async {
    final host = await _ref.read(hostRepositoryProvider).byId(hostId);
    if (host == null) {
      throw McpToolException('No saved host with id "$hostId".');
    }
    final session = await _bridge.openSession(host);
    if (session == null) {
      throw const McpToolException(
        'The session was not opened — the connection failed or the user '
        'cancelled a prompt. SSHetu shows the reason.',
      );
    }
    return _summary(session, _manager.activeId);
  }

  Future<Tunnel> _tunnel(String id) async =>
      await _ref.read(tunnelRepositoryProvider).byId(id) ??
      (throw McpToolException('No saved tunnel with id "$id".'));

  @override
  Future<TunnelSummary> startTunnel(String tunnelId) async {
    final tunnel = await _tunnel(tunnelId);
    await _bridge.startTunnel(tunnel);
    return _tunnelSummaryFor(tunnel);
  }

  @override
  Future<TunnelSummary> stopTunnel(String tunnelId) async {
    final tunnel = await _tunnel(tunnelId);
    await _ref.read(tunnelRunnersProvider.notifier).stop(tunnel);
    return _tunnelSummaryFor(tunnel);
  }

  Future<T> _withSftp<T>(
    String sessionId,
    Future<T> Function(SftpService sftp) body,
  ) async {
    final session = _liveSession(sessionId);
    final sftp = SshSftpService(session.connection);
    try {
      return await body(sftp);
    } on SftpException catch (error) {
      throw McpToolException(error.message);
    } finally {
      await sftp.close();
    }
  }

  static Future<String> _resolve(SftpService sftp, String path) async =>
      path.startsWith('~') ? sftp.resolveRemotePath(path) : path;

  @override
  Future<TransferSummary> download({
    required String sessionId,
    required String remotePath,
    required String localPath,
    required bool overwrite,
  }) => _withSftp(sessionId, (sftp) async {
    final local = File(localPath);
    if (!overwrite && await local.exists()) {
      throw McpToolException(
        '$localPath already exists. Pass "overwrite": true to replace it.',
      );
    }
    if (!await Directory(p.dirname(localPath)).exists()) {
      throw McpToolException('The folder for $localPath does not exist.');
    }
    final remote = await _resolve(sftp, remotePath);
    switch (await sftp.statPath(remote)) {
      case RemotePathKind.missing:
        throw McpToolException('$remote does not exist on the server.');
      case RemotePathKind.directory:
        throw McpToolException('$remote is a folder; name a file.');
      case RemotePathKind.file:
        break;
    }
    await sftp.download(remotePath: remote, localPath: localPath);
    return TransferSummary(
      remotePath: remote,
      localPath: localPath,
      bytes: await local.length(),
    );
  });

  @override
  Future<TransferSummary> upload({
    required String sessionId,
    required String localPath,
    required String remotePath,
    required bool overwrite,
  }) => _withSftp(sessionId, (sftp) async {
    final local = File(localPath);
    if (!await local.exists()) {
      throw McpToolException('$localPath does not exist on this computer.');
    }
    final remote = await _resolve(sftp, remotePath);
    switch (await sftp.statPath(remote)) {
      case RemotePathKind.directory:
        throw McpToolException(
          '$remote is a folder; name the file to create in it.',
        );
      case RemotePathKind.file when !overwrite:
        throw McpToolException(
          '$remote already exists. Pass "overwrite": true to replace it.',
        );
      case RemotePathKind.file:
      case RemotePathKind.missing:
        break;
    }
    await sftp.upload(localPath: localPath, remotePath: remote);
    return TransferSummary(
      remotePath: remote,
      localPath: localPath,
      bytes: await local.length(),
    );
  });
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
