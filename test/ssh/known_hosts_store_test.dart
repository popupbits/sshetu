import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/host_key.dart';
import 'package:sshetu/core/ssh/host_key_verifier.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';

import 'fixtures/known_hosts_fixture.dart';

/// Hashed entries imported from a `known_hosts` file, found by name at
/// verify time, and RSA keys matched across signature algorithms.
void main() {
  late InMemoryKnownHostsStore store;

  setUp(() => store = InMemoryKnownHostsStore());

  KnownHostKey key(
    String hostname,
    int port,
    String type,
    String fingerprint,
  ) => KnownHostKey(
    hostname: hostname,
    port: port,
    keyType: type,
    fingerprint: fingerprint,
    trustedAt: DateTime.utc(2026),
  );

  SshHostKeyVerifier verifier(String host, int port) =>
      SshHostKeyVerifier(knownHosts: store, hostname: host, port: port);

  Uint8List fp(String value) => Uint8List.fromList(utf8.encode(value));

  test('a hashed entry is found by the name it hashes', () async {
    await store.trust(
      key(kHashedExampleCom, 0, 'ssh-ed25519', kEd25519Fingerprint),
    );
    expect(store.findAll('example.com', 22), hasLength(1));
    expect(store.findAll('Example.COM', 22), hasLength(1));
    expect(store.findAll('example.org', 22), isEmpty);
    expect(store.find('example.com', 22)?.isHashed, isTrue);
  });

  test('the port is part of a hashed name', () async {
    await store.trust(
      key(kHashedExampleOrg2222, 0, 'ssh-rsa', kRsaFingerprint),
    );
    expect(store.findAll('example.org', 2222), hasLength(1));
    expect(store.findAll('example.org', 22), isEmpty);
  });

  test('an exact pin comes before hashed ones', () async {
    await store.trust(
      key(kHashedExampleCom, 0, 'ssh-ed25519', kEd25519Fingerprint),
    );
    await store.trust(key('example.com', 22, 'ssh-rsa', kRsaFingerprint));
    final found = store.findAll('example.com', 22);
    expect(found.map((k) => k.isHashed), [false, true]);
  });

  group('the verifier', () {
    test('trusts a key that any matching entry pins', () async {
      // Two hashed lines for one host, one per key type — how OpenSSH
      // writes a server with two keys under HashKnownHosts.
      await store.trust(
        key(kHashedExampleOrg2222, 0, 'ssh-rsa', kRsaFingerprint),
      );
      final v = verifier('example.org', 2222);
      expect(await v.verify('rsa-sha2-512', fp(kRsaFingerprint)), isTrue);
      expect(v.lastPresentation!.verdict, HostKeyVerdict.trusted);
    });

    test('refuses a key no entry for the host pins', () async {
      await store.trust(
        key(kHashedExampleCom, 0, 'ssh-ed25519', kEd25519Fingerprint),
      );
      final v = verifier('example.com', 22);
      expect(await v.verify('ssh-ed25519', fp(kRsaFingerprint)), isFalse);
      expect(v.lastPresentation!.verdict, HostKeyVerdict.changed);
      expect(v.lastPresentation!.known?.fingerprint, kEd25519Fingerprint);
    });

    test('matches an ssh-rsa pin when rsa-sha2-256 is negotiated', () async {
      await store.trust(key('h.example', 22, 'ssh-rsa', kRsaFingerprint));
      final v = verifier('h.example', 22);
      expect(await v.verify('rsa-sha2-256', fp(kRsaFingerprint)), isTrue);
    });

    test('still refuses a different key family with the same text', () async {
      await store.trust(key('h.example', 22, 'ssh-rsa', kEd25519Fingerprint));
      final v = verifier('h.example', 22);
      expect(await v.verify('ssh-ed25519', fp(kEd25519Fingerprint)), isFalse);
    });

    test('an unrelated hashed entry leaves a host unknown', () async {
      await store.trust(
        key(kHashedExampleCom, 0, 'ssh-ed25519', kEd25519Fingerprint),
      );
      final v = verifier('other.example', 22);
      expect(await v.verify('ssh-ed25519', fp(kEd25519Fingerprint)), isFalse);
      expect(v.lastPresentation!.verdict, HostKeyVerdict.unknown);
    });
  });
}
