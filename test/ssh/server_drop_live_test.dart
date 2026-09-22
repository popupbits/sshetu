@Tags(['live'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/host_key_verifier.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';
import 'package:sshetu/core/ssh/reconnect_loop.dart';
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/tunnel_runner.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';
import 'package:sshetu/core/terminal/remote_shell.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/server_info/data/server_exec.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';
import 'package:sshetu/features/tunnels/ports_monitor.dart';

/// A server-side drop must not leave a single uncaught error behind.
///
/// Everything that rides one connection is open at once — a tmux tab, an
/// SFTP session, an exec in flight, a local forward with a live connection
/// through it, the ports poll — and then the server side is killed. The app
/// reconnects on its own; what this watches is the other channel out of an
/// app, the one Settings → Diagnostics records: errors that reach the zone
/// because nothing was listening.
///
/// Configured like `tmux_live_test.dart`, from the environment, and skipped
/// without it:
///
///     SSHETU_LIVE_SSH   user@host:port of a server with tmux
///     SSHETU_LIVE_KEY   path to an unencrypted private key it accepts
///     SSHETU_LIVE_KILL  a command that kills the server side of every
///                       connection (a hard drop: the socket closes)
///
///     flutter test --tags live test/ssh/server_drop_live_test.dart
void main() {
  final env = Platform.environment;
  final address = env['SSHETU_LIVE_SSH'];
  final keyPath = env['SSHETU_LIVE_KEY'];
  final kill = env['SSHETU_LIVE_KILL'];
  final skip = address == null || keyPath == null || kill == null
      ? 'SSHETU_LIVE_SSH, SSHETU_LIVE_KEY and SSHETU_LIVE_KILL are not set'
      : null;

  late SshTarget target;
  late SecretVault vault;
  final knownHosts = InMemoryKnownHostsStore();

  setUpAll(() async {
    if (skip != null) return;
    final match = RegExp(r'^([^@]+)@([^:]+):(\d+)$').firstMatch(address!)!;
    target = SshTarget(
      hostname: match[2]!,
      port: int.parse(match[3]!),
      username: match[1]!,
      identityId: 'live-key',
      credentialId: 'live-host',
      keepaliveInterval: const Duration(seconds: 5),
    );
    vault = InMemorySecretVault();
    await vault.write(
      const SecretRef.identityPrivateKey('live-key'),
      await File(keyPath!).readAsString(),
    );
  });

  SshConnection connect() => SshConnection(
    target: target,
    verifierFactory: (hostname, port) => SshHostKeyVerifier(
      knownHosts: knownHosts,
      hostname: hostname,
      port: port,
      onUnknownHostKey: (_) => true,
    ),
    credentials: VaultCredentialSource(
      vault: vault,
      catalog: () async => const [],
    ),
  );

  test(
    'a server-side drop leaves no uncaught error, with every kind of '
    'channel open on the connection',
    () async {
      final uncaught = <String>[];
      final done = Completer<({int rows, int expected})>();

      runZonedGuarded(
        () async {
          try {
            done.complete(
              await _scenario(connect, kill!, (e, s) {
                uncaught.add('thrown into the framework: $e\n$s');
              }),
            );
          } catch (e, s) {
            if (!done.isCompleted) done.completeError(e, s);
          }
        },
        (error, stack) {
          uncaught.add('$error\n$stack');
        },
      );

      final resized = await done.future;
      // Anything the drop left pending fails within a moment of it; this is
      // the margin for one that fails late.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(uncaught, isEmpty, reason: uncaught.join('\n---\n'));
      // And the terminal itself took the size it was laid out at while the
      // link was down — a window-change the dead shell refused must not
      // leave its buffer at the old one.
      expect(resized.rows, resized.expected);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'an SFTP service that was in use before a drop works again after it',
    () async {
      final connection = connect();
      addTearDown(connection.close);
      final sftp = SshSftpService(connection);
      expect(await sftp.list('/'), isNotEmpty);

      final result = await Process.run(kill!, const [], runInShell: true);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      // The old session goes; the next call reconnects on a new one.
      await _waitFor(() => !connection.isConnected);

      // Before the fix this failed on every call from here on: the service
      // held an SFTP channel of the session that had just died.
      expect(await sftp.list('/'), isNotEmpty);
      await sftp.close();
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  /// Opens SFTP on a connection whose inbound side is cut the instant the
  /// `subsystem` request goes out — after the channel opened, before the
  /// server's reply — and returns what reached the zone uncaught.
  Future<List<Object>> sftpCutBeforeReply(
    Future<SftpClient> Function(SSHClient) open,
  ) async {
    final match = RegExp(r'^([^@]+)@([^:]+):(\d+)$').firstMatch(address!)!;
    final socket = _CuttableSocket(
      await SSHSocket.connect(match[2]!, int.parse(match[3]!)),
    );
    final client = SSHClient(
      socket,
      username: match[1]!,
      identities: SSHKeyPair.fromPem(await File(keyPath!).readAsString()),
      onVerifyHostKey: (_, _) => true,
    );
    final uncaught = <Object>[];
    try {
      await client.authenticated;
      final opened = Completer<Object?>();
      runZonedGuarded(() {
        // Write one is CHANNEL_OPEN, answered normally; write two is the
        // subsystem request.
        socket.cutInboundAfterWrites(2);
        open(client).then(opened.complete, onError: opened.complete);
      }, (error, _) => uncaught.add(error));
      final result = await opened.future.timeout(const Duration(seconds: 10));
      expect(result, isA<SftpClient>(), reason: 'sftp() does not wait for it');
      await client.done.then((_) {}, onError: (Object _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } finally {
      client.close();
    }
    return uncaught;
  }

  test(
    'dartssh2 leaves the SFTP subsystem reply unobserved — why the guard '
    'exists (fails once dartssh2 stops doing this)',
    () async {
      final uncaught = await sftpCutBeforeReply((client) => client.sftp());
      expect(uncaught, [
        isA<SSHStateError>().having(
          (e) => e.message,
          'message',
          'SSH connection closed',
        ),
      ]);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'SFTP opened through the guard leaves nothing uncaught when the link '
    'drops before the reply',
    () async {
      final uncaught = await sftpCutBeforeReply(
        (client) => guardOrphanedChannelReplies(client.sftp),
      );
      expect(uncaught, isEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

/// An [SSHSocket] whose inbound side can be cut at an exact point in the
/// conversation, counted in outbound packets — dartssh2 writes each packet
/// with one `add`. Cutting ends the stream the transport reads, which it
/// takes as the server hanging up.
class _CuttableSocket implements SSHSocket {
  _CuttableSocket(this._inner) {
    _subscription = _inner.stream.listen(
      _inbound.add,
      onError: _inbound.addError,
      onDone: _inbound.close,
    );
    sink = _CountingSink(_inner.sink, _wrote);
  }

  final SSHSocket _inner;
  final _inbound = StreamController<Uint8List>();
  late final StreamSubscription<Uint8List> _subscription;
  int? _cutAfter;

  void cutInboundAfterWrites(int writes) => _cutAfter = writes;

  void _wrote() {
    final left = _cutAfter;
    if (left == null) return;
    if (left > 1) {
      _cutAfter = left - 1;
      return;
    }
    _cutAfter = null;
    unawaited(_subscription.cancel());
    unawaited(_inbound.close());
  }

  @override
  Stream<Uint8List> get stream => _inbound.stream;

  // The socket's own sink, closed by whoever closes the socket — dartssh2.
  @override
  // ignore: close_sinks
  late final StreamSink<List<int>> sink;

  @override
  Future<void> get done => _inner.done;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } on Object {
      _inner.destroy();
    }
  }

  @override
  void destroy() => _inner.destroy();

  @override
  Future<void> flush() => _inner.flush();
}

class _CountingSink implements StreamSink<List<int>> {
  _CountingSink(this._inner, this._onAdd);

  final StreamSink<List<int>> _inner;
  final void Function() _onAdd;

  @override
  void add(List<int> data) {
    _inner.add(data);
    _onAdd();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  Future<void> close() => _inner.close();

  @override
  Future<void> get done => _inner.done;
}

/// [thrown] receives what a call made from a widget — a layout, a key
/// press — threw synchronously: the framework hands that to
/// `FlutterError.onError`, which Diagnostics records just the same.
///
/// Returns the terminal's height after the resize made while the link was
/// down, and the height it was resized to.
Future<({int rows, int expected})> _scenario(
  SshConnection Function() connect,
  String kill,
  void Function(Object error, StackTrace stack) thrown,
) async {
  void fromWidget(void Function() call) {
    try {
      call();
    } catch (e, s) {
      thrown(e, s);
    }
  }

  final connection = connect();
  final id = 'sszdrop${DateTime.now().millisecondsSinceEpoch}';
  final session = TerminalSession(
    id: id,
    title: 'live',
    hostId: 'live-host',
    connection: connection,
    keepOnServer: true,
  );
  final sftp = SshSftpService(connection);
  final exec = ConnectionExec(connection);
  final ports = PortsMonitor(exec, interval: const Duration(seconds: 1));
  final now = DateTime.now();
  final runner = TunnelRunner(
    tunnel: Tunnel(
      id: 'live-tunnel',
      hostId: 'live-host',
      label: 'live',
      kind: TunnelKind.local,
      listenPort: 0,
      createdAt: now,
      updatedAt: now,
      // The server's own sshd, as seen from the server: it answers at once
      // with a banner, which is what keeps this connection busy.
      targetHost: '127.0.0.1',
      targetPort: connection.target.port,
    ),
    connect: connection.client,
  );
  Socket? through;
  try {
    await session.start();
    expect(
      session.status,
      TerminalSessionStatus.running,
      reason: session.error,
    );
    expect(session.shellOrigin, ShellOrigin.tmuxCreated);

    // SFTP, server info's exec, the ports poll and a forward, all over the
    // tab's own connection.
    expect(await sftp.list('/tmp'), isNotEmpty);
    expect((await exec.run('echo hi')).stdout.trim(), 'hi');
    ports.start();
    await runner.start();
    expect(runner.status.isRunning, isTrue, reason: '${runner.status}');
    expect(await runner.probeTarget(), isNotNull);
    through = await Socket.connect('127.0.0.1', runner.status.boundPort!);
    final banner = Completer<void>();
    through.listen(
      (_) {
        if (!banner.isCompleted) banner.complete();
      },
      onError: (Object _) {},
      onDone: () {},
    );
    await banner.future.timeout(const Duration(seconds: 10));

    // In flight at the moment of the drop: an exec still running, and an
    // SFTP listing being read.
    final inFlight = exec
        .run('sleep 30')
        .then<Object?>((r) => r, onError: (Object e) => e);
    final listing = sftp
        .list('/usr/bin')
        .then<Object?>((r) => r, onError: (Object e) => e);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    // The hard drop.
    final result = await Process.run(kill, const [], runInShell: true);
    if (result.exitCode != 0) {
      throw StateError('"$kill" failed: ${result.stderr}');
    }

    await _waitFor(
      () =>
          session.reconnect.phase != ReconnectPhase.idle ||
          session.status != TerminalSessionStatus.running,
      describe: () => '${session.status} ${session.reconnect.phase}',
    );
    // What a pane does as the "reconnecting" bar appears and moves the
    // terminal: it is laid out again at a new size, with the old shell
    // still attached.
    final rows = session.terminal.viewHeight;
    fromWidget(
      () => session.terminal.resize(session.terminal.viewWidth, rows - 1),
    );
    final resized = (rows: session.terminal.viewHeight, expected: rows - 1);
    fromWidget(() => session.send('typed while down\r'));

    // The exec in flight failed and was told so; that is handled, not
    // uncaught.
    expect(await inFlight.timeout(const Duration(seconds: 15)), isA<Object>());
    // The listing either finished before the drop or failed with it.
    await listing.timeout(const Duration(seconds: 15));

    // An SFTP call after the drop reopens its channel on the new session
    // rather than failing on the dead one's — and whatever it does, it does
    // as a result, never as an uncaught error.
    expect(await sftp.list('/tmp'), isNotEmpty);

    await _waitFor(
      () =>
          session.status == TerminalSessionStatus.running &&
          session.reconnect.phase == ReconnectPhase.idle,
      timeout: const Duration(seconds: 30),
      describe: () =>
          '${session.status} ${session.reconnect.phase} ${session.error}',
    );
    expect(session.shellOrigin, ShellOrigin.tmuxReattached);
    fromWidget(() => session.terminal.resize(session.terminal.viewWidth, rows));
    // Let the ports poll run over the new connection.
    await Future<void>.delayed(const Duration(seconds: 2));
    return resized;
  } finally {
    through?.destroy();
    ports.dispose();
    await runner.dispose();
    await sftp.close();
    session.end();
    // The tmux kill runs over the still-open connection, fire-and-forget.
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

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
