import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/transfer/crypto/key_schedule.dart';
import 'package:sshetu/features/transfer/domain/pairing_code.dart';

/// The QR code, which is the credential.
///
/// Anything a camera might hand this parser is attacker-controlled — a code
/// printed by someone else, a QR found on a wall — so the tests are mostly
/// about what it *refuses*.
void main() {
  PairingCode sample() => PairingCode.generate(
    addresses: ['192.168.1.5', '10.0.0.2'],
    port: 53101,
    deviceName: "dlohani's MacBook",
    random: Random(7),
  );

  test('a code survives the round trip', () {
    final original = sample();
    final decoded = PairingCode.decode(original.encode());

    expect(decoded.addresses, original.addresses);
    expect(decoded.port, original.port);
    expect(decoded.secret, original.secret);
    expect(decoded.deviceName, original.deviceName);
  });

  test('every address survives, because only the phone knows which works', () {
    // A laptop has Wi-Fi, Ethernet and often a VPN interface. Guessing on the
    // sender's side gets it wrong exactly when someone is on a network they
    // did not set up.
    final decoded = PairingCode.decode(sample().encode());
    expect(decoded.addresses, hasLength(2));
  });

  test('a name with spaces and an apostrophe survives', () {
    expect(
      PairingCode.decode(sample().encode()).deviceName,
      "dlohani's MacBook",
    );
  });

  test('two generated codes never share a secret', () {
    final secrets = {
      for (var i = 0; i < 50; i++)
        String.fromCharCodes(
          PairingCode.generate(
            addresses: ['127.0.0.1'],
            port: 1,
            deviceName: 'x',
          ).secret,
        ),
    };
    expect(secrets, hasLength(50));
  });

  test('the secret is full width', () {
    expect(sample().secret, hasLength(kTransferSecretBytes));
  });

  group('refuses', () {
    void refuses(String label, String raw) {
      test(label, () {
        expect(
          () => PairingCode.decode(raw),
          throwsA(isA<PairingCodeException>()),
        );
      });
    }

    refuses('a QR code from something else entirely', 'https://example.com');
    refuses('a plain string', 'hello');
    refuses('the empty string', '');
    refuses(
      'our scheme with the wrong host',
      'sshetu://pair/v1?h=1&p=2&s=x&n=y',
    );
    refuses(
      'a future version, by name',
      'sshetu://transfer/v2?h=192.168.1.5&p=1&s=AAAA&n=x',
    );
    refuses(
      'a code with no address',
      'sshetu://transfer/v1?p=53101&s=AAAA&n=x',
    );
    refuses(
      'a code with no secret',
      'sshetu://transfer/v1?h=192.168.1.5&p=53101&n=x',
    );
    refuses(
      'a port outside the range',
      'sshetu://transfer/v1?h=192.168.1.5&p=99999&s=AAAA&n=x',
    );
    refuses(
      'a port that is not a number',
      'sshetu://transfer/v1?h=192.168.1.5&p=ssh&s=AAAA&n=x',
    );
    refuses(
      'a secret too short to be one',
      'sshetu://transfer/v1?h=192.168.1.5&p=53101&s=AAAA&n=x',
    );
  });

  test('the version refusal says which version it is', () {
    // A user with two builds needs to be told to update one of them, not that
    // "something went wrong".
    expect(
      () => PairingCode.decode(
        'sshetu://transfer/v9?h=192.168.1.5&p=1&s=AAAA&n=x',
      ),
      throwsA(
        isA<PairingCodeException>().having(
          (e) => e.message,
          'message',
          allOf(contains('version 9'), contains('version 1')),
        ),
      ),
    );
  });

  test('a code cannot be built with a short secret', () {
    expect(
      () => PairingCode(
        addresses: ['127.0.0.1'],
        port: 1,
        secret: Uint8List(8),
        deviceName: 'x',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
