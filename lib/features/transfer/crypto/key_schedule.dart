import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Bytes of pairing secret behind the QR code.
///
/// 32, not a short typed code. The secret is read by a camera, so there is no
/// reason to shorten it to something a person could retype — and a short code
/// would need SPAKE2 or similar to be safe, which is real complexity bought
/// for a convenience nobody asked for.
const int kTransferSecretBytes = 32;

/// How long a shown QR code stays redeemable.
const Duration kTransferTtl = Duration(minutes: 5);

/// Salt separating this protocol's key material from any other use of the
/// same bytes. Fixed and public — that is what a salt is for here.
final Uint8List kTransferSalt = Uint8List.fromList(
  utf8.encode('sshetu/transfer/v1'),
);

/// Which way a frame travels.
///
/// Each direction gets its own key derived under its own label, so a frame
/// captured in one direction cannot be replayed back at its sender: the other
/// end simply cannot open it.
enum TransferDirection {
  senderToReceiver('dir:sender->receiver'),
  receiverToSender('dir:receiver->sender');

  const TransferDirection(this.label);

  final String label;

  TransferDirection get reversed => this == senderToReceiver
      ? TransferDirection.receiverToSender
      : TransferDirection.senderToReceiver;
}

/// Turns one pairing secret into the two directional keys a session needs.
///
/// HKDF-SHA256 throughout, with the same salt and a distinct `info` label per
/// output, so no two derived keys can collide. Nothing here touches the
/// network: the secret arrives from the QR code and the keys never leave.
abstract final class TransferKeySchedule {
  static const int keyBytes = 32;

  /// The session key both ends derive from the shared secret.
  static Uint8List sessionKey(Uint8List secret) {
    if (secret.length < kTransferSecretBytes) {
      throw ArgumentError.value(
        secret.length,
        'secret',
        'must be at least $kTransferSecretBytes bytes',
      );
    }
    return _hkdf(secret, 'session', keyBytes);
  }

  /// The key sealing frames travelling in [direction].
  static Uint8List directionKey(
    Uint8List sessionKey,
    TransferDirection direction,
  ) => _hkdf(sessionKey, direction.label, keyBytes);

  /// HKDF-SHA256 (RFC 5869): extract with the fixed salt, then expand under
  /// [info]. Only ever asked for one block, which is why expand is a single
  /// round rather than a loop.
  static Uint8List _hkdf(Uint8List input, String info, int length) {
    assert(length <= 32, 'one SHA-256 block only');
    final prk = Hmac(sha256, kTransferSalt).convert(input).bytes;
    final expanded = Hmac(
      sha256,
      prk,
    ).convert([...utf8.encode(info), 0x01]).bytes;
    return Uint8List.fromList(expanded.sublist(0, length));
  }
}
