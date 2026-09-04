import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ssh/host_key_verifier.dart';
import '../../core/ssh/key_material_cache.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../core/ssh/vault_credential_source.dart';
import '../../core/terminal/terminal_session.dart';
import '../hosts/domain/ssh_host.dart';

/// The open terminal tabs.
///
/// Sessions live here rather than in a screen's state so a tab survives being
/// navigated away from: switching to Hosts to start a second connection must
/// not kill the first, and on a phone that is the normal way to use the app.
class SessionManager extends Notifier<List<TerminalSession>> {
  /// The live sessions. The source of truth; [state] mirrors it.
  ///
  /// Held as a field rather than read back out of [state] because Riverpod 3
  /// forbids touching a provider from inside its own life-cycle callbacks —
  /// and the one place that matters is exactly the one that matters most:
  /// tearing every session down when the container goes away. Reading `state`
  /// there threw, which meant the app could exit leaving SSH connections open.
  final List<TerminalSession> _sessions = [];

  @override
  List<TerminalSession> build() {
    ref.onDispose(() {
      for (final session in _sessions) {
        session.dispose();
      }
      _sessions.clear();
    });
    return const [];
  }

  var _counter = 0;

  /// Publishes [_sessions] as immutable state.
  void _publish() => state = List.unmodifiable(_sessions);

  String? _activeId;

  /// The session the workspace is showing.
  ///
  /// Held here rather than in a screen so that switching destinations, or
  /// moving between the phone's full-screen terminal and the desktop
  /// workspace, does not lose which tab you were in.
  String? get activeId {
    // A tab that has been closed must not stay "active" — the getter resolves
    // against live state rather than trusting a stored id.
    if (_activeId != null && _sessions.any((s) => s.id == _activeId)) {
      return _activeId;
    }
    return _sessions.isEmpty ? null : _sessions.last.id;
  }

  /// The session the workspace is showing, if any.
  TerminalSession? get active {
    final id = activeId;
    return id == null ? null : byId(id);
  }

  void select(String id) {
    if (_activeId == id) return;
    _activeId = id;
    // The list itself has not changed, but which of them is showing has, and
    // that is what the strip and the pane are watching.
    _publish();
  }

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
    final connection = await _buildConnection(
      host,
      onUnknownHostKey: onUnknownHostKey,
      prompt: prompt,
    );

    final session = TerminalSession(
      // Must be safe in a URL path: the session id goes into
      // `/terminal/<id>`, and a '#' would be read as a fragment delimiter —
      // go_router would then match `/terminal/<hostId>` and look up an id that
      // does not exist, so the screen would open on "no open sessions" and
      // tapping a host would appear to do nothing at all.
      id: '${host.id}-${_counter++}',
      title: host.label,
      hostId: host.id,
      connection: connection,
      startupCommand: host.startupCommand,
    );

    _activeId = session.id;
    _sessions.add(session);
    _publish();
    await ref
        .read(hostRepositoryProvider)
        .touch(host.id, now: DateTime.now().toUtc());
    // Started after the tab exists, so the UI can show "connecting" and the
    // host key prompt has a screen to appear over.
    await session.start();
    return session;
  }

  /// An open tab's connection to [hostId], if one is live.
  ///
  /// Port forwarding calls this before dialing its own: a tunnel to a host
  /// already open in a terminal should ride that transport rather than pay
  /// for a second handshake to the same server.
  SshConnection? connectionForHost(String hostId) {
    for (final session in _sessions) {
      if (session.hostId == hostId && session.connection.isConnected) {
        return session.connection;
      }
    }
    return null;
  }

  /// Opens a connection to [host] outside of any terminal tab.
  ///
  /// For port forwarding, which needs the transport but never a shell and
  /// must not appear as an open session. The caller owns what comes back —
  /// closing it is their job, because this manager only tracks connections
  /// that back a tab and would otherwise leak this one forever.
  Future<SshConnection> openBareConnection(
    SshHost host, {
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
  }) async {
    final connection = await _buildConnection(
      host,
      onUnknownHostKey: onUnknownHostKey,
      prompt: prompt,
    );
    // Establishes the session now rather than lazily on first use, so a bad
    // host key or a rejected credential surfaces to the caller immediately
    // instead of on whichever tunnel happens to accept the first connection.
    await connection.client();
    await ref
        .read(hostRepositoryProvider)
        .touch(host.id, now: DateTime.now().toUtc());
    return connection;
  }

  Future<SshConnection> _buildConnection(
    SshHost host, {
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
  }) async {
    final knownHosts = await ref.read(knownHostsProvider.future);
    final hosts = ref.read(hostRepositoryProvider);
    final target = await hosts.targetFor(host);

    return SshConnection(
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
        // Shared, so opening a second session does not re-read every key —
        // and on macOS, does not raise the same authorisation prompts again.
        keyCache: ref.read(keyMaterialCacheProvider),
        // Read lazily, at connect time: a key imported since the app started
        // should be offered without a restart.
        catalog: () async => [
          for (final identity
              in await ref.read(identityRepositoryProvider).all())
            AvailableIdentity(
              id: identity.id,
              label: identity.label,
              keyType: identity.keyType,
              hasPassphrase: identity.hasPassphrase,
            ),
        ],
        prompt: prompt,
      ),
    );
  }

  /// Closes one tab and, with it, the SSH session behind it.
  ///
  /// Deliberately: a tab *is* the session. Leaving the connection alive after
  /// its only window is gone would be a process leak with good intentions —
  /// nothing would show it and nothing could end it. Navigating away from a
  /// terminal does not come through here, so backing out of a session keeps it
  /// running, which is the difference the user actually cares about.
  /// Moves [delta] tabs from the active one, wrapping.
  ///
  /// Lives here rather than in the shortcut handler because the menu bar
  /// needs the same behaviour, and two copies of "wrap past the last tab" is
  /// two chances to disagree about what Cmd-] does.
  void cycle(int delta) {
    if (_sessions.length < 2) return;
    final current = _sessions.indexWhere((session) => session.id == activeId);
    if (current < 0) return;
    // Wraps, the way every tabbed application does: past the last tab is the
    // first one, not a dead end.
    final next = (current + delta + _sessions.length) % _sessions.length;
    select(_sessions[next].id);
  }

  void close(String id) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index < 0) return;

    _sessions.removeAt(index).dispose();

    // Focus the neighbour, the way every tabbed interface does: closing the
    // tab you are looking at should leave you next to where you were, not on
    // whichever tab happens to be last.
    if (_activeId == id) {
      _activeId = _sessions.isEmpty
          ? null
          : _sessions[(index - 1).clamp(0, _sessions.length - 1)].id;
    }

    _publish();
  }

  TerminalSession? byId(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }
}

final sessionManagerProvider =
    NotifierProvider<SessionManager, List<TerminalSession>>(SessionManager.new);
