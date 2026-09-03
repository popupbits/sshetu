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
    this.subject,
  });

  final SecretRequestKind kind;

  /// `user@host:port`, so the prompt says which machine is asking. A dialog
  /// that just says "Password:" with three sessions open is a dialog people
  /// type the wrong password into.
  final String address;

  /// What the secret is for, when that is not the host — a key's label.
  final String? subject;

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

/// Asks the user for a secret. Returning null cancels.
typedef SecretPrompt = Future<SecretResponse?> Function(SecretRequest request);

/// Resolves credentials from the [SecretVault], falling back to asking.
///
/// Where the two halves meet: the vault knows what was saved, the prompt knows
/// how to ask, and the connection layer knows neither. It is also the only
/// place a secret the user types is written back — [SshCredentialSource] never
/// caches, and this honours that by writing to the vault (durable, deliberate)
/// rather than holding the value on a field.
class VaultCredentialSource implements SshCredentialSource {
  VaultCredentialSource({
    required this.vault,
    this.catalog = _noIdentities,
    this.prompt,
  });

  final SecretVault vault;

  /// Every key the user has, used when a host names none of its own.
  final IdentityCatalog catalog;

  final SecretPrompt? prompt;

  static Future<List<AvailableIdentity>> _noIdentities() async => const [];

  /// How OpenSSH orders the keys it offers when nothing says otherwise:
  /// strongest and cheapest first. Anything unrecognised sorts last rather
  /// than being dropped — an unusual key type is still worth offering.
  static const _preference = [
    'ssh-ed25519',
    'ecdsa-sha2-nistp256',
    'ecdsa-sha2-nistp384',
    'ecdsa-sha2-nistp521',
    'ssh-rsa',
  ];

  @override
  Future<List<SshPrivateKey>> privateKeys(SshTarget target) async {
    final chosen = target.identityId;

    // A host that names its key uses that key and no other. Offering the rest
    // would send public keys the user did not choose to a server that has no
    // business learning which other machines they can reach.
    if (chosen != null) {
      final key = await _load(target, chosen, mayPromptForPassphrase: true);
      return key == null ? const [] : [key];
    }

    // No `IdentityFile` — the ordinary case for an imported config, and the
    // reason nine of ten imported hosts could not use key auth at all. Offer
    // the user's keys, as `ssh` does.
    final available = [...await catalog()];
    available.sort((a, b) {
      int rank(String type) {
        final index = _preference.indexOf(type);
        return index < 0 ? _preference.length : index;
      }

      return rank(a.keyType).compareTo(rank(b.keyType));
    });

    // Passphrase-protected keys are unlocked here only when there is exactly
    // one candidate. Otherwise a host that names no key would raise a
    // passphrase dialog *per key* before the server has said which it wants —
    // asking for three secrets to use one. An encrypted key still works: name
    // it on the host, and it is unlocked deliberately.
    final soleCandidate = available.length == 1;

    final keys = <SshPrivateKey>[];
    for (final identity in available) {
      if (identity.hasPassphrase && !soleCandidate) continue;
      final key = await _load(
        target,
        identity.id,
        label: identity.label,
        hasPassphrase: identity.hasPassphrase,
        mayPromptForPassphrase: soleCandidate,
      );
      if (key != null) keys.add(key);
    }
    return keys;
  }

  /// Reads one key, and its passphrase if it has one.
  Future<SshPrivateKey?> _load(
    SshTarget target,
    String identityId, {
    required bool mayPromptForPassphrase,
    String? label,
    bool? hasPassphrase,
  }) async {
    // Never prompted for: a private key is a file, not something anyone types
    // into a dialog. Absent means the identity is broken, and the connection
    // should say so rather than ask an unanswerable question.
    final pem = await vault.read(SecretRef.identityPrivateKey(identityId));
    if (pem == null) return null;

    final ref = SecretRef.identityPassphrase(identityId);
    var passphrase = await vault.read(ref);

    if (passphrase == null && mayPromptForPassphrase) {
      final known =
          hasPassphrase ??
          (await catalog())
              .where((i) => i.id == identityId)
              .firstOrNull
              ?.hasPassphrase ??
          false;
      if (known) {
        passphrase = await _ask(
          SecretRequest(
            kind: SecretRequestKind.passphrase,
            address: target.address,
            subject: label,
            canRemember: true,
          ),
          ref,
        );
        if (passphrase == null) return null;
      }
    }

    return SshPrivateKey(
      identityId: identityId,
      label: label ?? identityId,
      pem: pem,
      passphrase: passphrase,
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
