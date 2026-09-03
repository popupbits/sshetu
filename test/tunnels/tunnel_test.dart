import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/features/tunnels/domain/tunnel.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  Tunnel local({
    String listenHost = Tunnel.defaultListenHost,
    int listenPort = 5432,
    String? targetHost = 'db.internal',
    int? targetPort = 5432,
  }) => Tunnel(
    id: 't1',
    hostId: 'h1',
    label: 'db',
    kind: TunnelKind.local,
    listenHost: listenHost,
    listenPort: listenPort,
    targetHost: targetHost,
    targetPort: targetPort,
    createdAt: now,
    updatedAt: now,
  );

  group('mapping', () {
    test('a local or remote forward shows listen and target', () {
      expect(local().mapping, '127.0.0.1:5432 → db.internal:5432');
    });

    test('a SOCKS forward shows only the listen side', () {
      // A dynamic forward has no fixed target, so a mapping that printed
      // "null:null" here would be the classic sign a field went unchecked.
      final tunnel = local().copyWith(
        kind: TunnelKind.socks,
        clearTargetHost: true,
        clearTargetPort: true,
      );
      expect(tunnel.mapping, '127.0.0.1:5432');
    });
  });

  group('isListenLoopback', () {
    for (final host in ['127.0.0.1', 'localhost', '::1']) {
      test('$host is loopback', () {
        expect(local(listenHost: host).isListenLoopback, isTrue);
      });
    }

    for (final host in ['0.0.0.0', '192.168.1.5', '::']) {
      test('$host is not loopback', () {
        // These are exactly the values the editor has to warn about — binding
        // any of them puts the forward on the whole network.
        expect(local(listenHost: host).isListenLoopback, isFalse);
      });
    }
  });

  group('isValidPort', () {
    test('1 and 65535 are the boundaries, both valid', () {
      expect(Tunnel.isValidPort(1), isTrue);
      expect(Tunnel.isValidPort(65535), isTrue);
    });

    test('0 is rejected even though the OS treats it as "assign one"', () {
      // A forward the user cannot see the port of is not one they can point a
      // client at, so this is deliberate, not an off-by-one.
      expect(Tunnel.isValidPort(0), isFalse);
    });

    test('65536 and negative numbers are rejected', () {
      expect(Tunnel.isValidPort(65536), isFalse);
      expect(Tunnel.isValidPort(-1), isFalse);
    });

    test('null is rejected', () {
      expect(Tunnel.isValidPort(null), isFalse);
    });
  });

  group('TunnelKind storage round trip', () {
    test('local and remote persist as their own name', () {
      expect(TunnelKind.local.storageValue, 'local');
      expect(TunnelKind.remote.storageValue, 'remote');
      expect(TunnelKind.fromStorage('local'), TunnelKind.local);
      expect(TunnelKind.fromStorage('remote'), TunnelKind.remote);
    });

    test('the socks enum value persists as "dynamic", the schema\'s word', () {
      // `dynamic` is a reserved word and cannot be an enum member, so this is
      // the one place the mismatch between Dart's vocabulary and the
      // database's has to be bridged — worth its own guard.
      expect(TunnelKind.socks.storageValue, 'dynamic');
      expect(TunnelKind.fromStorage('dynamic'), TunnelKind.socks);
    });

    test('an unrecognised stored value falls back to local, not a crash', () {
      // The safe reading for a value written by a newer app version: local is
      // the only kind that cannot reach further into the network than the
      // user already configured.
      expect(TunnelKind.fromStorage('teleport'), TunnelKind.local);
    });

    test('only socks skips requiresTarget', () {
      expect(TunnelKind.local.requiresTarget, isTrue);
      expect(TunnelKind.remote.requiresTarget, isTrue);
      expect(TunnelKind.socks.requiresTarget, isFalse);
    });
  });

  group('copyWith', () {
    test('clearTargetHost and clearTargetPort actually null the fields', () {
      // The classic bug this guards against: copyWith treating "no new value
      // passed" as "keep the old one" even when the caller explicitly asked
      // to clear it, because passing null looks the same as passing nothing.
      final cleared = local().copyWith(
        clearTargetHost: true,
        clearTargetPort: true,
      );
      expect(cleared.targetHost, isNull);
      expect(cleared.targetPort, isNull);
    });

    test('omitting a field keeps the existing value', () {
      final tunnel = local();
      final renamed = tunnel.copyWith(label: 'renamed');
      expect(renamed.label, 'renamed');
      expect(renamed.targetHost, tunnel.targetHost);
      expect(renamed.listenPort, tunnel.listenPort);
    });
  });
}
