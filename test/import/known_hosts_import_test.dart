import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/host_key.dart';
import 'package:sshetu/core/ssh/known_hosts_file.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';
import 'package:sshetu/features/import/known_hosts_import.dart';

import '../ssh/fixtures/known_hosts_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 9, 1);
  final parsed = parseKnownHosts(kKnownHostsFixture);

  KnownHostKey pin(String host, int port, String type, String fingerprint) =>
      KnownHostKey(
        hostname: host,
        port: port,
        keyType: type,
        fingerprint: fingerprint,
        trustedAt: DateTime.utc(2025),
      );

  test('into an empty device, everything importable is new', () {
    final preview = previewKnownHostsImport(parsed, const [], now: now);

    expect(
      [
        for (final k in preview.toTrust)
          k.isHashed ? 'hashed' : '${k.hostname}:${k.port} ${k.keyType}',
      ],
      [
        // Two keys in the file; the one a connection negotiates first wins.
        'plain.example.com:22 ssh-ed25519',
        'multi.example.com:22 ecdsa-sha2-nistp256',
        '10.0.0.5:22 ecdsa-sha2-nistp256',
        'multi.example.com:2200 ecdsa-sha2-nistp256',
        'bastion.example.net:2222 ssh-rsa',
        'exact.example.com:22 ssh-ed25519',
        'hashed',
        'hashed',
      ],
    );
    expect(preview.newHashed, 2);
    expect(preview.alreadyTrusted, 0);
    expect(preview.conflicts, isEmpty);
    expect(preview.alternateKeys, 1);
    expect(preview.toTrust.every((k) => k.trustedAt == now), isTrue);
  });

  test('sorts against existing pins: trusted, conflicting, alternate', () {
    final existing = [
      // Same key as the file: already trusted.
      pin('plain.example.com', 22, 'ssh-ed25519', kEd25519Fingerprint),
      // A different RSA key for the same address: a conflict.
      pin('bastion.example.net', 2222, 'ssh-rsa', kEcdsaFingerprint),
      // The name a hashed line hashes, with that line's key.
      pin('example.com', 22, 'ssh-ed25519', kEd25519Fingerprint),
      // The other hashed line's host, pinned under another key type.
      pin('example.org', 2222, 'ecdsa-sha2-nistp256', kEcdsaFingerprint),
    ];
    final preview = previewKnownHostsImport(parsed, existing, now: now);

    expect(preview.toTrust.map((k) => '${k.hostname}:${k.port}'), [
      'multi.example.com:22',
      '10.0.0.5:22',
      'multi.example.com:2200',
      'exact.example.com:22',
    ]);
    expect(preview.alreadyTrusted, 2);
    expect(preview.conflicts, hasLength(1));
    final conflict = preview.conflicts.single;
    expect(conflict.address, 'bastion.example.net:2222');
    expect(conflict.trusted.fingerprint, kEcdsaFingerprint);
    expect(conflict.fileKeys.single.fingerprint, kRsaFingerprint);
    // plain.example.com's RSA key, and the RSA hashed line for a host
    // already pinned with ECDSA.
    expect(preview.alternateKeys, 2);
  });

  test('a hashed line conflicts with a same-type pin it names', () {
    final existing = [
      pin('example.com', 22, 'ssh-ed25519', 'SHA256:somethingElse'),
    ];
    final preview = previewKnownHostsImport(parsed, existing, now: now);
    final conflict = preview.conflicts.single;
    expect(conflict.address, 'example.com');
    expect(conflict.fileKeys.single.isHashed, isTrue);
  });

  test('importing twice finds everything already trusted', () async {
    final store = InMemoryKnownHostsStore();
    final first = previewKnownHostsImport(parsed, store.all(), now: now);
    expect(await applyKnownHostsImport(store, first), 8);

    final second = previewKnownHostsImport(parsed, store.all(), now: now);
    expect(second.isEmpty, isTrue);
    expect(second.conflicts, isEmpty);
    expect(second.alreadyTrusted, 8);
  });

  test('applying never touches a conflicting pin', () async {
    final store = InMemoryKnownHostsStore();
    final original = pin(
      'bastion.example.net',
      2222,
      'ssh-rsa',
      kEcdsaFingerprint,
    );
    await store.trust(original);
    final preview = previewKnownHostsImport(parsed, store.all(), now: now);
    await applyKnownHostsImport(store, preview);
    expect(store.find('bastion.example.net', 2222), original);
  });

  test('an imported hashed key is what verification then finds', () async {
    final store = InMemoryKnownHostsStore();
    await applyKnownHostsImport(
      store,
      previewKnownHostsImport(parsed, const [], now: now),
    );
    final found = store.findAll('example.org', 2222);
    expect(found.single.fingerprint, kRsaFingerprint);
  });
}
