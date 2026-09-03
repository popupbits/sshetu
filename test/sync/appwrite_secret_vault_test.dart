import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/appwrite_secret_vault.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';

import 'fake_secret_remote.dart';

void main() {
  late FakeSecretRemote remote;
  late AppwriteSecretVault vault;

  setUp(() {
    remote = FakeSecretRemote();
    vault = AppwriteSecretVault(remote: remote, userId: 'user-1');
  });

  test('round trips a value through the fake remote', () async {
    const ref = SecretRef.identityPrivateKey('k1');
    await vault.write(ref, 'PEM-DATA');
    expect(await vault.read(ref), 'PEM-DATA');
    expect(await vault.contains(ref), isTrue);
  });

  test(
    'a missing secret reads as null, matching every other SecretVault',
    () async {
      expect(await vault.read(const SecretRef.hostPassword('nope')), isNull);
    },
  );

  test('delete is idempotent', () async {
    const ref = SecretRef.hostPassword('h1');
    await vault.delete(ref);
    await vault.delete(ref);
    expect(await vault.contains(ref), isFalse);
  });

  test('the row id is short and charset-safe, unlike the storage key it is derived from', () async {
    // Appwrite row ids are capped at 36 chars from {a-zA-Z0-9._-}; a
    // storageKey like identity/<uuid>/private has slashes and can run well
    // past that, which is why AppwriteSecretVault hashes it rather than
    // using it directly. This pins that the hash is short enough to be a
    // legal row id for a realistically long owner id.
    final ref = SecretRef.identityPrivateKey(
      'a-very-long-identity-id-1234567890-abcdef',
    );
    await vault.write(ref, 'PEM-DATA');

    final rowId = remote.debugRowIds.single;
    expect(rowId.length, lessThanOrEqualTo(36));
    expect(RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(rowId), isTrue);
  });

  test(
    'a value over the size cap is rejected before it ever reaches the network',
    () async {
      final oversized = 'a' * (AppwriteSecretVault.maxValueBytes + 1);
      await expectLater(
        vault.write(const SecretRef.hostPassword('h1'), oversized),
        throwsA(isA<SecretVaultException>()),
      );
      expect(
        remote.debugRowIds,
        isEmpty,
        reason: 'rejected before any write was attempted',
      );
    },
  );
}
