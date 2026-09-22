import 'dart:async';

import 'package:sshetu/features/server_info/data/server_exec.dart';

typedef ExecHandler = FutureOr<ExecResult> Function(
  String command,
  String? stdin,
);

/// A [ServerExec] answered by a function, recording every call.
class FakeServerExec implements ServerExec {
  FakeServerExec(this.handler, {this.connected = true});

  ExecHandler handler;
  bool connected;
  final List<({String command, String? stdin})> calls = [];

  @override
  bool get isConnected => connected;

  @override
  Future<ExecResult> run(String command, {String? stdin}) async {
    if (!connected) throw const ServerOfflineException();
    calls.add((command: command, stdin: stdin));
    return handler(command, stdin);
  }
}
