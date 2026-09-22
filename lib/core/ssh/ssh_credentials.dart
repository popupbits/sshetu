import 'keyboard_interactive.dart';
import 'ssh_target.dart';

export 'keyboard_interactive.dart'
    show
        KeyboardInteractiveAnswers,
        KeyboardInteractiveChallenge,
        KeyboardInteractivePrompt;

/// One private key, ready to be offered to a server.
class SshPrivateKey {
  const SshPrivateKey({
    required this.identityId,
    required this.label,
    required this.pem,
    this.passphrase,
  });

  final String identityId;

  /// What the user calls this key. Used in messages, never the material.
  final String label;

  /// PEM or OpenSSH private key material.
  final String pem;

  /// Its passphrase, when it needed one and the user supplied it.
  final String? passphrase;

  /// Prints the label only — never the material, never the passphrase.
  @override
  String toString() => 'SshPrivateKey($label)';
}

/// A key the app knows about, without its material.
///
/// Enough to decide *which* keys to offer and in what order, without unlocking
/// any of them: choosing an identity should never require reading one.
class AvailableIdentity {
  const AvailableIdentity({
    required this.id,
    required this.label,
    required this.keyType,
    required this.hasPassphrase,
  });

  final String id;
  final String label;
  final String keyType;
  final bool hasPassphrase;
}

/// Lists the identities the user has. Injected so the connection layer never
/// reaches into a repository.
typedef IdentityCatalog = Future<List<AvailableIdentity>> Function();

/// Supplies the secrets a connection needs, one target at a time.
///
/// An interface rather than loose callbacks so that a chain — a host behind a
/// bastion — resolves each hop's credentials through the same object, and so
/// tests can drive the connection layer without a vault, a keystore or a UI.
///
/// **Nothing here is cached by the connection.** A password returned for one
/// attempt is used for that attempt and dropped; if a reconnect needs it again
/// it is asked for again. Holding credentials for the life of a connection
/// object would keep a password in memory for hours after the user typed it.
abstract interface class SshCredentialSource {
  /// The keys to offer [target], in the order they should be tried.
  ///
  /// A **list**, because that is what SSH actually does. OpenSSH with no
  /// `IdentityFile` offers every default key it can find and lets the server
  /// pick; a client that insists on being told exactly one key cannot connect
  /// to any of the hosts in a typical `~/.ssh/config`, which name none. Empty
  /// is a valid answer — the connection then falls back to a password.
  Future<List<SshPrivateKey>> privateKeys(SshTarget target);

  /// The login password for [target], asked for only if key authentication
  /// was not offered or was refused.
  Future<String?> password(SshTarget target);

  /// Answers one round of keyboard-interactive authentication for [target] —
  /// a PAM `Password:`, a one-time code, whatever the server asks.
  ///
  /// Called once per round, so a password round followed by a code round is
  /// two calls, each with its own [KeyboardInteractiveChallenge.round]. Each
  /// hop of a jump chain gets its own calls with its own [target], so a prompt
  /// can always say which machine is asking.
  ///
  /// Null declines, and authentication fails promptly with a message saying
  /// so. A source that must never supply a password — key verification — has
  /// to decline here too, or keyboard-interactive becomes the side door that
  /// lets a password satisfy a connection meant to prove a key.
  Future<KeyboardInteractiveAnswers?> keyboardInteractive(
    SshTarget target,
    KeyboardInteractiveChallenge challenge,
  );
}

/// A source that has nothing.
///
/// For tests, and as the explicit "this connection may not prompt" case: an
/// unattended reconnect that would need a password fails instead of blocking
/// forever on a dialog nobody will see.
class NoCredentials implements SshCredentialSource {
  const NoCredentials();

  @override
  Future<List<SshPrivateKey>> privateKeys(SshTarget target) async => const [];

  @override
  Future<String?> password(SshTarget target) async => null;

  @override
  Future<KeyboardInteractiveAnswers?> keyboardInteractive(
    SshTarget target,
    KeyboardInteractiveChallenge challenge,
  ) async => null;
}
