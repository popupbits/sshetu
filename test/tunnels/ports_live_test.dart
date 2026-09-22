@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/host_key_verifier.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/tunnel_runner.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/tunnels/domain/far_end.dart';
import 'package:sshetu/features/tunnels/domain/free_port.dart';
import 'package:sshetu/features/tunnels/domain/listening_ports.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';
import 'package:sshetu/features/tunnels/ports_monitor.dart';

/// Detected ports and far-end checks against a **real** Linux sshd with a
/// listener already running on it (for example
/// `python3 -m http.server 18080 --bind 127.0.0.1`).
///
///     SSHETU_PORTS_LIVE_SSH    user@host:port of the server
///     SSHETU_PORTS_LIVE_KEY    path to an unencrypted private key it accepts
///     SSHETU_PORTS_LIVE_HTTP   the port the HTTP listener is on
///
///     flutter test --tags live test/tunnels/ports_live_test.dart
void main() {
  final env = Platform.environment;
  final address = env['SSHETU_PORTS_LIVE_SSH'];
  final keyPath = env['SSHETU_PORTS_LIVE_KEY'];
  final httpPort = int.tryParse(env['SSHETU_PORTS_LIVE_HTTP'] ?? '');
  final skip = address == null || keyPath == null || httpPort == null
      ? 'SSHETU_PORTS_LIVE_SSH, _KEY and _HTTP are not set'
      : null;

  late SshConnection connection;
  late int sshPort;

  setUpAll(() async {
    if (skip != null) return;
    final match = RegExp(r'^([^@]+)@([^:]+):(\d+)$').firstMatch(address!)!;
    sshPort = int.parse(match[3]!);
    final vault = InMemorySecretVault();
    await vault.write(
      const SecretRef.identityPrivateKey('live-key'),
      await File(keyPath!).readAsString(),
    );
    connection = SshConnection(
      target: SshTarget(
        hostname: match[2]!,
        port: sshPort,
        username: match[1]!,
        identityId: 'live-key',
        credentialId: 'live-host',
      ),
      verifierFactory: (hostname, port) => SshHostKeyVerifier(
        knownHosts: InMemoryKnownHostsStore(),
        hostname: hostname,
        port: port,
        onUnknownHostKey: (_) => true,
      ),
      credentials: VaultCredentialSource(
        vault: vault,
        catalog: () async => const [],
      ),
    );
    await connection.client();
  });

  tearDownAll(() async {
    if (skip != null) return;
    await connection.close();
  });

  test('lists the listener, with its process, and hides sshd', () async {
    final ports = await listListeningPorts(ConnectionExec(connection));
    final http = ports.firstWhere((p) => p.port == httpPort);
    expect(http.process, startsWith('python'));
    expect(http.isLoopbackOnly, isTrue);
    expect(http.targetHost, '127.0.0.1');

    final shown = visiblePorts(ports, alsoIgnore: {sshPort});
    expect(shown.map((p) => p.port), contains(httpPort));
    expect(shown.map((p) => p.port), isNot(contains(sshPort)));
  }, skip: skip);

  test(
    'an ad-hoc style forward reaches it, and the far end checks out',
    () async {
      final local = await pickLocalPort(httpPort!) ?? 0;
      final now = DateTime.now().toUtc();
      final runner = TunnelRunner(
        tunnel: Tunnel(
          id: 'adhoc-live',
          hostId: 'live',
          label: 'live',
          kind: TunnelKind.local,
          listenPort: local,
          targetHost: '127.0.0.1',
          targetPort: httpPort,
          createdAt: now,
          updatedAt: now,
        ),
        connect: connection.client,
      );
      addTearDown(runner.dispose);
      await runner.start();
      expect(runner.status.isRunning, isTrue, reason: '${runner.status}');
      final bound = runner.status.boundPort!;

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.get('127.0.0.1', bound, '/');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 200);
      expect(body, contains('hello from sst'));

      // Wait for the HTTP connection to finish piping, then check the far end:
      // it must answer, and must not show up as one of the connections.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final before = runner.status.connections;
      expect(await runner.probeTarget(), FarEndStatus.listening);
      expect(runner.status.connections, before);
    },
    skip: skip,
  );

  test('a far end with nothing on it says so', () async {
    final now = DateTime.now().toUtc();
    final runner = TunnelRunner(
      tunnel: Tunnel(
        id: 'dead-live',
        hostId: 'live',
        label: 'dead',
        kind: TunnelKind.local,
        listenPort: await pickLocalPort(47000) ?? 0,
        targetHost: '127.0.0.1',
        // Reserved, and nothing listens there on a test box.
        targetPort: 1,
        createdAt: now,
        updatedAt: now,
      ),
      connect: connection.client,
    );
    addTearDown(runner.dispose);
    await runner.start();
    expect(runner.status.isRunning, isTrue);
    expect(await runner.probeTarget(), FarEndStatus.notListening);
  }, skip: skip);
}
