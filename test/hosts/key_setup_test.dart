import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/ssh/ssh_credentials.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/features/hosts/data/key_setup_service.dart';
import 'package:sshetu/features/hosts/domain/key_setup.dart';

/// Swapping a password login for a key, and the ways it can go wrong.
///
/// The dangerous outcome is not "it did not work" — it is "it said it worked,
/// deleted the password, and the key does not authenticate". Most of what is
/// below is about making that outcome impossible.
void main() {
  const key =
      'ssh-ed25519 '
      'AAAAC3NzaC1lZDI1NTE5AAAAIH1234567890abcdefghijklmnopqrstuvwxyzAB '
      'dlohani@laptop';

  const privateKey = SshPrivateKey(
    identityId: 'k1',
    label: 'laptop',
    pem: 'PRIVATE',
  );

  const target = SshTarget(
    hostname: '10.0.0.1',
    username: 'root',
    authMethod: SshAuthMethod.password,
    credentialId: 'h1',
  );

  /// Records every script run, and answers however the test says.
  late List<String> ran;
  late List<String> stdins;
  late InMemorySecretVault vault;

  setUp(() {
    ran = [];
    stdins = [];
    vault = InMemorySecretVault();
  });

  RunRemote runner({
    String output = KeySetupScripts.addedMarker,
    int code = 0,
  }) {
    return (script, stdin) async {
      ran.add(script);
      stdins.add(stdin);
      if (script == KeySetupScripts.install) {
        return (output: output, exitCode: code);
      }
      return (output: 'SSHETU:ok', exitCode: 0);
    };
  }

  KeySetupService service({RunRemote? run, VerifyConnection? verify}) =>
      KeySetupService(
        vault: vault,
        run: run ?? runner(),
        verify: verify ?? (_, _) async {},
      );

  Future<KeySetupResult> setUpKey(KeySetupService s) => s.run_(
    target: target,
    publicKey: key,
    privateKey: privateKey,
    hostId: 'h1',
  );

  group('when the key works', () {
    test('it installs, verifies, then forgets the password', () async {
      await vault.write(SecretRef.hostPassword('h1'), 'hunter2');

      final result = await setUpKey(service());

      expect(result.installed, KeyInstallOutcome.added);
      expect(result.verified, isTrue);
      expect(
        await vault.read(SecretRef.hostPassword('h1')),
        isNull,
        reason: 'the saved password should be gone',
      );
      expect(ran, [KeySetupScripts.install, KeySetupScripts.commit]);
    });

    test('the key travels on stdin, never in the command', () async {
      // A key on the command line is a key in the server's process list, and
      // a label with a quote in it is a shell injection.
      await setUpKey(service());

      expect(ran.first, isNot(contains('ssh-ed25519')));
      expect(stdins.first.trim(), key);
    });

    test('a key already there is not a failure', () async {
      final result = await setUpKey(
        service(run: runner(output: KeySetupScripts.presentMarker)),
      );

      expect(result.installed, KeyInstallOutcome.alreadyPresent);
      expect(result.verified, isTrue);
    });
  });

  group('when the key does not work', () {
    test('the password survives and the server is put back', () async {
      await vault.write(SecretRef.hostPassword('h1'), 'hunter2');

      await expectLater(
        setUpKey(
          service(verify: (_, _) async => throw Exception('auth failed')),
        ),
        throwsA(isA<KeySetupException>()),
      );

      expect(
        await vault.read(SecretRef.hostPassword('h1')),
        'hunter2',
        reason: 'deleting it here would lock the user out',
      );
      expect(ran, contains(KeySetupScripts.rollback));
      expect(ran, isNot(contains(KeySetupScripts.commit)));
    });

    test('a server that asks for a password says so', () async {
      // The failure this names is the subtle one: the server refused the key
      // and offered password auth instead. Reported differently because the
      // fix is different — usually a permissions or PubkeyAuthentication
      // problem on the server, not a wrong key.
      await expectLater(
        setUpKey(
          service(
            verify: (target, credentials) async {
              await credentials.password(target);
              throw Exception('no password supplied');
            },
          ),
        ),
        throwsA(
          isA<KeySetupException>().having(
            (e) => e.message,
            'message',
            contains('asked for a password'),
          ),
        ),
      );
    });

    test('a failed install never reaches verification', () async {
      var verified = false;

      await expectLater(
        setUpKey(
          service(
            run: runner(output: 'sh: /home is full', code: 1),
            verify: (_, _) async => verified = true,
          ),
        ),
        throwsA(isA<KeySetupException>()),
      );

      expect(verified, isFalse);
    });

    test('output with no marker is a failure, not a success', () async {
      // An exit code of zero from a shell that never ran the script is the
      // trap: without the marker this would read as "installed".
      await expectLater(
        setUpKey(service(run: runner(output: 'welcome to the server\n'))),
        throwsA(isA<KeySetupException>()),
      );
    });

    test('a rollback that also fails does not hide the real reason', () async {
      await expectLater(
        setUpKey(
          service(
            run: (script, stdin) async {
              ran.add(script);
              if (script == KeySetupScripts.rollback) {
                throw Exception('connection lost');
              }
              return (output: KeySetupScripts.addedMarker, exitCode: 0);
            },
            verify: (_, _) async => throw Exception('auth failed'),
          ),
        ),
        throwsA(
          isA<KeySetupException>().having(
            (e) => e.message,
            'message',
            contains('could not be used to log in'),
          ),
        ),
      );
    });
  });

  group('before anything is sent', () {
    test('a key that is not a key is refused', () async {
      for (final bad in [
        '',
        '   ',
        'ssh-ed25519',
        'not-a-key AAAA',
        'ssh-ed25519 short',
        'ssh-ed25519 AAAA;rm -rf /',
        'ssh-ed25519 AAAA\nssh-rsa BBBB',
      ]) {
        await expectLater(
          service().run_(
            target: target,
            publicKey: bad,
            privateKey: privateKey,
            hostId: 'h1',
          ),
          throwsA(isA<KeySetupException>()),
          reason: bad,
        );
      }

      expect(ran, isEmpty, reason: 'nothing should have been run');
    });

    test('a real key passes the check', () {
      expect(isPlausiblePublicKey(key), isTrue);
    });
  });

  test('verification is offered the key and refused a password', () async {
    late SshCredentialSource offered;
    late SshTarget verifiedTarget;

    await setUpKey(
      service(
        verify: (t, credentials) async {
          verifiedTarget = t;
          offered = credentials;
        },
      ),
    );

    expect(await offered.privateKeys(target), [privateKey]);
    expect(
      await offered.password(target),
      isNull,
      reason: 'a password here would let a broken key verify',
    );
    expect(verifiedTarget.authMethod, SshAuthMethod.publicKey);
    expect(verifiedTarget.identityId, 'k1');
  });

  test('a host with no saved password still installs and verifies', () async {
    final result = await service().run_(
      target: target,
      publicKey: key,
      privateKey: privateKey,
    );

    expect(result.verified, isTrue);
  });
}
