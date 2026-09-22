import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../secrets/locked_secret_vault.dart';
import 'host_key.dart';
import 'host_key_verifier.dart';
import 'keyboard_interactive.dart';
import 'resilient_ssh_socket.dart';
import 'ssh_algorithm_policy.dart';
import 'ssh_connection_state.dart';
import 'ssh_credentials.dart';
import 'ssh_target.dart';

/// Builds the verifier for one address in a chain.
///
/// A factory rather than a single verifier because a jump chain presents a
/// host key **per hop**, and each has to be checked against the known-hosts
/// entry for *its own* address. Verifying only the final host would let a
/// compromised bastion go unnoticed, which is exactly the machine an attacker
/// would want.
typedef HostKeyVerifierFactory = SshHostKeyVerifier Function(
  String hostname,
  int port,
);

/// Raised when a connection cannot be established or has been lost.
///
/// [cause] lets a caller tell a refused host key ([HostKeyRejected]) from a
/// bad credential from an unreachable host, without any of them being mistaken
/// for success.
class SshConnectionException implements Exception {
  SshConnectionException(this.message, {this.cause, this.retryable = false});

  final String message;
  final Object? cause;

  /// Whether retrying could plausibly help (network) or not (host key, auth).
  final bool retryable;

  @override
  String toString() =>
      'SshConnectionException: $message${cause == null ? '' : ' ($cause)'}';
}

/// One live SSH connection to one [SshTarget], with its lifecycle.
///
/// Everything that runs on a host shares a single connection: a shell, an SFTP
/// browser and three port forwards are channels on one transport, not four TCP
/// connections and four handshakes. [client] is therefore the only way in — it
/// returns the existing session, waits for one being established, or
/// reconnects with backoff.
///
/// A lost connection is never papered over: [client] throws
/// [SshConnectionException] rather than handing back a dead session, and
/// [states] reports the transition so the UI can say so.
class SshConnection {
  SshConnection({
    required this.target,
    required this.verifierFactory,
    this.credentials = const NoCredentials(),
    this.connectTimeout = const Duration(seconds: 15),
    this.interactiveTimeout = const Duration(minutes: 5),
    this.maxAttempts = 3,
  });

  final SshTarget target;
  final HostKeyVerifierFactory verifierFactory;
  final SshCredentialSource credentials;

  /// How long to wait for **TCP** to a host that may simply be down.
  ///
  /// Short on purpose: nothing is waiting on a person here, and a server that
  /// has not answered in fifteen seconds is not about to.
  final Duration connectTimeout;

  /// How long the handshake and authentication may take **once connected**.
  ///
  /// Deliberately human-scale, and that is the whole reason it is a separate
  /// number. Both phases can stop and ask the user something: an unknown host
  /// key raises a dialog from inside `onVerifyHostKey`, and a password prompt
  /// runs inside authentication. Holding those to a network timeout means the
  /// clock for *reading a SHA256 fingerprint and comparing it against what the
  /// server operator published* is fifteen seconds — so the careful user, the
  /// only one the dialog is for, is the one whose connection dies. Anyone who
  /// tapped through without looking got connected.
  ///
  /// Five minutes still bounds a genuinely hung server, and the TCP timeout
  /// above still catches one that never answered at all.
  final Duration interactiveTimeout;

  /// How many attempts one [client] call makes before giving up.
  final int maxAttempts;

  final StreamController<SshConnectionState> _states =
      StreamController<SshConnectionState>.broadcast();

  SSHClient? _client;

  /// Clients for the intermediate hops, outermost first. Held so they can be
  /// closed with the connection: a bastion session left open after the host
  /// behind it is gone is a leaked connection the user cannot see.
  final List<SSHClient> _chain = [];

  Future<SSHClient>? _connecting;
  bool _closed = false;

  /// Hops, by address, that refused the saved password when it was sent
  /// through keyboard-interactive without asking. From then on this
  /// connection asks the user instead — the saved password is tried once, not
  /// replayed at the server on every attempt.
  final Set<String> _savedPasswordRefused = {};
  SshConnectionState _state = const SshConnectionState.idle();

  SshConnectionState get state => _state;

  /// Lifecycle transitions, for the UI and for logs.
  Stream<SshConnectionState> get states => _states.stream;

  /// Whether a usable session is open right now.
  bool get isConnected => _client != null && !_client!.isClosed;

  /// The live session, connecting or reconnecting if needed.
  ///
  /// Throws [SshConnectionException] when the host cannot be reached, a host
  /// key is refused, or authentication fails — never returns a closed session.
  Future<SSHClient> client() {
    if (_closed) {
      throw SshConnectionException(
        'Connection to ${target.address} is closed.',
      );
    }
    final existing = _client;
    if (existing != null && !existing.isClosed) return Future.value(existing);
    return _connecting ??= _connectWithRetries().whenComplete(() {
      _connecting = null;
    });
  }

  /// Drops the current session so the next [client] call reconnects.
  Future<void> reset() async {
    await _teardown();
    _emit(const SshConnectionState(status: SshConnectionStatus.disconnected));
  }

  /// Closes the connection permanently, including every hop behind it.
  Future<void> close() async {
    _closed = true;
    await _teardown();
    await _states.close();
  }

  /// Whether the server still answers, within [timeout].
  ///
  /// For the moments a socket is most likely to have died without anyone
  /// noticing — the app coming back from the background, the phone changing
  /// networks. A connection that does not answer is torn down on the spot
  /// and reported as dropped, which is what lets a reconnect start now
  /// rather than after TCP's own timeout, many minutes later.
  Future<bool> probe({Duration timeout = const Duration(seconds: 5)}) async {
    final current = _client;
    if (current == null || current.isClosed) return false;
    try {
      await current.ping().timeout(timeout);
      return true;
    } on Object catch (e) {
      _declareDead(current, e is TimeoutException ? null : e);
      return false;
    }
  }

  Timer? _watchdog;
  bool _watchdogBusy = false;

  /// Pings the server every keepalive interval and treats silence as a drop.
  void _startWatchdog(SSHClient client) {
    _watchdog?.cancel();
    _watchdog = null;
    final interval = target.keepaliveOrNull;
    if (interval == null) return;
    // Generous: a slow link is not a dead one. At least ten seconds, and
    // never longer than the interval itself, so pings cannot pile up.
    final timeout = interval < const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : interval;
    _watchdog = Timer.periodic(interval, (_) async {
      if (_watchdogBusy || !identical(_client, client)) return;
      _watchdogBusy = true;
      try {
        await probe(timeout: timeout);
      } finally {
        _watchdogBusy = false;
      }
    });
  }

  /// Tears down [client] because it stopped answering, and says so.
  void _declareDead(SSHClient client, Object? error) {
    if (!identical(_client, client)) return;
    _client = null;
    _watchdog?.cancel();
    _watchdog = null;
    // Closing the client ends every channel on it, which is how the shell
    // learns the link is gone.
    unawaited(client.close().catchError((Object _) {}));
    for (final hop in _chain.reversed) {
      if (!hop.isClosed) unawaited(hop.close().catchError((Object _) {}));
    }
    _chain.clear();
    if (_closed) return;
    _emit(
      SshConnectionState(
        status: SshConnectionStatus.disconnected,
        error: error == null
            ? 'The server stopped responding.'
            : _describe(error),
      ),
    );
  }

  Future<void> _teardown() async {
    _watchdog?.cancel();
    _watchdog = null;
    final current = _client;
    _client = null;
    if (current != null && !current.isClosed) current.close();

    // Innermost first: closing a bastion before the session running through it
    // turns an orderly shutdown into a dropped link.
    for (final hop in _chain.reversed) {
      if (!hop.isClosed) hop.close();
    }
    _chain.clear();
  }

  Future<SSHClient> _connectWithRetries() async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        final wait = reconnectBackoff(attempt - 1);
        _emit(
          SshConnectionState(
            status: SshConnectionStatus.disconnected,
            error: _describe(lastError),
            attempt: attempt - 1,
            nextRetryIn: wait,
          ),
        );
        await Future<void>.delayed(wait);
        if (_closed) break;
      }
      _emit(
        SshConnectionState(
          status: SshConnectionStatus.connecting,
          attempt: attempt - 1,
        ),
      );
      try {
        final client = await _connectOnce();
        _client = client;
        _startWatchdog(client);
        _emit(const SshConnectionState(status: SshConnectionStatus.connected));
        return client;
      } on SshConnectionException catch (e) {
        lastError = e;
        // A refused host key or a rejected credential will be refused again in
        // half a second. Retrying it just delays telling the user the truth.
        if (!e.retryable) {
          _fail(e);
          rethrow;
        }
      } on VaultLockedException catch (e) {
        // The user declined the credential lock's prompt. Not retried — asking
        // again in half a second is nagging, not resilience — and reported as
        // a failure so the tab says why instead of spinning on "connecting".
        await _teardown();
        final failure = SshConnectionException(e.message, cause: e);
        _fail(failure);
        throw failure;
      }
    }
    final failure = SshConnectionException(
      'Could not connect to ${target.address} after $maxAttempts attempts: '
      '${_describe(lastError)}',
      cause: lastError,
      retryable: true,
    );
    _fail(failure);
    throw failure;
  }

  /// Dials the whole chain, outermost bastion first.
  ///
  /// Each hop after the first is reached over a `direct-tcpip` channel on the
  /// previous one, which is what `ProxyJump` does and why it is safer than
  /// agent forwarding: this client authenticates to every host itself, so no
  /// bastion ever sees a credential for anything behind it.
  Future<SSHClient> _connectOnce() async {
    await _teardown();
    final hops = target.chain;
    SSHClient? previous;

    for (var i = 0; i < hops.length; i++) {
      final hop = hops[i];
      final isFinal = i == hops.length - 1;

      final SSHSocket socket;
      if (previous == null) {
        try {
          socket = ResilientSshSocket(
            await SSHSocket.connect(
              hop.hostname,
              hop.port,
              timeout: connectTimeout,
            ),
          );
        } on Object catch (e) {
          await _teardown();
          throw SshConnectionException(
            'Cannot reach ${hop.hostname}:${hop.port}',
            cause: e,
            retryable: true,
          );
        }
      } else {
        try {
          socket = await previous.forwardLocal(hop.hostname, hop.port);
        } on Object catch (e) {
          await _teardown();
          throw SshConnectionException(
            'The jump host could not open a connection to '
            '${hop.hostname}:${hop.port}',
            cause: e,
            retryable: true,
          );
        }
      }

      final client = await _authenticate(hop, socket);
      if (isFinal) return client;
      _chain.add(client);
      previous = client;
    }

    // Unreachable: `hops` always contains at least `target`.
    throw SshConnectionException('No target to connect to.');
  }

  Future<SSHClient> _authenticate(SshTarget hop, SSHSocket socket) async {
    // Credentials are resolved before the handshake completes but the key is
    // read first: a host with a missing or unreadable key is a configuration
    // error and should say so immediately, rather than after a timeout.
    final identities = await _identities(hop);
    final verifier = verifierFactory(hop.hostname, hop.port);

    // Fresh per client: rounds count from zero on every attempt, and each hop
    // of a chain answers for itself with its own target.
    final interactive = KeyboardInteractiveSession(
      (challenge) => credentials.keyboardInteractive(hop, challenge),
      allowSavedPassword: !_savedPasswordRefused.contains(hop.address),
    );

    final client = SSHClient(
      socket,
      username: hop.username,
      identities: identities,
      algorithms: SshAlgorithmPolicy.forHost(
        allowLegacy: hop.allowLegacyAlgorithms,
      ),
      onVerifyHostKey: verifier.verify,
      // Password is always wired as a *fallback*, not as an exclusive mode.
      //
      // SSH negotiates: the client offers its public keys, and only if the
      // server refuses them — or asks for a password outright — does password
      // authentication happen. dartssh2 follows that order, so wiring both is
      // what `ssh` does, and it is why a host whose config named no
      // IdentityFile can now authenticate with a key instead of falling
      // straight to a password prompt it did not need.
      //
      // Nobody is prompted who would not have been: this callback is invoked
      // only when the server actually asks.
      onPasswordRequest: () async =>
          await credentials.password(hop) ??
          (throw SshConnectionException(
            'No password supplied for ${hop.address}.',
          )),
      // Keyboard-interactive: PAM's `Password:`, a one-time code, a second
      // factor after a key. Like the password, invoked only when the server
      // actually asks — and a decline returns null, which dartssh2 turns into
      // a prompt authentication failure rather than a wait.
      onUserInfoRequest: (request) => interactive.respond(
        name: request.name,
        instruction: request.instruction,
        prompts: [
          for (final prompt in request.prompts)
            KeyboardInteractivePrompt(prompt.promptText, echo: prompt.echo),
        ],
      ),
      // The final hop is watched by [_startWatchdog] instead: dartssh2's own
      // keepalive ignores an unanswered ping, so a link that died silently —
      // the normal fate of a phone's socket while it sleeps — would stay
      // "connected" until TCP gave up, many minutes later. A bastion keeps
      // dartssh2's, because the watchdog's ping travels through it anyway.
      keepAliveInterval: identical(hop, target) ? null : hop.keepaliveOrNull,
      // Not [connectTimeout]: both of these can be waiting on a dialog.
      handshakeTimeout: interactiveTimeout,
      authTimeout: interactiveTimeout,
    );

    // Listened to immediately, not after authentication: a client that fails
    // to authenticate also completes `done` with that error, and with nobody
    // listening it surfaces as an unhandled async error instead of the failure
    // the caller is about to be told about.
    unawaited(
      client.done.then(
        (_) => _handleDropped(client, null),
        onError: (Object e) => _handleDropped(client, e),
      ),
    );

    try {
      await client.authenticated;
    } on Object catch (e) {
      client.close();
      await _teardown();

      // A refused host key surfaces from dartssh2 as a handshake or auth
      // abort, so the verifier's own verdict is the accurate story to tell —
      // and for a changed key it is the most important message this app ever
      // shows.
      final presentation = verifier.lastPresentation;
      if (presentation != null &&
          presentation.verdict != HostKeyVerdict.trusted) {
        throw SshConnectionException(
          presentation.describe(),
          cause: HostKeyRejected(presentation),
        );
      }
      // A saved password behind the credential lock, and the user declined.
      if (e is VaultLockedException) {
        throw SshConnectionException(e.message, cause: e);
      }
      if (e is SSHAuthFailError && interactive.declined) {
        throw SshConnectionException(
          'Sign-in to ${hop.address} stopped: the server asked for an answer '
          '(a password or a code) and none was given.',
          cause: e,
        );
      }
      if (e is SSHAuthFailError && interactive.usedSavedPassword) {
        // The saved password was sent without asking and refused. One more
        // attempt, which asks the user — the only retry an auth failure gets,
        // because it is the only one that changes what is sent.
        _savedPasswordRefused.add(hop.address);
        throw SshConnectionException(
          'The saved password for ${hop.address} was refused.',
          cause: e,
          retryable: true,
        );
      }
      if (e is SSHAuthFailError) {
        throw SshConnectionException(
          'Authentication as ${hop.username}@${hop.hostname} was rejected.',
          cause: e,
        );
      }
      throw SshConnectionException(
        'Handshake with ${hop.address} failed',
        cause: e,
        retryable: true,
      );
    }
    return client;
  }

  /// The key pairs to offer [hop], or null when there are none.
  ///
  /// Null rather than an error: a host with no usable key is not broken, it is
  /// a host that will authenticate with a password. Only a host that named a
  /// specific key and could not produce it is a configuration error worth
  /// stopping for.
  Future<List<SSHKeyPair>?> _identities(SshTarget hop) async {
    // `password` is an explicit choice not to offer keys, and it is honoured.
    // Offering them anyway would send the user's public keys to a server they
    // deliberately did not want them sent to — a small disclosure (which other
    // machines this person can reach) but not ours to make on their behalf.
    if (hop.authMethod != SshAuthMethod.publicKey) return null;

    final keys = await credentials.privateKeys(hop);

    if (keys.isEmpty) {
      if (hop.identityId != null) {
        throw SshConnectionException(
          'The private key for ${hop.address} is not available.',
        );
      }
      return null;
    }

    final pairs = <SSHKeyPair>[];
    final rejected = <String>[];
    for (final key in keys) {
      try {
        pairs.addAll(SSHKeyPair.fromPem(key.pem, key.passphrase));
      } on Object {
        // One unreadable key among several must not sink the connection: the
        // others may well be the one this server wants. Recorded by label so
        // a total failure can still name what went wrong, and never by the
        // decoder's message — that can quote the bytes it choked on, and
        // those bytes are key material.
        rejected.add(key.label);
      }
    }

    if (pairs.isEmpty) {
      throw SshConnectionException(
        'None of the keys offered to ${hop.address} could be decoded '
        '(${rejected.join(', ')}). A wrong passphrase looks like this.',
      );
    }
    return pairs;
  }

  void _handleDropped(SSHClient client, Object? error) {
    // Only the session actually in use reports a drop: one that never
    // authenticated, or one already replaced by a reconnect, is not news.
    if (!identical(_client, client)) return;
    _client = null;
    _watchdog?.cancel();
    _watchdog = null;
    if (_closed) return;
    _emit(
      SshConnectionState(
        status: SshConnectionStatus.disconnected,
        error: error == null
            ? 'The remote host closed the connection.'
            : _describe(error),
      ),
    );
  }

  void _fail(SshConnectionException e) => _emit(
    SshConnectionState(status: SshConnectionStatus.failed, error: e.message),
  );

  void _emit(SshConnectionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  static String _describe(Object? error) => switch (error) {
    null => 'unknown error',
    SshConnectionException e => e.message,
    SocketException e => e.message.isEmpty ? 'socket error' : e.message,
    _ => error.toString(),
  };
}
