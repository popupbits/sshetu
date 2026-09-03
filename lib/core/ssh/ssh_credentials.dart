import 'ssh_target.dart';

/// Supplies the secrets a connection needs, one target at a time.
///
/// An interface rather than three callbacks so that a chain — a host behind a
/// bastion — resolves each hop's credentials through the same object, and so
/// tests can drive the connection layer without a vault, a keystore or a UI.
///
/// Implementations decide *how* a secret is obtained: read from the
/// [SecretVault], asked for in a dialog, or refused. Returning `null` means
/// "not available", and the connection fails with a message saying which
/// secret was missing rather than a bare authentication error.
///
/// **Nothing here is cached by the connection.** A password returned for one
/// attempt is used for that attempt and dropped; if a reconnect needs it
/// again, it is asked for again. Holding credentials for the life of a
/// connection object would mean a long-lived session keeps a password in
/// memory for hours after the user typed it.
abstract interface class SshCredentialSource {
  /// PEM or OpenSSH private key material for [target]'s identity.
  ///
  /// Null when the target has no identity, or the user declined to unlock it.
  Future<String?> privateKey(SshTarget target);

  /// The passphrase for [target]'s private key.
  ///
  /// Only called when the key is actually encrypted — checked before use, so
  /// an unencrypted key never prompts.
  Future<String?> passphrase(SshTarget target);

  /// The login password for [target].
  Future<String?> password(SshTarget target);
}

/// A source that has nothing. Useful in tests, and as the explicit "this
/// connection may not prompt" case: an unattended reconnect that would need a
/// password fails instead of blocking forever on a dialog nobody will see.
class NoCredentials implements SshCredentialSource {
  const NoCredentials();

  @override
  Future<String?> privateKey(SshTarget target) async => null;

  @override
  Future<String?> passphrase(SshTarget target) async => null;

  @override
  Future<String?> password(SshTarget target) async => null;
}
