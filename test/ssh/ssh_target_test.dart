import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/ssh_algorithm_policy.dart';
import 'package:sshetu/core/ssh/ssh_connection_state.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';

void main() {
  group('SshTarget', () {
    test('a plain target is a chain of one', () {
      const target = SshTarget(hostname: 'db', username: 'root');
      expect(target.chain, [target]);
    });

    test('a chain dials outermost bastion first', () {
      // `db` behind `bastion` behind `edge` must dial edge, bastion, db —
      // dialling in the wrong order is a connection that cannot be made.
      const edge = SshTarget(hostname: 'edge', username: 'me');
      const bastion = SshTarget(
        hostname: 'bastion',
        username: 'me',
        jumpTarget: edge,
      );
      const db = SshTarget(
        hostname: 'db',
        username: 'root',
        jumpTarget: bastion,
      );

      expect(db.chain.map((t) => t.hostname).toList(), [
        'edge',
        'bastion',
        'db',
      ]);
    });

    test('address carries no secret', () {
      const target = SshTarget(
        hostname: 'db',
        username: 'root',
        port: 2222,
        identityId: 'key-1',
      );
      expect(target.address, 'root@db:2222');
      expect(target.toString(), isNot(contains('key-1')));
    });

    test('copyWith can clear a jump host explicitly', () {
      // Removing a bastion is a real edit; `null` alone cannot express it.
      const bastion = SshTarget(hostname: 'bastion', username: 'me');
      const db = SshTarget(
        hostname: 'db',
        username: 'root',
        jumpTarget: bastion,
      );

      expect(db.copyWith().jumpTarget, isNotNull);
      expect(db.copyWith(clearJumpTarget: true).jumpTarget, isNull);
    });

    test('defaults are the safe ones', () {
      const target = SshTarget(hostname: 'h', username: 'u');
      expect(target.port, 22);
      expect(target.authMethod, SshAuthMethod.publicKey);
      expect(
        target.allowLegacyAlgorithms,
        isFalse,
        reason: 'weakened algorithms must never be the default',
      );
    });
  });

  group('SshAlgorithmPolicy', () {
    // dartssh2 exports the concrete algorithm types but not their shared
    // SSHAlgorithm supertype, so `name` is read off each list directly.
    List<String> kex(SSHAlgorithms a) => [for (final e in a.kex) e.name];
    List<String> hostkey(SSHAlgorithms a) => [
      for (final e in a.hostkey) e.name,
    ];
    List<String> cipher(SSHAlgorithms a) => [for (final e in a.cipher) e.name];
    List<String> mac(SSHAlgorithms a) => [for (final e in a.mac) e.name];

    test('the modern set excludes everything dartssh2 4.0 dropped', () {
      final kexNames = kex(SshAlgorithmPolicy.modern);
      final hostkeyNames = hostkey(SshAlgorithmPolicy.modern);
      final cipherNames = cipher(SshAlgorithmPolicy.modern);

      expect(kexNames, isNot(contains('diffie-hellman-group14-sha1')));
      expect(kexNames, isNot(contains('diffie-hellman-group1-sha1')));
      expect(hostkeyNames, isNot(contains('ssh-rsa')));
      expect(cipherNames, isNot(contains('aes256-cbc')));
      expect(cipherNames, isNot(contains('aes128-cbc')));
    });

    test('the permissive set adds them back', () {
      final kexNames = kex(SshAlgorithmPolicy.permissive);
      final hostkeyNames = hostkey(SshAlgorithmPolicy.permissive);
      final cipherNames = cipher(SshAlgorithmPolicy.permissive);

      expect(kexNames, contains('diffie-hellman-group14-sha1'));
      expect(hostkeyNames, contains('ssh-rsa'));
      expect(cipherNames, contains('aes256-cbc'));
    });

    test('legacy entries never outrank modern ones', () {
      // The point of appending rather than prepending: turning the escape
      // hatch on for one appliance must not downgrade a modern server.
      final cipherNames = cipher(SshAlgorithmPolicy.permissive);
      final kexNames = kex(SshAlgorithmPolicy.permissive);
      final hostkeyNames = hostkey(SshAlgorithmPolicy.permissive);

      expect(
        cipherNames.indexOf('aes256-gcm@openssh.com'),
        lessThan(cipherNames.indexOf('aes256-cbc')),
      );
      expect(
        kexNames.indexOf('curve25519-sha256'),
        lessThan(kexNames.indexOf('diffie-hellman-group14-sha1')),
      );
      expect(
        hostkeyNames.indexOf('ssh-ed25519'),
        lessThan(hostkeyNames.indexOf('ssh-rsa')),
      );
    });

    test('the permissive set is a superset of the modern one', () {
      // A host that opts in must not lose the ability to negotiate anything
      // it could negotiate before.
      for (final n in cipher(SshAlgorithmPolicy.modern)) {
        expect(cipher(SshAlgorithmPolicy.permissive), contains(n));
      }
      for (final n in kex(SshAlgorithmPolicy.modern)) {
        expect(kex(SshAlgorithmPolicy.permissive), contains(n));
      }
      for (final n in hostkey(SshAlgorithmPolicy.modern)) {
        expect(hostkey(SshAlgorithmPolicy.permissive), contains(n));
      }
      for (final n in mac(SshAlgorithmPolicy.modern)) {
        expect(mac(SshAlgorithmPolicy.permissive), contains(n));
      }
    });

    test('forHost picks by the per-host opt-in', () {
      expect(
        hostkey(SshAlgorithmPolicy.forHost(allowLegacy: false)),
        isNot(contains('ssh-rsa')),
      );
      expect(
        hostkey(SshAlgorithmPolicy.forHost(allowLegacy: true)),
        contains('ssh-rsa'),
      );
    });
  });

  group('reconnectBackoff', () {
    test('starts quickly — a radio hop usually recovers in seconds', () {
      expect(reconnectBackoff(0), const Duration(milliseconds: 500));
      expect(reconnectBackoff(1), const Duration(seconds: 1));
    });

    test('grows, then stops at a ceiling', () {
      expect(reconnectBackoff(2), const Duration(seconds: 2));
      expect(reconnectBackoff(6), const Duration(seconds: 30));
      expect(
        reconnectBackoff(50),
        const Duration(seconds: 30),
        reason: 'a host that is down must not push the wait to infinity',
      );
    });

    test('never returns a negative or zero delay', () {
      for (var i = 0; i < 20; i++) {
        expect(reconnectBackoff(i), greaterThan(Duration.zero));
      }
    });
  });
}
