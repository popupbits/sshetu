import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/secrets/app_lock.dart' show appLocalizationsFor;
import '../../core/settings/settings_controller.dart';
import '../../core/ssh/host_key_verifier.dart';
import '../../core/ssh/key_material_cache.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../core/ssh/vault_credential_source.dart';
import '../../core/settings/device_identity.dart';
import '../../core/terminal/terminal_session.dart';
import '../../core/terminal/tmux_names.dart';
import '../hosts/domain/ssh_host.dart';
import 'pane_layouts.dart';
import 'pane_tree.dart';
import '../server_info/data/server_exec.dart';
import '../server_info/host_os_controller.dart';
import 'reconnect_triggers.dart';
import 'workspace_restore.dart';

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
      unawaited(_triggers?.cancel());
      _triggers = null;
      // Disposed, not ended: the app going away is not the user closing
      // their tabs, so a session kept in tmux stays there to be reattached.
      for (final session in _sessions) {
        session.dispose();
      }
      _sessions.clear();
    });
    // A resized divider or a new split changes what a relaunch should
    // rebuild, though no tab opened or closed.
    ref.listen(paneLayoutsProvider, (_, _) => _saveWorkspace());
    return const [];
  }

  /// The lifecycle and network events, listened to only while there is at
  /// least one tab — see [ReconnectTriggers].
  StreamSubscription<ReconnectTrigger>? _triggers;

  void _watchTriggers() {
    if (_sessions.isEmpty) {
      unawaited(_triggers?.cancel());
      _triggers = null;
      return;
    }
    _triggers ??= ref
        .read(reconnectTriggersProvider)
        .events
        .listen((_) => nudgeAll());
  }

  /// Asks every tab to check its link: a tab waiting to reconnect tries now,
  /// and a tab that believes it is connected proves it. Called when the app
  /// returns to the foreground or the network comes back.
  void nudgeAll() {
    for (final session in List.of(_sessions)) {
      unawaited(session.nudge());
    }
  }

  /// Puts an already-built session in the list, as [connect] does. For tests
  /// that need a tab without a server behind it.
  @visibleForTesting
  void adopt(TerminalSession session, {PaneSplitRequest? split}) {
    _insert(session, split);
    if (split != null) _activeId = session.id;
    _watchTriggers();
    _publish();
  }

  PaneLayouts get _layouts => ref.read(paneLayoutsProvider.notifier);

  /// Adds [session] to the list — as a pane of [split]'s tab when asked, kept
  /// next to that tab's other sessions so a tab's panes are always adjacent
  /// in the list and the tab never jumps when its first pane closes.
  void _insert(TerminalSession session, PaneSplitRequest? split) {
    session.onInput = (data) => _routeInput(session, data);
    final target = split == null ? null : byId(split.target);
    if (split == null || target == null) {
      _sessions.add(session);
      return;
    }
    final members = _layouts.treeFor(target.id)?.panes ?? [target.id];
    final last = _sessions.lastIndexWhere((s) => members.contains(s.id));
    _sessions.insert(last + 1, session);
    _layouts.split(target.id, session.id, split.axis);
  }

  // ------------------------------------------------------- panes, broadcast

  /// The workspace's tabs: single sessions and split layouts, in order.
  List<PaneTab> get tabs => groupIntoTabs([
    for (final session in _sessions) session.id,
  ], ref.read(paneLayoutsProvider));

  /// Set while one paste is being delivered to several panes, so each
  /// pane's own paste is not broadcast a second time.
  var _fanningOut = false;

  List<TerminalSession> _broadcastTargetsOf(TerminalSession source) => [
    for (final id in broadcastTargets(
      _layouts.treeFor(source.id),
      source.id,
      isLive: (id) => byId(id)?.isLive ?? false,
    ))
      ?byId(id),
  ];

  /// Sends a keystroke typed into [source] on to the rest of its tab, when
  /// broadcast is on. Raw bytes, as typed — the same as tmux's synchronised
  /// panes.
  void _routeInput(TerminalSession source, String data) {
    if (_fanningOut) return;
    for (final target in _broadcastTargetsOf(source)) {
      target.send(data);
    }
  }

  /// Delivers text the paste flow has already sanitised and confirmed: to
  /// [source], and with broadcast on to every pane receiving it. Each pane
  /// gets its own `paste`, so each is bracketed or not by what its own
  /// program asked for.
  void pasteToTab(TerminalSession source, String text) {
    final targets = _broadcastTargetsOf(source);
    _fanningOut = true;
    try {
      source.terminal.paste(text);
      for (final target in targets) {
        target.terminal.paste(text);
      }
    } finally {
      _fanningOut = false;
    }
  }

  /// How many other panes are receiving what is typed into [id] right now.
  int broadcastCount(String id) {
    final source = byId(id);
    return source == null ? 0 : _broadcastTargetsOf(source).length;
  }

  /// Moves focus [delta] panes within the active tab.
  void cyclePane(int delta) {
    final id = activeId;
    if (id == null) return;
    final next = _layouts.cycle(id, delta);
    if (next != null) select(next);
  }

  /// Closes every pane of the tab [id] is in.
  void closeTab(String id) {
    final members = _layouts.treeFor(id)?.panes ?? [id];
    for (final member in members) {
      close(member);
    }
  }

  /// Selects the tab at [position], 1-based. Out of range does nothing.
  void selectTabAt(int position) {
    final all = tabs;
    if (position < 1 || position > all.length) return;
    select(all[position - 1].focused);
  }

  var _counter = 0;

  /// Publishes [_sessions] as immutable state, and remembers them for the
  /// next launch.
  void _publish() {
    state = List.unmodifiable(_sessions);
    _saveWorkspace();
  }

  /// Set while last launch's tabs are being reopened, so the half-reopened
  /// list is not saved over the whole one — a crash mid-restore would
  /// otherwise lose the tabs not yet reached.
  bool _restoring = false;

  /// The terminal tabs as they should come back next launch.
  SavedWorkspace get workspace {
    final active = activeId;
    final index = _sessions.indexWhere((s) => s.id == active);
    return SavedWorkspace(
      tabs: [
        for (final session in _sessions)
          SavedTab(
            hostId: session.hostId,
            tmuxName: session.keepOnServer ? session.tmuxName : null,
            ownsTmux: session.ownsTmuxSession,
          ),
      ],
      selected: index < 0 ? null : index,
      // Panes named by their tab's position, which is what the saved tabs
      // are keyed by.
      layouts: [
        for (final tree in ref.read(paneLayoutsProvider))
          ?tree.relabel((id) {
            final at = _sessions.indexWhere((s) => s.id == id);
            return at < 0 ? null : '$at';
          }),
      ],
    );
  }

  void _saveWorkspace() {
    if (_restoring) return;
    unawaited(ref.read(workspaceStoreProvider).write(workspace));
  }

  /// Brackets reopening last launch's tabs; see [_restoring].
  void beginRestore() => _restoring = true;

  void endRestore() {
    _restoring = false;
    _saveWorkspace();
  }

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
    // The tab remembers which of its panes was last in use.
    _layouts.focus(id);
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
  ///
  /// [tmuxName] picks up a session kept on the server — one this device left
  /// last launch, or one chosen from the server's list — instead of a new
  /// one; [resuming] makes the tab say so if that session has gone.
  /// [ownsTmuxSession] false borrows it: closing the tab leaves it running.
  /// [connection], when given, is an already-open connection to [host] the
  /// tab takes over, so no second handshake (or password prompt) is needed.
  /// [split] opens it as a pane of an existing tab rather than a new tab.
  Future<TerminalSession> connect(
    SshHost host, {
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
    required KeyboardInteractivePrompter interactivePrompt,
    String? tmuxName,
    bool resuming = false,
    bool ownsTmuxSession = true,
    SshConnection? connection,
    bool activate = true,
    PaneSplitRequest? split,
  }) async {
    final transport =
        connection ??
        await _buildConnection(
          host,
          onUnknownHostKey: onUnknownHostKey,
          prompt: prompt,
          interactivePrompt: interactivePrompt,
        );

    final settings = ref.read(settingsControllerProvider);
    final l10n = appLocalizationsFor(settings.localeCode);
    final session = TerminalSession(
      // Must be safe in a URL path: the session id goes into
      // `/terminal/<id>`, and a '#' would be read as a fragment delimiter —
      // go_router would then match `/terminal/<hostId>` and look up an id that
      // does not exist, so the screen would open on "no open sessions" and
      // tapping a host would appear to do nothing at all.
      //
      // Not the tmux session's name: ids restart every launch, and a name
      // derived from one would let a new tab reattach an unrelated old
      // session. That name is random, and carries this device's id.
      id: '${host.id}-${_counter++}',
      title: host.label,
      hostId: host.id,
      connection: transport,
      startupCommand: host.startupCommand,
      // A tab picking up a kept session keeps it, whatever the setting says
      // now: turning it off is about new tabs, not about abandoning old ones.
      keepOnServer: tmuxName != null || settings.keepSessionsOnServer,
      tmuxName: tmuxName ?? newTmuxSessionName(ref.read(deviceIdProvider)),
      env: host.envVars,
      resuming: resuming && tmuxName != null,
      ownsTmuxSession: ownsTmuxSession,
      // Read once, here: xterm2 sizes the ring when the terminal is built.
      scrollbackLines: settings.scrollbackLines,
      notices: TerminalNotices(
        connectionLost: l10n.terminalNoticeConnectionLost,
        sessionEnded: l10n.terminalNoticeSessionEnded,
        sessionClosed: l10n.terminalNoticeSessionClosed,
        reconnected: l10n.terminalNoticeReconnected,
        tmuxUnavailable: l10n.terminalNoticeTmuxUnavailable,
        tmuxSessionGone: l10n.terminalNoticeTmuxSessionGone,
      ),
    );

    if (activate || _sessions.isEmpty) _activeId = session.id;
    // [split] opens the session as a pane beside an existing one instead of
    // as a tab of its own.
    _insert(session, split);
    _watchTriggers();
    _publish();
    await ref
        .read(hostRepositoryProvider)
        .touch(host.id, now: DateTime.now().toUtc());
    // Started after the tab exists, so the UI can show "connecting" and the
    // host key prompt has a screen to appear over.
    await session.start();
    // Which OS the host runs, for its tile — once per run, over this
    // session's connection, never a handshake of its own.
    if (transport.isConnected) {
      unawaited(
        ref
            .read(hostOsProvider.notifier)
            .detect(host.id, ConnectionExec(transport)),
      );
    }
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

  /// The open tab bound to tmux session [name] on [hostId], if any — so
  /// attaching a session from the server's list selects the tab already
  /// showing it rather than opening it twice.
  TerminalSession? tabForTmux(String hostId, String name) {
    for (final session in _sessions) {
      if (session.hostId == hostId &&
          session.keepOnServer &&
          session.tmuxName == name) {
        return session;
      }
    }
    return null;
  }

  /// Whether any tab is open to [hostId], live or waiting to reconnect.
  bool hasTabFor(String hostId) =>
      _sessions.any((session) => session.hostId == hostId);

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
    required KeyboardInteractivePrompter interactivePrompt,
  }) async {
    final connection = await _buildConnection(
      host,
      onUnknownHostKey: onUnknownHostKey,
      prompt: prompt,
      interactivePrompt: interactivePrompt,
    );
    // Establishes the session now rather than lazily on first use, so a bad
    // host key or a rejected credential surfaces to the caller immediately
    // instead of on whichever tunnel happens to accept the first connection.
    try {
      await connection.client();
    } on Object {
      // Nobody else holds it: a failed bare connection is closed here or
      // never.
      unawaited(connection.close());
      rethrow;
    }
    await ref
        .read(hostRepositoryProvider)
        .touch(host.id, now: DateTime.now().toUtc());
    return connection;
  }

  Future<SshConnection> _buildConnection(
    SshHost host, {
    required HostKeyTrustDecision onUnknownHostKey,
    required SecretPrompt prompt,
    required KeyboardInteractivePrompter interactivePrompt,
  }) async {
    final knownHosts = await ref.read(knownHostsProvider.future);
    final hosts = ref.read(hostRepositoryProvider);
    final target = await hosts.targetFor(host);

    return SshConnection(
      target: target,
      // The host's own choice, final hop only — a bastion never gets the
      // agent, whatever the target says (see [agentHandlerFor]).
      forwardAgent: target.forwardAgent,
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
        interactivePrompt: interactivePrompt,
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
  ///
  /// A tab, not a session: the panes of a split tab are one stop, and
  /// arriving at it lands on the pane that was last in use there.
  void cycle(int delta) {
    final all = tabs;
    if (all.length < 2) return;
    final active = activeId;
    final current = all.indexWhere((tab) => tab.contains(active ?? ''));
    if (current < 0) return;
    // Wraps, the way every tabbed application does: past the last tab is the
    // first one, not a dead end.
    final next = (current + delta + all.length) % all.length;
    select(all[next].focused);
  }

  /// Closes one session — one pane of a split tab, or a whole plain tab.
  void close(String id) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index < 0) return;

    // Ended, not merely disposed: closing a tab is the user's decision, so a
    // tmux session kept for it on the server goes too.
    _sessions.removeAt(index).end();
    _watchTriggers();
    // Its sibling takes the space, and the focus if it had it.
    final successor = _layouts.remove(id);

    // Focus the neighbour, the way every tabbed interface does: closing the
    // tab you are looking at should leave you next to where you were, not on
    // whichever tab happens to be last. A pane of a split hands focus to the
    // pane beside it instead, which is still in the same tab.
    if (_activeId == id) {
      if (successor != null) {
        _activeId = successor;
      } else if (_sessions.isEmpty) {
        _activeId = null;
      } else {
        final neighbour = _sessions[(index - 1).clamp(0, _sessions.length - 1)];
        _activeId = tabs
            .firstWhere((tab) => tab.contains(neighbour.id))
            .focused;
      }
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
