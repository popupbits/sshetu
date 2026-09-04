import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/locked_secret_vault.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';

void main() {
  group('SecretRef', () {
    test(
      'namespaces by owner kind, so a host and an identity cannot collide',
      () {
        // Both created from one import would otherwise share an id.
        const id = 'shared-id';
        expect(
          const SecretRef.hostPassword(id).storageKey,
          isNot(const SecretRef.identityPrivateKey(id).storageKey),
        );
      },
    );

    test('separates a private key from its passphrase', () {
      expect(
        const SecretRef.identityPrivateKey('k1').storageKey,
        isNot(const SecretRef.identityPassphrase('k1').storageKey),
      );
    });

    test('forIdentity covers every slot an identity can own', () {
      // The failure this guards is silent: forget the passphrase slot and key
      // material stays on the device after the user deleted the key.
      final refs = SecretRef.forIdentity('k1');
      expect(refs.map((r) => r.kind).toSet(), {
        SecretKind.identityPrivateKey,
        SecretKind.identityPassphrase,
      });
    });

    test('toString carries the address but never a value', () {
      const ref = SecretRef.identityPrivateKey('k1');
      expect(ref.toString(), contains('identity/k1/private'));
    });
  });

  group('SecretVault contract', () {
    late InMemorySecretVault vault;
    const ref = SecretRef.hostPassword('h1');

    setUp(() => vault = InMemorySecretVault());

    test('a missing secret reads as null, not an error', () async {
      expect(await vault.read(ref), isNull);
    });

    test(
      'deleting a missing secret succeeds, so purging is idempotent',
      () async {
        await vault.delete(ref);
        await vault.delete(ref);
        expect(await vault.contains(ref), isFalse);
      },
    );

    test('deleteAll removes every slot for an owner', () async {
      await vault.write(const SecretRef.identityPrivateKey('k1'), 'PEM');
      await vault.write(const SecretRef.identityPassphrase('k1'), 'hunter2');
      expect(vault.length, 2);

      await vault.deleteAll(SecretRef.forIdentity('k1'));
      expect(vault.length, 0);
    });

    test('deleteAll leaves other owners alone', () async {
      await vault.write(const SecretRef.identityPrivateKey('k1'), 'PEM-1');
      await vault.write(const SecretRef.identityPrivateKey('k2'), 'PEM-2');

      await vault.deleteAll(SecretRef.forIdentity('k1'));

      expect(
        await vault.read(const SecretRef.identityPrivateKey('k2')),
        'PEM-2',
      );
    });
  });

  group('LockedSecretVault', () {
    late InMemorySecretVault inner;
    late int prompts;
    var allow = true;
    var now = Duration.zero;
    const ref = SecretRef.hostPassword('h1');

    LockedSecretVault build({Duration grace = const Duration(minutes: 5)}) =>
        LockedSecretVault(
          inner: inner,
          gracePeriod: grace,
          clock: () => now,
          presenceCheck: (_) async {
            prompts++;
            return allow;
          },
        );

    setUp(() async {
      inner = InMemorySecretVault();
      prompts = 0;
      allow = true;
      now = Duration.zero;
      await inner.write(ref, 's3cret');
    });

    test('reading prompts once, then rides the grace period', () async {
      final vault = build();

      expect(await vault.read(ref), 's3cret');
      now += const Duration(minutes: 1);
      expect(await vault.read(ref), 's3cret');

      expect(prompts, 1, reason: 'one unlock should cover the whole window');
    });

    test('prompts again once the grace period expires', () async {
      final vault = build(grace: const Duration(minutes: 5));

      await vault.read(ref);
      now += const Duration(minutes: 6);
      await vault.read(ref);

      expect(prompts, 2);
    });

    test('a refused unlock throws and does not leak the secret', () async {
      allow = false;
      final vault = build();

      await expectLater(vault.read(ref), throwsA(isA<VaultLockedException>()));
    });

    test('a presence check that throws locks rather than opens', () async {
      // The failure mode that matters: a device with no enrolled biometric
      // must not fall through to handing the secret over.
      final vault = LockedSecretVault(
        inner: inner,
        clock: () => now,
        presenceCheck: (_) async => throw StateError('no biometric hardware'),
      );

      await expectLater(vault.read(ref), throwsA(isA<VaultLockedException>()));
      expect(vault.isUnlocked, isFalse);
    });

    test('concurrent reads raise a single prompt', () async {
      // Connecting a host reads a key and its passphrase at once; that is one
      // unlock, not a queue of fingerprint dialogs.
      await inner.write(const SecretRef.identityPrivateKey('k1'), 'PEM');
      final vault = build();

      await Future.wait([
        vault.read(ref),
        vault.read(const SecretRef.identityPrivateKey('k1')),
      ]);

      expect(prompts, 1);
    });

    test('contains does not prompt', () async {
      // A host list showing "password saved" per row must not ask for a
      // fingerprint per row.
      final vault = build();

      expect(await vault.contains(ref), isTrue);
      expect(prompts, 0);
    });

    test('write and delete do not prompt', () async {
      final vault = build();

      await vault.write(const SecretRef.hostPassword('h2'), 'new');
      await vault.delete(const SecretRef.hostPassword('h2'));

      expect(prompts, 0);
    });

    test('lock() closes the window immediately', () async {
      final vault = build();

      await vault.read(ref);
      expect(vault.isUnlocked, isTrue);

      vault.lock();
      expect(vault.isUnlocked, isFalse);

      await vault.read(ref);
      expect(prompts, 2);
    });
  });

  group('a store that refuses to erase', () {
    test('still has every other secret taken from it', () async {
      // Stopping at the first refusal left the rest behind: a key the store
      // would not erase also stranded its passphrase, which nothing would
      // ever come back for.
      final refused = <String>{'identity/k1/private'};
      final vault = _PartlyRefusingVault(refused);
      await vault.write(SecretRef.identityPrivateKey('k1'), 'KEY');
      await vault.write(SecretRef.identityPassphrase('k1'), 'PHRASE');

      await expectLater(
        vault.deleteAll(SecretRef.forIdentity('k1')),
        throwsA(isA<SecretVaultException>()),
      );

      expect(
        await vault.read(SecretRef.identityPassphrase('k1')),
        isNull,
        reason: 'the passphrase was erasable and must be gone',
      );
      expect(
        await vault.read(SecretRef.identityPrivateKey('k1')),
        'KEY',
        reason: 'and the one that was refused is honestly still there',
      );
    });
  });
}

/// Refuses to delete exactly the keys it was told to.
class _PartlyRefusingVault extends InMemorySecretVault {
  _PartlyRefusingVault(this.refuse);

  final Set<String> refuse;

  @override
  Future<void> delete(SecretRef ref) async {
    if (refuse.contains(ref.storageKey)) {
      throw SecretVaultException('Could not remove secret', ref: ref);
    }
    return super.delete(ref);
  }

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    Object? failure;
    for (final ref in refs) {
      try {
        await delete(ref);
      } on Object catch (error) {
        failure ??= error;
      }
    }
    if (failure != null) throw failure;
  }
}
