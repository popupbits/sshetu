import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/ssh_credentials.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/ssh/vault_credential_source.dart';

import 'fixtures/pasted_keys.dart';

/// A vault that counts what it was asked for.
///
/// Read counts are the point of several of these tests: every read is a real
/// credential-store lookup, and on macOS's login keychain each one can raise
/// its own authorisation prompt. "It works" and "it works without asking the
/// user four times" are different properties, and only the second one is
/// pleasant to use.
class _CountingVault implements SecretVault {
  _CountingVault(this._values);

  final Map<String, String> _values;
  final List<String> reads = [];

  int readsOf(SecretRef ref) => reads.where((k) => k == ref.storageKey).length;

  @override
  Future<String?> read(SecretRef ref) async {
    reads.add(ref.storageKey);
    return _values[ref.storageKey];
  }

  @override
  Future<void> write(SecretRef ref, String value) async {
    _values[ref.storageKey] = value;
  }

  @override
  Future<void> delete(SecretRef ref) async => _values.remove(ref.storageKey);

  @override
  Future<bool> contains(SecretRef ref) async =>
      _values.containsKey(ref.storageKey);

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    for (final ref in refs) {
      _values.remove(ref.storageKey);
    }
  }
}

void main() {
  const target = SshTarget(
    hostname: 'example.com',
    username: 'deploy',
    credentialId: 'host-1',
  );

  AvailableIdentity identity(
    String id, {
    String type = 'ssh-ed25519',
    bool encrypted = false,
  }) => AvailableIdentity(
    id: id,
    label: id,
    keyType: type,
    hasPassphrase: encrypted,
  );

  group('a host that names no key', () {
    test('offers the user keys, as ssh does', () async {
      // The bug this guards: `~/.ssh/config` entries rarely name an
      // IdentityFile, and treating that as "no key auth" made nine of ten
      // imported hosts prompt for a password they did not need.
      final vault = _CountingVault({
        'identity/a/private': 'PEM-A',
        'identity/b/private': 'PEM-B',
      });
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => [identity('a'), identity('b')],
      );

      final keys = await source.privateKeys(target);
      expect(keys.map((k) => k.identityId), containsAll(['a', 'b']));
    });

    test('offers them strongest first, as ssh orders them', () async {
      final vault = _CountingVault({
        'identity/rsa/private': 'PEM',
        'identity/ed/private': 'PEM',
      });
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => [
          identity('rsa', type: 'ssh-rsa'),
          identity('ed', type: 'ssh-ed25519'),
        ],
      );

      final keys = await source.privateKeys(target);
      expect(keys.first.identityId, 'ed');
    });

    test(
      'skips encrypted keys when there is more than one candidate',
      () async {
        // Otherwise connecting to a host that names no key raises a passphrase
        // dialog *per key*, before the server has said which one it wants —
        // three secrets asked for to use one.
        final vault = _CountingVault({
          'identity/plain/private': 'PEM',
          'identity/locked/private': 'PEM',
          'identity/locked/passphrase': 'hunter2',
        });
        final source = VaultCredentialSource(
          vault: vault,
          catalog: () async => [
            identity('plain'),
            identity('locked', encrypted: true),
          ],
        );

        final keys = await source.privateKeys(target);
        expect(keys.map((k) => k.identityId), ['plain']);
      },
    );

    test('does unlock an encrypted key when it is the only one', () async {
      final vault = _CountingVault({
        'identity/only/private': 'PEM',
        'identity/only/passphrase': 'hunter2',
      });
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => [identity('only', encrypted: true)],
      );

      final keys = await source.privateKeys(target);
      expect(keys.single.passphrase, 'hunter2');
    });
  });

  group('a host that names a key', () {
    test('offers that key and no other', () async {
      // Offering the rest would send public keys the user did not choose to a
      // server with no business learning which other machines they can reach.
      final vault = _CountingVault({
        'identity/chosen/private': 'PEM-CHOSEN',
        'identity/other/private': 'PEM-OTHER',
      });
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => [identity('chosen'), identity('other')],
      );

      final keys = await source.privateKeys(
        target.copyWith(identityId: 'chosen'),
      );
      expect(keys.single.identityId, 'chosen');
      expect(vault.readsOf(const SecretRef.identityPrivateKey('other')), 0);
    });
  });

  group('credential-store traffic', () {
    test('never looks for a passphrase a key does not have', () async {
      // Each lookup is a real keychain round trip, and on macOS possibly a
      // prompt. The catalog already knows there is nothing to find.
      final vault = _CountingVault({'identity/a/private': 'PEM'});
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => [identity('a')],
      );

      await source.privateKeys(target);

      expect(
        vault.readsOf(const SecretRef.identityPassphrase('a')),
        0,
        reason: 'the key is recorded as having no passphrase',
      );
    });

    test('reads each key once, however many times it is offered', () async {
      // A reconnect must not re-read every key. Four prompts on connect and
      // four more on every retry is what made this unusable.
      final vault = _CountingVault({'identity/a/private': 'PEM'});
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => [identity('a')],
      );

      await source.privateKeys(target);
      await source.privateKeys(target);
      await source.privateKeys(target);

      expect(vault.readsOf(const SecretRef.identityPrivateKey('a')), 1);
    });

    test('a password is re-read every time, unlike a key', () async {
      // Deliberate asymmetry: a key is a file the user stored, a password is
      // something they typed, and it should not outlive the attempt.
      final vault = _CountingVault({'host/host-1/password': 'secret'});
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => const [],
      );

      await source.password(target);
      await source.password(target);

      expect(vault.readsOf(const SecretRef.hostPassword('host-1')), 2);
    });
  });

  group('with nothing available', () {
    test('offers no keys rather than failing', () async {
      // An empty list is a valid answer: the connection falls back to a
      // password. Only a host that *named* a key it cannot produce is an error.
      final source = VaultCredentialSource(
        vault: _CountingVault({}),
        catalog: () async => const [],
      );

      expect(await source.privateKeys(target), isEmpty);
    });

    test('a password with no prompt wired returns null, never hangs', () async {
      // The unattended reconnect: blocking forever on a dialog nobody will see
      // is how a background retry turns into a hung session.
      final source = VaultCredentialSource(
        vault: _CountingVault({}),
        catalog: () async => const [],
      );

      expect(await source.password(target), isNull);
    });
  });

  group('keyboard-interactive', () {
    const passwordRound = KeyboardInteractiveChallenge(
      prompts: [KeyboardInteractivePrompt('Password: ', echo: false)],
      round: 0,
    );
    const codeRound = KeyboardInteractiveChallenge(
      name: 'Two-factor',
      prompts: [KeyboardInteractivePrompt('Verification code: ', echo: true)],
      round: 1,
    );
    const passwordRef = SecretRef.hostPassword('host-1');

    test('the saved password answers a first-round PAM password prompt, '
        'without asking', () async {
      final asked = <KeyboardInteractiveRequest>[];
      final source = VaultCredentialSource(
        vault: _CountingVault({'host/host-1/password': 'secret'}),
        interactivePrompt: (request) async {
          asked.add(request);
          return null;
        },
      );

      final answers = await source.keyboardInteractive(target, passwordRound);

      expect(answers?.answers, ['secret']);
      expect(answers?.fromSavedPassword, isTrue);
      expect(asked, isEmpty);
    });

    test('a one-time code is asked for, never read from the vault and never '
        'saved', () async {
      final vault = _CountingVault({'host/host-1/password': 'secret'});
      final asked = <KeyboardInteractiveRequest>[];
      final source = VaultCredentialSource(
        vault: vault,
        interactivePrompt: (request) async {
          asked.add(request);
          // Even if a UI tried to remember it, the source refuses.
          return const KeyboardInteractiveReply(['123456'], remember: true);
        },
      );

      final answers = await source.keyboardInteractive(target, codeRound);

      expect(answers?.answers, ['123456']);
      expect(answers?.fromSavedPassword, isFalse);
      expect(asked.single.canRemember, isFalse);
      expect(asked.single.address, target.address);
      expect(asked.single.challenge.name, 'Two-factor');
      expect(vault.reads, isEmpty, reason: 'no lookup for a code prompt');
      expect(await vault.read(passwordRef), 'secret');
    });

    test('once the saved password was refused, the user is asked', () async {
      final asked = <KeyboardInteractiveRequest>[];
      final source = VaultCredentialSource(
        vault: _CountingVault({'host/host-1/password': 'wrong'}),
        interactivePrompt: (request) async {
          asked.add(request);
          return const KeyboardInteractiveReply(['right']);
        },
      );

      final answers = await source.keyboardInteractive(
        target,
        const KeyboardInteractiveChallenge(
          prompts: [KeyboardInteractivePrompt('Password:', echo: false)],
          round: 0,
          allowSavedPassword: false,
        ),
      );

      expect(answers?.answers, ['right']);
      expect(asked, hasLength(1));
      expect(asked.single.canRemember, isTrue);
    });

    test(
      'a typed password prompt answer is saved only when asked to',
      () async {
        final vault = _CountingVault({});
        var remember = false;
        final source = VaultCredentialSource(
          vault: vault,
          interactivePrompt: (request) async =>
              KeyboardInteractiveReply(const ['typed'], remember: remember),
        );

        await source.keyboardInteractive(target, passwordRound);
        expect(await vault.contains(passwordRef), isFalse);

        remember = true;
        await source.keyboardInteractive(target, passwordRound);
        expect(await vault.read(passwordRef), 'typed');
      },
    );

    test(
      'a quick connect has nowhere to save, so offers no remember',
      () async {
        const quick = SshTarget(hostname: 'example.com', username: 'deploy');
        final asked = <KeyboardInteractiveRequest>[];
        final source = VaultCredentialSource(
          vault: _CountingVault({}),
          interactivePrompt: (request) async {
            asked.add(request);
            return const KeyboardInteractiveReply(['typed'], remember: true);
          },
        );

        expect(
          (await source.keyboardInteractive(quick, passwordRound))?.answers,
          ['typed'],
        );
        expect(asked.single.canRemember, isFalse);
      },
    );

    test(
      'with no prompt wired, an unanswerable round declines, never hangs',
      () async {
        final source = VaultCredentialSource(vault: _CountingVault({}));

        expect(await source.keyboardInteractive(target, codeRound), isNull);
        expect(await source.keyboardInteractive(target, passwordRound), isNull);
      },
    );

    test('cancelling declines the round', () async {
      final source = VaultCredentialSource(
        vault: _CountingVault({}),
        interactivePrompt: (_) async => null,
      );

      expect(await source.keyboardInteractive(target, codeRound), isNull);
    });
  });

  // Regression: a mistyped passphrase was cached in the key cache every
  // connection shares, so no later connect ever asked again and the key was
  // unusable until the app restarted — and with "remember" ticked, the typo
  // was written to the vault for good.
  group('a typed passphrase', () {
    final sealed = encryptedOpenSsh();
    const chosen = SshTarget(
      hostname: 'example.com',
      username: 'deploy',
      credentialId: 'host-1',
      identityId: 'locked',
    );

    ({_CountingVault vault, VaultCredentialSource source, List<String> asked})
    open(List<String> answers) {
      final vault = _CountingVault({'identity/locked/private': sealed.pem});
      final asked = <String>[];
      final source = VaultCredentialSource(
        vault: vault,
        catalog: () async => [identity('locked', encrypted: true)],
        prompt: (request) async {
          final answer = answers[asked.length];
          asked.add(answer);
          return SecretResponse(answer, remember: true);
        },
      );
      return (vault: vault, source: source, asked: asked);
    }

    test('that is wrong is neither cached nor remembered', () async {
      final (:vault, :source, :asked) = open(['typo', fixturePassphrase]);

      final first = await source.privateKeys(chosen);
      // Still handed over, so the connection fails as a wrong passphrase.
      expect(first.single.passphrase, 'typo');
      expect(
        await vault.contains(const SecretRef.identityPassphrase('locked')),
        isFalse,
      );

      // And the next connect asks again, rather than reusing the typo.
      final second = await source.privateKeys(chosen);
      expect(asked, ['typo', fixturePassphrase]);
      expect(second.single.passphrase, fixturePassphrase);
    });

    test('that is right is remembered, and not asked for again', () async {
      final (:vault, :source, :asked) = open([fixturePassphrase]);

      await source.privateKeys(chosen);
      await source.privateKeys(chosen);

      expect(asked, [fixturePassphrase]);
      expect(
        await vault.read(const SecretRef.identityPassphrase('locked')),
        fixturePassphrase,
      );
    });
  });
}
