import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/ssh/host_key.dart';
import 'package:ssh_navigator/core/ssh/host_key_verifier.dart';
import 'package:ssh_navigator/core/ssh/known_hosts_store.dart';

Uint8List fp(String value) => Uint8List.fromList(utf8.encode(value));

const kFingerprint = 'SHA256:AAAAC3NzaC1lZDI1NTE5AAAAIExampleExample';
const kOtherFingerprint = 'SHA256:BBBBC3NzaC1lZDI1NTE5AAAAIDifferentKeyXX';

void main() {
  late InMemoryKnownHostsStore store;

  setUp(() => store = InMemoryKnownHostsStore());

  SshHostKeyVerifier build({
    HostKeyTrustDecision? onUnknown,
    String hostname = 'example.com',
    int port = 22,
  }) => SshHostKeyVerifier(
    knownHosts: store,
    hostname: hostname,
    port: port,
    onUnknownHostKey: onUnknown,
    now: () => DateTime.utc(2026, 1, 1),
  );

  Future<void> trustExisting({
    String keyType = 'ssh-ed25519',
    String fingerprint = kFingerprint,
    String hostname = 'example.com',
    int port = 22,
  }) => store.trust(
    KnownHostKey(
      hostname: hostname,
      port: port,
      keyType: keyType,
      fingerprint: fingerprint,
      trustedAt: DateTime.utc(2025),
    ),
  );

  group('a matching key', () {
    test('is accepted without prompting', () async {
      await trustExisting();
      var prompted = false;
      final verifier = build(
        onUnknown: (_) {
          prompted = true;
          return true;
        },
      );

      expect(await verifier.verify('ssh-ed25519', fp(kFingerprint)), isTrue);
      expect(prompted, isFalse);
    });
  });

  group('an unknown key', () {
    test('is refused when nothing is wired to ask', () async {
      // The unattended case. A background reconnect must never trust a
      // stranger on the user's behalf.
      final verifier = build();

      expect(await verifier.verify('ssh-ed25519', fp(kFingerprint)), isFalse);
      expect(store.all(), isEmpty);
    });

    test('is refused when the user declines, and is not remembered', () async {
      final verifier = build(onUnknown: (_) => false);

      expect(await verifier.verify('ssh-ed25519', fp(kFingerprint)), isFalse);
      expect(
        store.find('example.com', 22),
        isNull,
        reason: 'declining must not pin the key anyway',
      );
    });

    test(
      'is trusted on first use when the user accepts, and remembered',
      () async {
        final verifier = build(onUnknown: (_) => true);

        expect(await verifier.verify('ssh-ed25519', fp(kFingerprint)), isTrue);

        final stored = store.find('example.com', 22);
        expect(stored, isNotNull);
        expect(stored!.fingerprint, kFingerprint);
        expect(stored.keyType, 'ssh-ed25519');
        expect(stored.trustedAt, DateTime.utc(2026, 1, 1));
      },
    );

    test(
      'describes itself with the fingerprint the user must compare',
      () async {
        HostKeyPresentation? seen;
        final verifier = build(
          onUnknown: (p) {
            seen = p;
            return false;
          },
        );
        await verifier.verify('ssh-ed25519', fp(kFingerprint));

        expect(seen!.verdict, HostKeyVerdict.unknown);
        expect(seen!.describe(), contains(kFingerprint));
        expect(seen!.describe(), contains('example.com:22'));
      },
    );
  });

  group('a changed key', () {
    test('is refused without ever asking the user', () async {
      // The whole point. A "Trust anyway" button here would make every other
      // guarantee in this file decorative.
      await trustExisting();
      var prompted = false;
      final verifier = build(
        onUnknown: (_) {
          prompted = true;
          return true;
        },
      );

      expect(
        await verifier.verify('ssh-ed25519', fp(kOtherFingerprint)),
        isFalse,
      );
      expect(
        prompted,
        isFalse,
        reason: 'a changed key must never reach the trust prompt',
      );
    });

    test('does not overwrite the pinned key', () async {
      await trustExisting();
      final verifier = build(onUnknown: (_) => true);

      await verifier.verify('ssh-ed25519', fp(kOtherFingerprint));

      expect(store.find('example.com', 22)!.fingerprint, kFingerprint);
    });

    test('is reported so the failure can be explained precisely', () async {
      await trustExisting();
      final verifier = build();

      await verifier.verify('ssh-ed25519', fp(kOtherFingerprint));

      final presentation = verifier.lastPresentation!;
      expect(presentation.verdict, HostKeyVerdict.changed);
      expect(presentation.describe(), contains('IDENTIFICATION HAS CHANGED'));
      expect(presentation.describe(), contains(kFingerprint));
      expect(presentation.describe(), contains(kOtherFingerprint));
    });

    test(
      'counts a same-fingerprint key of a different type as changed',
      () async {
        // A server that swapped ssh-rsa for ssh-ed25519 under the same address
        // is still a different identity, and pinning must notice.
        await trustExisting(keyType: 'ssh-rsa');
        final verifier = build();

        expect(await verifier.verify('ssh-ed25519', fp(kFingerprint)), isFalse);
        expect(verifier.lastPresentation!.verdict, HostKeyVerdict.changed);
      },
    );

    test('can be resolved only by forgetting the pin deliberately', () async {
      await trustExisting();
      final verifier = build(onUnknown: (_) => true);

      expect(
        await verifier.verify('ssh-ed25519', fp(kOtherFingerprint)),
        isFalse,
      );

      await store.forget('example.com', 22);

      expect(
        await verifier.verify('ssh-ed25519', fp(kOtherFingerprint)),
        isTrue,
        reason: 'once the user removes the pin, the host is unknown again',
      );
    });
  });

  group('addressing', () {
    test('pins are per port, not per hostname', () async {
      // Two SSH servers on one machine are two identities.
      await trustExisting(port: 22);
      final other = build(port: 2222);

      expect(await other.verify('ssh-ed25519', fp(kFingerprint)), isFalse);
      expect(other.lastPresentation!.verdict, HostKeyVerdict.unknown);
    });
  });

  group('robustness', () {
    test('a malformed fingerprint refuses rather than throwing', () async {
      // The server controls these bytes. Throwing out of a handshake callback
      // would surface as an unhandled error rather than a refused connection.
      await trustExisting();
      final verifier = build();
      final malformed = Uint8List.fromList([0xC3, 0x28, 0xFF]);

      late bool result;
      expect(
        () async => result = await verifier.verify('ssh-ed25519', malformed),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
      expect(result, isFalse);
    });
  });
}
