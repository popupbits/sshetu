import 'dart:async';

import '../secrets/secret_ref.dart';
import '../secrets/secret_vault.dart';
import 'ssh_credentials.dart';
import 'ssh_target.dart';

/// What the app is asking the user for.
enum SecretRequestKind { password, passphrase }

/// A request for a secret the vault could not supply.
class SecretRequest {
  const SecretRequest({
    required this.kind,
    required this.address,
    required this.canRemember,
  });

  final SecretRequestKind kind;

  /// `user@host:port`, so the prompt says which machine is asking. A dialog
  /// that just says "Password:" with three sessions open is a dialog people
  /// type the wrong password into.
  final String address;

  /// Whether offering to save this makes sense. False for a quick connect,
  /// which has nowhere to save it to.
  final bool canRemember;
}

/// The user's answer.
class SecretResponse {
  const SecretResponse(this.value, {this.remember = false});

  final String value;

  /// Whether to write it to the vault for next time.
  final bool remember;
}

/// Asks the user for a secret. Returning null cancels the connection.
typedef SecretPrompt = Future<SecretResponse?> Function(SecretRequest request);

/// Resolves credentials from the [SecretVault], falling back to asking.
///
/// This is where the two halves meet: the vault knows what was saved, the
/// prompt knows how to ask, and the connection layer knows neither. It is also
/// the only place a secret the user types is written back — [SshCredentialSource]
/// is documented as never caching, and this honours that by writing to the
/// vault (durable, deliberate) rather than holding the value on a field.
class VaultCredentialSource implements SshCredentialSource {
  VaultCredentialSource({required this.vault, this.prompt});

  final SecretVault vault;
  final SecretPrompt? prompt;

  @override
  Future<String?> privateKey(SshTarget target) {
    final id = target.identityId;
    if (id == null) return Future.value();
    // Never prompted for: a private key is a file, not something anyone types
    // into a dialog. If it is not in the vault, the identity is broken and the
    // connection should say so rather than asking an unanswerable question.
    return vault.read(SecretRef.identityPrivateKey(id));
  }

  @override
  Future<String?> passphrase(SshTarget target) async {
    final id = target.identityId;
    if (id == null) return null;

    final ref = SecretRef.identityPassphrase(id);
    final saved = await vault.read(ref);
    if (saved != null) return saved;

    return _ask(
      SecretRequest(
        kind: SecretRequestKind.passphrase,
        address: target.address,
        canRemember: true,
      ),
      ref,
    );
  }

  @override
  Future<String?> password(SshTarget target) async {
    final id = target.credentialId;

    if (id != null) {
      final saved = await vault.read(SecretRef.hostPassword(id));
      if (saved != null) return saved;
    }

    return _ask(
      SecretRequest(
        kind: SecretRequestKind.password,
        address: target.address,
        // A quick connect has no row to hang a saved password on.
        canRemember: id != null,
      ),
      id == null ? null : SecretRef.hostPassword(id),
    );
  }

  /// Asks, and saves the answer only if the user said to.
  Future<String?> _ask(SecretRequest request, SecretRef? saveTo) async {
    final ask = prompt;
    // No prompt wired means nobody is watching — an unattended reconnect.
    // Failing is correct: blocking forever on a dialog no one will see is how
    // a background reconnect turns into a hung session.
    if (ask == null) return null;

    final response = await ask(request);
    if (response == null) return null;

    if (response.remember && saveTo != null) {
      await vault.write(saveTo, response.value);
    }
    return response.value;
  }
}
