@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/host_key_verifier.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_connection_state.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/server_info/data/server_info_service.dart';
import 'package:sshetu/features/server_info/domain/host_os.dart';
import 'package:sshetu/features/server_info/domain/process_list.dart';
import 'package:sshetu/features/server_info/domain/stats_parser.dart';
import 'package:sshetu/features/server_info/server_stats_monitor.dart';

/// Server info against a **real** Linux sshd.
///
///     SSHETU_INFO_LIVE_SSH   user@host:port of a Linux server
///     SSHETU_INFO_LIVE_KEY   path to an unencrypted private key it accepts
///
///     flutter test --tags live test/server_info/server_info_live_test.dart
void main() {
  final env = Platform.environment;
  final address = env['SSHETU_INFO_LIVE_SSH'];
  final keyPath = env['SSHETU_INFO_LIVE_KEY'];
  final skip = address == null || keyPath == null
      ? 'SSHETU_INFO_LIVE_SSH and SSHETU_INFO_LIVE_KEY are not set'
      : null;

  late SshConnection connection;
  late ConnectionExec exec;
  final states = <SshConnectionStatus>[];

  setUpAll(() async {
    if (skip != null) return;
    final match = RegExp(r'^([^@]+)@([^:]+):(\d+)$').firstMatch(address!)!;
    final vault = InMemorySecretVault();
    await vault.write(
      const SecretRef.identityPrivateKey('live-key'),
      await File(keyPath!).readAsString(),
    );
    connection = SshConnection(
      target: SshTarget(
        hostname: match[2]!,
        port: int.parse(match[3]!),
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
    connection.states.listen((s) => states.add(s.status));
    await connection.client();
    exec = ConnectionExec(connection);
  });

  tearDownAll(() async {
    if (skip != null) return;
    await connection.close();
  });

  test('polls ride one connection and parse a real /proc', () async {
    final monitor = ServerStatsMonitor(exec);
    addTearDown(monitor.dispose);
    await monitor.poll();
    await Future<void>.delayed(const Duration(seconds: 2));
    await monitor.poll();
    await Future<void>.delayed(const Duration(seconds: 1));
    await monitor.poll();

    expect(monitor.status, MonitorStatus.ready);
    final stats = monitor.stats!;
    final sample = stats.sample;
    expect(sample.identity.kernelName, 'Linux');
    expect(sample.identity.hostname, isNotEmpty);
    expect(sample.identity.cpuCount, greaterThan(0));
    expect(sample.memory!.totalBytes, greaterThan(0));
    expect(sample.load, isNotNull);
    expect(sample.uptime, isNotNull);
    expect(sample.filesystems, isNotEmpty);
    expect(
      sample.filesystems!.where((fs) => !isPseudoFilesystem(fs)),
      isNotEmpty,
    );
    expect(sample.net, isNotNull);
    expect(stats.cpuPercent, inInclusiveRange(0, 100));
    expect(stats.rxBytesPerSecond, greaterThanOrEqualTo(0));
    expect(monitor.cpuHistory, hasLength(2));

    // Exactly one handshake for all of it.
    expect(
      states.where((s) => s == SshConnectionStatus.connected),
      hasLength(1),
    );
  });

  test('processes: listed, SIGTERM works, a refusal says why', () async {
    final service = ServerInfoService(exec);
    final listing = await service.processes();
    expect(listing.hasCpu, isTrue);
    expect(listing.processes, isNotEmpty);

    final started = await exec.run(
      r'sh -c "nohup sleep 300 >/dev/null 2>&1 & echo \$!"',
    );
    final pid = int.parse(started.stdout.trim());
    await service.kill(pid, KillSignal.term);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final gone = await exec.run('kill -0 $pid');
    expect(gone.succeeded, isFalse, reason: 'sleep $pid should be gone');

    // PID 1 belongs to root; this user may not signal it.
    await expectLater(
      service.kill(1, KillSignal.term),
      throwsA(
        isA<KillFailedException>().having(
          (e) => e.message.toLowerCase(),
          'message',
          anyOf(contains('not permitted'), contains('permission')),
        ),
      ),
    );
  });

  test('detects the OS from /etc/os-release', () async {
    final info = await ServerInfoService(exec).detectOs();
    expect(info.family, isNot(OsFamily.unknown));
    expect(info.prettyName, isNotEmpty);
    // ignore: avoid_print
    print('live OS: ${info.family.name} — ${info.prettyName}');
  });
}
