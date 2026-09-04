import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/transfer/domain/pairing_code.dart';
import 'package:sshetu/features/transfer/domain/transfer_payload.dart';
import 'package:sshetu/features/transfer/transfer_session.dart';

import '../support/test_database.dart';

/// A whole transfer, over real sockets, between two real databases.
///
/// Not mocked. The failures this feature can have — a frame split across
/// packets, a handshake that deadlocks, a listener that outlives its dialog —
/// only exist once there is a socket, and a test with a fake transport would
/// pass while every one of them was present.
void main() {
  late AppDatabase sender;
  late AppDatabase receiver;
  late InMemorySecretVault senderVault;
  late InMemorySecretVault receiverVault;

  setUp(() async {
    sender = await openTestDatabase();
    receiver = await openTestDatabase();
    senderVault = InMemorySecretVault();
    receiverVault = InMemorySecretVault();
  });

  tearDown(() async {
    await sender.raw.close();
    await receiver.raw.close();
  });

  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> seed({int hosts = 1}) async {
    await sender.raw.insert('identities', {
      'id': 'k1',
      'label': 'laptop',
      'key_type': 'ssh-ed25519',
      'has_passphrase': 0,
      'origin': 'generated',
      'created_at': now,
      'updated_at': now,
    });
    for (var i = 0; i < hosts; i++) {
      await sender.raw.insert('hosts', {
        'id': 'h$i',
        'label': 'server-$i',
        'hostname': '10.0.0.$i',
        'port': 22,
        'username': 'root',
        'auth_method': 'publicKey',
        'identity_id': 'k1',
        'allow_legacy_algorithms': 0,
        'keepalive_seconds': 30,
        'created_at': now,
        'updated_at': now,
      });
    }
    await senderVault.write(SecretRef.identityPrivateKey('k1'), 'PRIVATE-KEY');
  }

  /// A sender bound to loopback, which is the only address a test can rely on.
  Future<TransferSender> startSender({bool includeSecrets = true}) async {
    final payload = await TransferPayload.read(
      sender.raw,
      includeSecrets: includeSecrets,
    );
    return TransferSender.start(
      payload: payload,
      vault: senderVault,
      deviceName: "dlohani's MacBook",
      addresses: ['127.0.0.1'],
    );
  }

  test('a configuration crosses two sockets and lands', () async {
    await seed(hosts: 3);
    final sending = await startSender();
    final handed = sending.handOver();

    final client = await TransferReceiver.connect(
      sending.code,
      deviceName: 'iPhone',
    );

    expect(client.offer.deviceName, "dlohani's MacBook");
    expect(client.offer.hosts, 3);
    expect(client.offer.identities, 1);
    expect(client.offer.includesSecrets, isTrue);

    final payload = await client.accept();
    await payload.apply(receiver.raw, vault: receiverVault);

    expect(await handed, 'iPhone');
    expect(await receiver.raw.query('hosts'), hasLength(3));
    expect(
      await receiverVault.read(SecretRef.identityPrivateKey('k1')),
      'PRIVATE-KEY',
    );
  });

  test('the offer says whether keys are included', () async {
    await seed();
    final sending = await startSender(includeSecrets: false);
    unawaited(sending.handOver().catchError((_) => ''));

    final client = await TransferReceiver.connect(
      sending.code,
      deviceName: 'iPhone',
    );

    expect(client.offer.includesSecrets, isFalse);
    await client.close();
    await sending.close();
  });

  test('scanning is not accepting', () async {
    // A QR code on a poster must not be able to write to someone's app. The
    // connection stops at the offer until a person taps.
    await seed();
    final sending = await startSender();
    unawaited(sending.handOver().catchError((_) => ''));

    final client = await TransferReceiver.connect(
      sending.code,
      deviceName: 'iPhone',
    );
    await client.close();

    expect(await receiver.raw.query('hosts'), isEmpty);
    await sending.close();
  });

  test('a device without the secret gets nothing', () async {
    await seed();
    final sending = await startSender();
    unawaited(sending.handOver().catchError((_) => ''));

    // Same address and port, a secret it made up: someone on the same network
    // who never saw the screen.
    final forged = PairingCode.generate(
      addresses: sending.code.addresses,
      port: sending.code.port,
      deviceName: 'impostor',
    );

    await expectLater(
      TransferReceiver.connect(forged, deviceName: 'attacker'),
      throwsA(isA<TransferException>()),
    );
    await sending.close();
  });

  test('the code is single-use', () async {
    // The listener closes behind the first device through it, so a code
    // photographed off the screen is worthless a moment later.
    await seed();
    final sending = await startSender();
    final handed = sending.handOver();

    final first = await TransferReceiver.connect(
      sending.code,
      deviceName: 'iPhone',
    );
    await (await first.accept()).apply(receiver.raw, vault: receiverVault);
    await handed;

    await expectLater(
      TransferReceiver.connect(sending.code, deviceName: 'second phone'),
      throwsA(isA<TransferException>()),
    );
  });

  test('the listener is gone once the sender closes', () async {
    // The dialog closing has to take the port with it. A listener that
    // outlives its sheet is a service nobody knows is running.
    await seed();
    final sending = await startSender();
    unawaited(sending.handOver().catchError((_) => ''));
    await sending.close();

    await expectLater(
      TransferReceiver.connect(sending.code, deviceName: 'iPhone'),
      throwsA(isA<TransferException>()),
    );
  });

  test('a large configuration survives being split across packets', () async {
    // Two hundred hosts is comfortably more than one TCP segment, which is
    // the case a loopback test with three rows never exercises.
    await seed(hosts: 200);
    final sending = await startSender();
    final handed = sending.handOver();

    final client = await TransferReceiver.connect(
      sending.code,
      deviceName: 'iPhone',
    );
    await (await client.accept()).apply(receiver.raw, vault: receiverVault);
    await handed;

    expect(await receiver.raw.query('hosts'), hasLength(200));
  });

  test('permission that never comes is a message, not a hang', () async {
    await seed();

    await expectLater(
      TransferSender.start(
        payload: await TransferPayload.read(sender.raw, includeSecrets: false),
        vault: senderVault,
        deviceName: 'laptop',
        clearToListen: () async =>
            throw const TransferException('Firewall said no.'),
      ),
      throwsA(
        isA<TransferException>().having(
          (e) => e.message,
          'message',
          'Firewall said no.',
        ),
      ),
    );
  });

  test('asking to listen leaves this isolate free to keep working', () async {
    // The whole point of the pre-clearance: whatever the OS does with the
    // first listen, it does not happen on the thread that draws frames. A
    // stalled event loop here is a frozen window there.
    final ticks = <int>[];
    final clock = Stopwatch()..start();
    final timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => ticks.add(clock.elapsedMilliseconds),
    );

    await askToListen();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    timer.cancel();

    expect(ticks, isNotEmpty);
    var worst = 0;
    for (var i = 1; i < ticks.length; i++) {
      worst = worst > ticks[i] - ticks[i - 1] ? worst : ticks[i] - ticks[i - 1];
    }
    expect(worst, lessThan(500), reason: 'the event loop stalled');
  });

  test('nobody scanning in time is a message, not a hang', () async {
    await seed();
    final sending = await startSender();

    await expectLater(
      sending.handOver(timeout: const Duration(milliseconds: 200)),
      throwsA(
        isA<TransferException>().having(
          (e) => e.message,
          'message',
          contains('in time'),
        ),
      ),
    );
  });

  test(
    'a peer speaking nonsense is dropped, and the code still works',
    () async {
      await seed();
      final sending = await startSender();
      final handed = sending.handOver();

      // A port scanner, or something else entirely.
      final rude = await Socket.connect('127.0.0.1', sending.code.port);
      rude.add(Uint8List.fromList([0, 0, 0, 4, 1, 2, 3, 4]));
      await rude.flush();
      rude.destroy();

      // The real device still gets through.
      final client = await TransferReceiver.connect(
        sending.code,
        deviceName: 'iPhone',
      );
      await (await client.accept()).apply(receiver.raw, vault: receiverVault);

      expect(await handed, 'iPhone');
      expect(await receiver.raw.query('hosts'), hasLength(1));
    },
  );
}

void unawaited(Future<void> future) {}
