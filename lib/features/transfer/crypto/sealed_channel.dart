import 'dart:convert';
import 'dart:typed_data';

import 'package:pinenacl/x25519.dart' show EncryptedMessage, SecretBox;

import 'key_schedule.dart';

/// A frame that could not be opened, or arrived out of order.
///
/// One exception for both, deliberately: to anything outside this class they
/// are the same event — the peer is not who it claims to be, or someone is
/// replaying frames — and the caller's only correct response to either is to
/// drop the connection.
class SealedChannelException implements Exception {
  const SealedChannelException(this.message);

  final String message;

  @override
  String toString() => 'SealedChannelException: $message';
}

/// One end of an authenticated, encrypted conversation.
///
/// Both ends derive their keys from the QR code's secret and nothing else.
/// Opening a frame *is* the authentication: if the peer did not scan the code,
/// it cannot produce a frame this end can open, and there is no handshake to
/// subvert because there is no negotiation.
///
/// Sequence numbers travel inside the sealed plaintext, not beside it, so they
/// cannot be edited by anyone who cannot already forge a frame. Each direction
/// counts separately and a frame arriving with the wrong number is refused —
/// which is what stops a captured frame being replayed later in the same
/// session.
class SealedChannel {
  SealedChannel({required Uint8List sessionKey, required this.sending})
    : _sendBox = SecretBox(
        TransferKeySchedule.directionKey(sessionKey, sending),
      ),
      _receiveBox = SecretBox(
        TransferKeySchedule.directionKey(sessionKey, sending.reversed),
      );

  /// The direction this end *writes*. It reads the other.
  final TransferDirection sending;

  final SecretBox _sendBox;
  final SecretBox _receiveBox;

  var _sendSeq = 0;
  var _receiveSeq = 0;

  /// Seals [message] as the next frame in this direction.
  Uint8List seal(Map<String, Object?> message) {
    final framed = <String, Object?>{...message, 'seq': _sendSeq++};
    // A fresh random 24-byte nonce per frame, which pinenacl draws from
    // Random.secure(). At that width, random is safe — there is no counter to
    // get wrong across a reconnect.
    final sealed = _sendBox.encrypt(
      Uint8List.fromList(utf8.encode(jsonEncode(framed))),
    );
    // nonce ‖ ciphertext, which is exactly what EncryptedMessage already is.
    return Uint8List.fromList(sealed);
  }

  /// Opens [frame], or throws.
  Map<String, Object?> open(Uint8List frame) {
    if (frame.length < 24 + 16) {
      throw const SealedChannelException('frame too short to be a frame');
    }

    final Uint8List plain;
    try {
      plain = _receiveBox.decrypt(EncryptedMessage.fromList(frame));
    } on Object {
      // Never say which part failed. To a caller it is one fact: this frame
      // did not come from someone holding the secret.
      throw const SealedChannelException('frame could not be opened');
    }

    final decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map<String, Object?>) {
      throw const SealedChannelException('frame was not an object');
    }

    final seq = decoded['seq'];
    if (seq is! int || seq != _receiveSeq) {
      throw const SealedChannelException('frame arrived out of order');
    }
    _receiveSeq++;

    return decoded..remove('seq');
  }
}
