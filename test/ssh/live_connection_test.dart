@Tags(['live'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/secrets/secret_ref.dart';
import 'package:ssh_navigator/core/secrets/secret_vault.dart';
import 'package:ssh_navigator/core/ssh/host_key.dart';
import 'package:ssh_navigator/core/ssh/host_key_verifier.dart';
import 'package:ssh_navigator/core/ssh/known_hosts_store.dart';
import 'package:ssh_navigator/core/ssh/sftp_service.dart';
import 'package:ssh_navigator/core/ssh/ssh_connection.dart';
import 'package:ssh_navigator/core/ssh/ssh_credentials.dart';
import 'package:ssh_navigator/core/ssh/ssh_target.dart';
import 'package:ssh_navigator/core/ssh/vault_credential_source.dart';
import 'package:ssh_navigator/core/terminal/terminal_session.dart';

/// End-to-end against a **real OpenSSH server**, started by this test.
///
/// Everything else in the suite stops at the edge of the network. This is the
/// part nobody can assert from a unit test: that the transport negotiates,
/// authenticates with a key out of the vault, opens a PTY, and that bytes
/// coming back actually reach the terminal's buffer.
///
/// It is tagged `live` and skipped where `sshd` is unavailable, so an ordinary
/// `flutter test` run does not depend on it. Run it deliberately:
///
///     flutter test --tags live
///
/// The server is this user's own `sshd` on a loopback port, with a throwaway
/// host key and a throwaway client key in a temp directory. It touches nothing
/// in `~/.ssh` and needs no privileges.
void main() {
  const sshdPath = '/usr/sbin/sshd';
  final available = File(sshdPath).existsSync() && !Platform.isWindows;
  // Skipped rather than failed where there is no sshd to talk to: a machine
  // without one has nothing to say about whether this app connects.
  final skipReason = available ? null : 'no $sshdPath on this machine';

  late Directory dir;
  late Process sshd;
  late int port;
  late String privateKey;

  setUpAll(() async {
    if (!available) return;
    // Deliberately NO TestWidgetsFlutterBinding here. It installs a fake
    // clock, and a test that drives a real socket needs a real one — with the
    // binding in place the shell appeared to exit instantly. The coalescer
    // copes with having no binding.
    dir = await Directory.systemTemp.createTemp('ssh_navigator_live');

    Future<void> keygen(String name) async {
      final result = await Process.run('ssh-keygen', [
        '-q',
        '-t',
        'ed25519',
        '-f',
        '${dir.path}/$name',
        '-N',
        '',
      ]);
      if (result.exitCode != 0) {
        throw StateError('ssh-keygen: ${result.stderr}');
      }
    }

    await keygen('host_key');
    await keygen('client_key');
    // A valid key the server does not authorise, to prove several are tried.
    await keygen('decoy');

    privateKey = await File('${dir.path}/client_key').readAsString();
    await File('${dir.path}/authorized_keys')
        .writeAsString(await File('${dir.path}/client_key.pub').readAsString());

    // A port the OS picks, so parallel runs cannot collide.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = probe.port;
    await probe.close();

    await File('${dir.path}/sshd_config').writeAsString('''
Port $port
ListenAddress 127.0.0.1
HostKey ${dir.path}/host_key
AuthorizedKeysFile ${dir.path}/authorized_keys
PidFile ${dir.path}/sshd.pid
UsePAM no
PasswordAuthentication no
PubkeyAuthentication yes
StrictModes no
# Without this there is no SFTP subsystem for the client to talk to, and an
# `openSession`/subsystem request simply never gets an answer — the SFTP
# tests hang rather than fail, which is a long way to travel to learn that a
# config file was incomplete. `-f` replaces the system config entirely, so
# nothing is inherited.
Subsystem sftp /usr/libexec/sftp-server
''');

    sshd = await Process.start(sshdPath, [
      '-f',
      '${dir.path}/sshd_config',
      '-D',
      '-e',
    ]);
    // Give it a moment to bind before the first connect.
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  tearDownAll(() async {
    if (!available) return;
    sshd.kill();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  SshConnection buildConnection({
    required KnownHostsStore knownHosts,
    required SecretVault vault,
    bool trustUnknown = true,
    String? identityId = 'test-identity',
    IdentityCatalog? catalog,
  }) => SshConnection(
    target: SshTarget(
      hostname: '127.0.0.1',
      port: port,
      username: Platform.environment['USER'] ?? 'runner',
      identityId: identityId,
      credentialId: 'test-host',
    ),
    verifierFactory: (hostname, hostPort) => SshHostKeyVerifier(
      knownHosts: knownHosts,
      hostname: hostname,
      port: hostPort,
      onUnknownHostKey: (_) => trustUnknown,
    ),
    credentials: VaultCredentialSource(
      vault: vault,
      catalog: catalog ?? () async => const [],
    ),
  );

  Future<SecretVault> vaultWithKey() async {
    final vault = InMemorySecretVault();
    await vault.write(
      const SecretRef.identityPrivateKey('test-identity'),
      privateKey,
    );
    return vault;
  }

  test('connects, authenticates with a key from the vault, and runs a shell', () async {
    final knownHosts = InMemoryKnownHostsStore();
    final connection = buildConnection(
      knownHosts: knownHosts,
      vault: await vaultWithKey(),
    );
    addTearDown(connection.close);

    final session = TerminalSession(
      id: 's1',
      title: 'live',
      hostId: 'live-host',
      connection: connection,
    );
    addTearDown(session.dispose);

    await session.start();

    expect(
      session.status,
      TerminalSessionStatus.running,
      reason: session.error ?? 'no error reported',
    );

    // The full round trip: a command typed in, its output parsed by xterm2 and
    // landing in the buffer the UI draws from.
    session.send('echo NAVIGATOR_OK\n');
    await _waitFor(
      () => session.terminal.buffer.getText().contains('NAVIGATOR_OK'),
      describe: () =>
          'terminal held: '
          '${session.terminal.buffer.getText().trim().replaceAll('\n', ' | ')}',
    );

    expect(session.terminal.buffer.getText(), contains('NAVIGATOR_OK'));
  }, skip: skipReason);

  test('trust on first use records the host key', () async {
    final knownHosts = InMemoryKnownHostsStore();
    final connection = buildConnection(
      knownHosts: knownHosts,
      vault: await vaultWithKey(),
    );
    addTearDown(connection.close);

    await connection.client();

    final stored = knownHosts.find('127.0.0.1', port);
    expect(stored, isNotNull);
    expect(stored!.fingerprint, startsWith('SHA256:'));
    expect(stored.keyType, 'ssh-ed25519');
  }, skip: skipReason);

  test('refusing an unknown host key refuses the connection', () async {
    final connection = buildConnection(
      knownHosts: InMemoryKnownHostsStore(),
      vault: await vaultWithKey(),
      trustUnknown: false,
    );
    addTearDown(connection.close);

    await expectLater(
      connection.client(),
      throwsA(isA<SshConnectionException>()),
    );
  }, skip: skipReason);

  test(
    'a changed host key is refused even though it was once trusted',
    () async {
      // The guarantee the whole verifier exists for, proven against a real
      // handshake rather than a stub.
      final knownHosts = InMemoryKnownHostsStore();
      final first = buildConnection(
        knownHosts: knownHosts,
        vault: await vaultWithKey(),
      );
      await first.client();
      await first.close();

      // Same address, different key: exactly what a substituted server looks
      // like. The stored entry is rewritten rather than the server changed,
      // which is indistinguishable from the client's point of view.
      final trusted = knownHosts.find('127.0.0.1', port)!;
      await knownHosts.trust(
        KnownHostKey(
          hostname: trusted.hostname,
          port: trusted.port,
          keyType: trusted.keyType,
          fingerprint: 'SHA256:definitelyNotTheRealFingerprintAAAAAAAAAAA',
          trustedAt: trusted.trustedAt,
        ),
      );

      final second = buildConnection(
        knownHosts: knownHosts,
        // Would say yes if it were ever asked. It must not be asked.
        trustUnknown: true,
        vault: await vaultWithKey(),
      );
      addTearDown(second.close);

      await expectLater(
        second.client(),
        throwsA(isA<SshConnectionException>()),
      );
    },
    skip: skipReason,
  );

  test(
    'a host naming no key authenticates with one of the user\'s keys',
    () async {
      // The gap that made nine of ten imported hosts prompt for a password:
      // `~/.ssh/config` entries rarely carry an IdentityFile, and `ssh` handles
      // that by offering the default keys. Proven against a real handshake:
      // the target names no identity, and the server still lets it in.
      final vault = InMemorySecretVault();
      await vault.write(
        const SecretRef.identityPrivateKey('id_ed25519'),
        privateKey,
      );

      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: vault,
        identityId: null,
        catalog: () async => const [
          AvailableIdentity(
            id: 'id_ed25519',
            label: 'id_ed25519',
            keyType: 'ssh-ed25519',
            hasPassphrase: false,
          ),
        ],
      );
      addTearDown(connection.close);

      final client = await connection.client();
      expect(client.isClosed, isFalse);
    },
    skip: skipReason,
  );

  test('the right key is found among several offered', () async {
    // The server accepts exactly one of these. A client that offered only its
    // first guess would fail; SSH offers them in turn, and so must this.
    final vault = InMemorySecretVault();
    await vault.write(
      const SecretRef.identityPrivateKey('wrong'),
      await File('${dir.path}/decoy').readAsString(),
    );
    await vault.write(const SecretRef.identityPrivateKey('right'), privateKey);

    final connection = buildConnection(
      knownHosts: InMemoryKnownHostsStore(),
      vault: vault,
      identityId: null,
      catalog: () async => const [
        AvailableIdentity(
          id: 'wrong',
          label: 'decoy',
          keyType: 'ssh-ed25519',
          hasPassphrase: false,
        ),
        AvailableIdentity(
          id: 'right',
          label: 'real',
          keyType: 'ssh-ed25519',
          hasPassphrase: false,
        ),
      ],
    );
    addTearDown(connection.close);

    final client = await connection.client();
    expect(client.isClosed, isFalse);
  }, skip: skipReason);

  test(
    'an undecodable key does not sink a connection that has others',
    () async {
      // One corrupt key among several must not stop the others being tried.
      final vault = InMemorySecretVault();
      await vault.write(
        const SecretRef.identityPrivateKey('broken'),
        '-----BEGIN OPENSSH PRIVATE KEY-----\nnot base64\n'
        '-----END OPENSSH PRIVATE KEY-----\n',
      );
      await vault.write(const SecretRef.identityPrivateKey('good'), privateKey);

      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: vault,
        identityId: null,
        catalog: () async => const [
          AvailableIdentity(
            id: 'broken',
            label: 'broken',
            keyType: 'ssh-ed25519',
            hasPassphrase: false,
          ),
          AvailableIdentity(
            id: 'good',
            label: 'good',
            keyType: 'ssh-ed25519',
            hasPassphrase: false,
          ),
        ],
      );
      addTearDown(connection.close);

      final client = await connection.client();
      expect(client.isClosed, isFalse);
    },
    skip: skipReason,
  );

  group('SFTP over the same connection', () {
    // The agent that built the file browser could not reach a server, so this
    // is the first time any of it has touched real SFTP. It runs on the shell
    // connection deliberately: reusing the channel is the whole design, and a
    // test that dialled separately would prove the wrong thing.
    late Directory work;

    setUp(() async {
      if (!available) return;
      work = await Directory.systemTemp.createTemp('ssh_navigator_sftp');
    });

    tearDown(() {
      if (available && work.existsSync()) work.deleteSync(recursive: true);
    });

    Future<SshSftpService> openSftp(SshConnection connection) async {
      // Force the connection up first, so a failure here is an SFTP failure
      // rather than a connection one.
      await connection.client();
      return SshSftpService(connection);
    }

    test('lists a real directory, directories first', () async {
      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: await vaultWithKey(),
      );
      addTearDown(connection.close);

      await Directory('${work.path}/zeta_dir').create();
      await File('${work.path}/alpha.txt').writeAsString('a');
      await File('${work.path}/beta.txt').writeAsString('b');

      final sftp = await openSftp(connection);
      addTearDown(sftp.close);

      final entries = await sftp.list(work.path);
      final names = entries.map((e) => e.name).toList();

      expect(names, ['zeta_dir', 'alpha.txt', 'beta.txt']);
      expect(entries.first.isDirectory, isTrue);
      expect(entries[1].size, 1);
    });

    test('downloads a file byte-for-byte, reporting progress', () async {
      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: await vaultWithKey(),
      );
      addTearDown(connection.close);

      // Big enough to arrive in several chunks, so progress is really
      // progress and not one callback at the end.
      final content = List.generate(200000, (i) => i % 251).join(',');
      await File('${work.path}/source.txt').writeAsString(content);

      final sftp = await openSftp(connection);
      addTearDown(sftp.close);

      final seen = <int>[];
      await sftp.download(
        remotePath: '${work.path}/source.txt',
        localPath: '${work.path}/copy.txt',
        onProgress: (done, total) => seen.add(done),
      );

      expect(await File('${work.path}/copy.txt').readAsString(), content);
      expect(seen, isNotEmpty, reason: 'progress was never reported');
      expect(seen.last, content.length);
    });

    test('uploads a file byte-for-byte', () async {
      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: await vaultWithKey(),
      );
      addTearDown(connection.close);

      const content = 'upload me, exactly as I am\nsecond line\n';
      await File('${work.path}/local.txt').writeAsString(content);

      final sftp = await openSftp(connection);
      addTearDown(sftp.close);

      await sftp.upload(
        localPath: '${work.path}/local.txt',
        remotePath: '${work.path}/remote.txt',
      );

      expect(await File('${work.path}/remote.txt').readAsString(), content);
    });

    test('renames and deletes', () async {
      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: await vaultWithKey(),
      );
      addTearDown(connection.close);

      await File('${work.path}/before.txt').writeAsString('x');

      final sftp = await openSftp(connection);
      addTearDown(sftp.close);

      await sftp.rename('${work.path}/before.txt', '${work.path}/after.txt');
      expect(File('${work.path}/after.txt').existsSync(), isTrue);

      final entry = (await sftp.list(work.path)).single;
      await sftp.delete(entry);
      expect(await sftp.list(work.path), isEmpty);
    });

    test('a missing file fails with a message safe to show', () async {
      // The contract that keeps raw wire errors and file handles off screen.
      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: await vaultWithKey(),
      );
      addTearDown(connection.close);

      final sftp = await openSftp(connection);
      addTearDown(sftp.close);

      await expectLater(
        sftp.list('${work.path}/does-not-exist'),
        throwsA(isA<SftpException>()),
      );
    });

    test('closing SFTP leaves the shell connection alive', () async {
      // The reuse guarantee: the file browser closing must not take the
      // terminal down with it.
      final connection = buildConnection(
        knownHosts: InMemoryKnownHostsStore(),
        vault: await vaultWithKey(),
      );
      addTearDown(connection.close);

      final sftp = await openSftp(connection);
      await sftp.list(work.path);
      await sftp.close();

      final client = await connection.client();
      expect(client.isClosed, isFalse);
    });
  }, skip: skipReason);

  test('a missing key fails with a message naming the problem', () async {
    final connection = buildConnection(
      knownHosts: InMemoryKnownHostsStore(),
      vault: InMemorySecretVault(), // nothing stored
    );
    addTearDown(connection.close);

    await expectLater(
      connection.client(),
      throwsA(
        isA<SshConnectionException>().having(
          (e) => e.message,
          'message',
          contains('not available'),
        ),
      ),
    );
  }, skip: skipReason);
}

/// Polls [condition] until it holds, or gives up.
///
/// Output arrives over a socket and is then batched by the coalescer, so there
/// is no single future to await — the terminal fills in over a few frames.
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String Function()? describe,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException(
    'condition not met within $timeout'
    '${describe == null ? '' : '; ${describe()}'}',
  );
}
