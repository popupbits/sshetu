import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/secrets/layered_secret_vault.dart';
import 'package:ssh_navigator/core/secrets/secret_ref.dart';
import 'package:ssh_navigator/core/secrets/secret_vault.dart';

/// Counts every call it receives, so a test can assert the network side was
/// (or was not) reached without caring what value came back.
class _CountingVault implements SecretVault {
  _CountingVault(this._inner);

  final SecretVault _inner;
  int reads = 0;
  int writes = 0;
  int deletes = 0;
  int containsCalls = 0;

  @override
  Future<String?> read(SecretRef ref) {
    reads++;
    return _inner.read(ref);
  }

  @override
  Future<void> write(SecretRef ref, String value) {
    writes++;
    return _inner.write(ref, value);
  }

  @override
  Future<void> delete(SecretRef ref) {
    deletes++;
    return _inner.delete(ref);
  }

  @override
  Future<bool> contains(SecretRef ref) {
    containsCalls++;
    return _inner.contains(ref);
  }

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) async {
    for (final ref in refs) {
      await delete(ref);
    }
  }
}

void main() {
  late _CountingVault local;
  late _CountingVault remote;
  late LayeredSecretVault vault;
  const ref = SecretRef.hostPassword('h1');

  setUp(() {
    local = _CountingVault(InMemorySecretVault());
    remote = _CountingVault(InMemorySecretVault());
    vault = LayeredSecretVault(local: local, remote: remote);
  });

  group('read', () {
    test('a local hit never reaches the remote vault', () async {
      // The bug this guards against: connecting to a host you use daily
      // making a network call on every single connection because the read
      // path fell through to the synced vault regardless of what was
      // already on the device.
      await local._inner.write(ref, 'local-secret');

      final value = await vault.read(ref);

      expect(value, 'local-secret');
      expect(remote.reads, 0, reason: 'the network was never touched');
    });

    test('a local miss falls back to the remote vault', () async {
      await remote._inner.write(ref, 'remote-secret');

      final value = await vault.read(ref);

      expect(value, 'remote-secret');
      expect(remote.reads, 1);
    });

    test(
      'a remote fallback warms the local copy, so the next read stays local',
      () async {
        await remote._inner.write(ref, 'remote-secret');

        await vault.read(ref);
        await vault.read(ref);

        // Only the first read should have needed the network — a device
        // that fell back once and then fell back on every subsequent read
        // would defeat the entire point of layering.
        expect(remote.reads, 1);
        expect(await local._inner.read(ref), 'remote-secret');
      },
    );

    test('missing on both sides reads as null, not an error', () async {
      expect(await vault.read(ref), isNull);
    });
  });

  group('write', () {
    test('a write reaches both the local and the remote vault', () async {
      await vault.write(ref, 'hunter2');

      expect(await local._inner.read(ref), 'hunter2');
      expect(await remote._inner.read(ref), 'hunter2');
    });

    test(
      'a remote write failure does not stop the local write from succeeding',
      () async {
        // The failure mode this guards against: saving a password while
        // offline must still work on this device. There is no retry queue
        // for secrets in v1 (see LayeredSecretVault's doc comment) — the
        // remote copy is simply missed until the next explicit write.
        final failingRemote = _ThrowingVault();
        final offlineVault = LayeredSecretVault(
          local: local,
          remote: failingRemote,
        );

        await offlineVault.write(ref, 'hunter2');

        expect(await local._inner.read(ref), 'hunter2');
      },
    );
  });

  group('delete and contains', () {
    test('delete reaches both sides', () async {
      await vault.write(ref, 'hunter2');
      await vault.delete(ref);

      expect(await local._inner.contains(ref), isFalse);
      expect(await remote._inner.contains(ref), isFalse);
    });

    test('contains is true if either side has it', () async {
      await remote._inner.write(ref, 'remote-only');
      expect(await vault.contains(ref), isTrue);
    });
  });
}

/// A remote vault that always fails, for the offline-write test above.
class _ThrowingVault implements SecretVault {
  @override
  Future<String?> read(SecretRef ref) => throw StateError('offline');

  @override
  Future<void> write(SecretRef ref, String value) =>
      throw StateError('offline');

  @override
  Future<void> delete(SecretRef ref) => throw StateError('offline');

  @override
  Future<bool> contains(SecretRef ref) => throw StateError('offline');

  @override
  Future<void> deleteAll(Iterable<SecretRef> refs) =>
      throw StateError('offline');
}
