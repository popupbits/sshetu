import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ssh/host_key_verifier.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/vault_credential_source.dart';
import '../../core/terminal/terminal_session.dart';
import '../hosts/domain/ssh_host.dart';

/// The open terminal tabs.
///
/// Sessions live here rather than in a screen's state so a tab survives being
/// navigated away from: switching to Hosts to start a second connection must
/// not kill the first, and on a phone that is the normal way to use the app.
class SessionManager extends Notifier<List<TerminalSession>> {
  @override
  List<TerminalSession> build() {
    ref.onDispose(() {
      for (final session in state) {
        session.dispose();
      }
    });
    return const [];
  }

  var _counter = 0;

  /// Opens a session to [host] and returns it.
  ///
  /// [onUnknownHostKey] and [prompt] come from the screen, because both end in
  /// a dialog and this layer has no `BuildContext`. That is also why they are
  /// required rather than optional: a connection wired up without them would
  /// silently refuse every unknown host and every password, and look like a
  /// broken network.
  Future<TerminalSession> connect(
    SshHost host, {
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
  }) async {
    final knownHosts = await ref.read(knownHostsProvider.future);
    final hosts = ref.read(hostRepositoryProvider);
    final target = await hosts.targetFor(host);

    final connection = SshConnection(
      target: target,
      // Per hop, not per connection: a chain presents a host key at every
      // stage, and only checking the last one would let a compromised bastion
      // pass unnoticed.
      verifierFactory: (hostname, port) => SshHostKeyVerifier(
        knownHosts: knownHosts,
        hostname: hostname,
        port: port,
        onUnknownHostKey: onUnknownHostKey,
      ),
      credentials: VaultCredentialSource(
        vault: ref.read(secretVaultProvider),
        prompt: prompt,
      ),
    );

    final session = TerminalSession(
      // Must be safe in a URL path: the session id goes into
      // `/terminal/<id>`, and a '#' would be read as a fragment delimiter —
      // go_router would then match `/terminal/<hostId>` and look up an id that
      // does not exist, so the screen would open on "no open sessions" and
      // tapping a host would appear to do nothing at all.
      id: '${host.id}-${_counter++}',
      title: host.label,
      connection: connection,
      startupCommand: host.startupCommand,
    );

    state = [...state, session];
    await hosts.touch(host.id, now: DateTime.now().toUtc());
    // Started after the tab exists, so the UI can show "connecting" and the
    // host key prompt has a screen to appear over.
    await session.start();
    return session;
  }

  /// Closes one tab and releases its connection.
  void close(String id) {
    final remaining = <TerminalSession>[];
    for (final session in state) {
      if (session.id == id) {
        session.dispose();
      } else {
        remaining.add(session);
      }
    }
    state = remaining;
  }

  TerminalSession? byId(String id) {
    for (final session in state) {
      if (session.id == id) return session;
    }
    return null;
  }
}

final sessionManagerProvider =
    NotifierProvider<SessionManager, List<TerminalSession>>(SessionManager.new);
