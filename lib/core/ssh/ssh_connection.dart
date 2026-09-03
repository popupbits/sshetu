import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'host_key.dart';
import 'host_key_verifier.dart';
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
    this.maxAttempts = 3,
  });

  final SshTarget target;
  final HostKeyVerifierFactory verifierFactory;
  final SshCredentialSource credentials;
  final Duration connectTimeout;

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

  Future<void> _teardown() async {
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

    final client = SSHClient(
      socket,
      username: hop.username,
      identities: identities,
      algorithms: SshAlgorithmPolicy.forHost(
        allowLegacy: hop.allowLegacyAlgorithms,
      ),
      onVerifyHostKey: verifier.verify,
      onPasswordRequest: hop.authMethod == SshAuthMethod.password
          ? () async =>
                await credentials.password(hop) ??
                (throw SshConnectionException(
                  'No password supplied for ${hop.address}.',
                ))
          : null,
      keepAliveInterval: hop.keepaliveInterval,
      handshakeTimeout: connectTimeout,
      authTimeout: connectTimeout,
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

  Future<List<SSHKeyPair>?> _identities(SshTarget hop) async {
    if (hop.authMethod != SshAuthMethod.publicKey) return null;
    if (hop.identityId == null) {
      throw SshConnectionException(
        '${hop.address} uses key authentication but has no key selected.',
      );
    }

    final pem = await credentials.privateKey(hop);
    if (pem == null) {
      throw SshConnectionException(
        'The private key for ${hop.address} is not available.',
      );
    }

    final bool encrypted;
    try {
      encrypted = SSHKeyPair.isEncryptedPem(pem);
    } on Object catch (e) {
      throw _undecodableKey(hop, e);
    }

    String? passphrase;
    if (encrypted) {
      passphrase = await credentials.passphrase(hop);
      if (passphrase == null) {
        throw SshConnectionException(
          'The key for ${hop.address} is passphrase-protected and no '
          'passphrase was supplied.',
        );
      }
    }

    try {
      return SSHKeyPair.fromPem(pem, passphrase);
    } on Object catch (e) {
      throw _undecodableKey(hop, e);
    }
  }

  /// Reports an unusable key by the *type* of the failure only.
  ///
  /// A decoder's exception can quote the bytes it choked on, and those bytes
  /// are key material — so neither its message nor the PEM is ever passed
  /// along, into a log or onto a screen.
  SshConnectionException _undecodableKey(SshTarget hop, Object error) =>
      SshConnectionException(
        'The private key for ${hop.address} could not be decoded '
        '(${error.runtimeType}). A wrong passphrase looks like this.',
      );

  void _handleDropped(SSHClient client, Object? error) {
    // Only the session actually in use reports a drop: one that never
    // authenticated, or one already replaced by a reconnect, is not news.
    if (!identical(_client, client)) return;
    _client = null;
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
