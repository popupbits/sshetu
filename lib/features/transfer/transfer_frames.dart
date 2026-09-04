import 'dart:typed_data';

/// The largest frame this protocol will assemble.
///
/// A length prefix arrives from a peer that has not yet proved anything — the
/// bytes are read before they can be opened — so an unbounded length is an
/// invitation to allocate a gigabyte on someone else's say-so. Sixteen
/// megabytes is far more than a configuration of hosts and keys will ever be.
const int kMaxFrameBytes = 16 * 1024 * 1024;

/// A peer that is not speaking this protocol.
class FramingException implements Exception {
  const FramingException(this.message);

  final String message;

  @override
  String toString() => 'FramingException: $message';
}

/// Prefixes [frame] with its length, big-endian.
Uint8List encodeFrame(Uint8List frame) {
  final out = Uint8List(4 + frame.length);
  ByteData.view(out.buffer).setUint32(0, frame.length);
  out.setRange(4, out.length, frame);
  return out;
}

/// Reassembles length-prefixed frames from a byte stream.
///
/// TCP has no message boundaries: a frame arrives in three pieces, or three
/// frames arrive in one. Every socket protocol needs this and every one that
/// skips it works perfectly on loopback and fails on a real network.
Stream<Uint8List> decodeFrames(Stream<List<int>> bytes) async* {
  final buffer = BytesBuilder();

  await for (final chunk in bytes) {
    buffer.add(chunk);

    // A chunk can complete several frames at once, or none.
    while (true) {
      final pending = buffer.toBytes();
      if (pending.length < 4) break;

      final length = ByteData.view(pending.buffer).getUint32(0);
      if (length > kMaxFrameBytes) {
        throw const FramingException('frame is implausibly large');
      }
      if (pending.length < 4 + length) break;

      yield Uint8List.sublistView(pending, 4, 4 + length);
      buffer
        ..clear()
        ..add(Uint8List.sublistView(pending, 4 + length));
    }
  }
}
