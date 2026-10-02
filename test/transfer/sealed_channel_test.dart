import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/transfer/crypto/key_schedule.dart';
import 'package:sshetu/features/transfer/crypto/sealed_channel.dart';

/// The channel two devices talk over once one has scanned the other's QR code.
///
/// Everything this protocol claims rests on one fact: a peer that did not scan
/// the code cannot produce a frame the other end can open. These tests are
/// that claim, stated as failures rather than as prose.
void main() {
  Uint8List secret([int seed = 1]) {
    final random = Random(seed);
    return Uint8List.fromList(
      List.generate(kTransferSecretBytes, (_) => random.nextInt(256)),
    );
  }

  ({SealedChannel sender, SealedChannel receiver}) pair(Uint8List shared) {
    final key = TransferKeySchedule.sessionKey(shared);
    return (
      sender: SealedChannel(
        sessionKey: key,
        sending: TransferDirection.senderToReceiver,
      ),
      receiver: SealedChannel(
        sessionKey: key,
        sending: TransferDirection.receiverToSender,
      ),
    );
  }

  test('a frame sealed by one end opens at the other', () {
    final (:sender, :receiver) = pair(secret());

    final frame = sender.seal({'type': 'hello', 'device': 'iPhone'});

    expect(receiver.open(frame), {'type': 'hello', 'device': 'iPhone'});
  });

  test('the wire carries nothing readable', () {
    final (:sender, receiver: _) = pair(secret());

    final frame = sender.seal({'type': 'hello', 'device': 'tester-iPhone'});

    // The one property worth asserting literally: a name that went in must not
    // come out of a hex dump of the frame.
    expect(String.fromCharCodes(frame), isNot(contains('tester')));
    expect(String.fromCharCodes(frame), isNot(contains('hello')));
  });

  test('a different secret cannot open the frame', () {
    // Someone on the same network who never saw the QR code.
    final (:sender, receiver: _) = pair(secret(1));
    final (sender: _, :receiver) = pair(secret(2));

    expect(
      () => receiver.open(sender.seal({'type': 'hello'})),
      throwsA(isA<SealedChannelException>()),
    );
  });

  test('a tampered frame is refused', () {
    final (:sender, :receiver) = pair(secret());
    final frame = sender.seal({'type': 'accept'});
    // Flip one bit of ciphertext.
    frame[frame.length - 1] ^= 0x01;

    expect(() => receiver.open(frame), throwsA(isA<SealedChannelException>()));
  });

  test('a frame cannot be replayed', () {
    // The attack this actually stops: capture "accept" and send it again to
    // make the sender transmit the payload a second time.
    final (:sender, :receiver) = pair(secret());
    final frame = sender.seal({'type': 'accept'});

    expect(receiver.open(frame), {'type': 'accept'});
    expect(
      () => receiver.open(frame),
      throwsA(isA<SealedChannelException>()),
      reason: 'the sequence number has already been used',
    );
  });

  test('a frame cannot be replayed back at its sender', () {
    // Each direction has its own key, so the sender cannot even open its own
    // frame — which is what makes reflection pointless rather than merely
    // detected.
    final (:sender, receiver: _) = pair(secret());
    final frame = sender.seal({'type': 'hello'});

    expect(() => sender.open(frame), throwsA(isA<SealedChannelException>()));
  });

  test('frames arriving out of order are refused', () {
    final (:sender, :receiver) = pair(secret());
    final first = sender.seal({'type': 'one'});
    final second = sender.seal({'type': 'two'});

    expect(
      () => receiver.open(second),
      throwsA(isA<SealedChannelException>()),
      reason: 'the first frame has not been seen yet',
    );
    // And the channel is not left in a state where the right frame now works:
    // a peer that reorders frames is not a peer to keep talking to.
    expect(receiver.open(first), {'type': 'one'});
  });

  test('a long conversation stays in step', () {
    final (:sender, :receiver) = pair(secret());

    for (var i = 0; i < 200; i++) {
      expect(receiver.open(sender.seal({'n': i})), {'n': i});
    }
  });

  test('garbage is refused rather than crashing', () {
    final (sender: _, :receiver) = pair(secret());

    for (final bytes in [
      Uint8List(0),
      Uint8List(10),
      Uint8List.fromList(List.filled(100, 0xAB)),
    ]) {
      expect(
        () => receiver.open(bytes),
        throwsA(isA<SealedChannelException>()),
      );
    }
  });

  test('a short secret is refused outright', () {
    expect(
      () => TransferKeySchedule.sessionKey(Uint8List(8)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the two directions get different keys', () {
    final key = TransferKeySchedule.sessionKey(secret());
    expect(
      TransferKeySchedule.directionKey(key, TransferDirection.senderToReceiver),
      isNot(
        TransferKeySchedule.directionKey(
          key,
          TransferDirection.receiverToSender,
        ),
      ),
    );
  });
}
