import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/ssh/ssh_connection.dart';

/// What one exec produced.
class ExecResult {
  const ExecResult({required this.stdout, this.stderr = '', this.exitCode});

  final String stdout;
  final String stderr;
  final int? exitCode;

  bool get succeeded => exitCode == 0;
}

/// Raised instead of dialling when the connection behind a panel is down.
class ServerOfflineException implements Exception {
  const ServerOfflineException();

  @override
  String toString() => 'ServerOfflineException: not connected';
}

/// Running short, non-interactive commands on a host.
///
/// The seam the monitor and the process list are tested through.
abstract interface class ServerExec {
  /// Whether a command could run right now without a new handshake.
  bool get isConnected;

  /// Runs [command] over an exec channel, writing [stdin] to it first.
  Future<ExecResult> run(String command, {String? stdin});
}

/// [ServerExec] over a session's **existing** connection.
///
/// Never dials. A poll every three seconds that reconnected whenever the link
/// was down would be a handshake — and possibly a password or host-key prompt
/// — every three seconds; the tab's own reconnect is what brings a dropped
/// link back, and this waits for it.
class ConnectionExec implements ServerExec {
  const ConnectionExec(
    this.connection, {
    this.timeout = const Duration(seconds: 10),
  });

  final SshConnection connection;
  final Duration timeout;

  @override
  bool get isConnected => connection.isConnected;

  @override
  Future<ExecResult> run(String command, {String? stdin}) async {
    if (!connection.isConnected) throw const ServerOfflineException();
    final client = await connection.client();
    final session = await client.execute(command).timeout(timeout);
    try {
      if (stdin != null && stdin.isNotEmpty) {
        session.write(Uint8List.fromList(utf8.encode(stdin)));
      }
      await session.stdin.close();
      final out = BytesBuilder(copy: false);
      final err = BytesBuilder(copy: false);
      await Future.wait([
        session.stdout.listen(out.add).asFuture<void>(),
        session.stderr.listen(err.add).asFuture<void>(),
      ]).timeout(timeout);
      await session.done.timeout(timeout);
      return ExecResult(
        stdout: utf8.decode(out.takeBytes(), allowMalformed: true),
        stderr: utf8.decode(err.takeBytes(), allowMalformed: true),
        exitCode: session.exitCode,
      );
    } on TimeoutException {
      session.close();
      rethrow;
    }
  }
}
