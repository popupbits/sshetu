import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';

import 'crypto/key_schedule.dart';
import 'crypto/sealed_channel.dart';
import 'domain/pairing_code.dart';
import 'domain/transfer_payload.dart';
import 'transfer_frames.dart';

/// What the two ends say to each other, in order.
///
/// Deliberately tiny. Every message below is sealed, so an eavesdropper sees
/// only lengths; the reason to keep the protocol small is that every message
/// is a state the other end has to handle, and states are where protocols go
/// wrong.
abstract final class TransferMessage {
  /// Receiver → sender. Proves the receiver holds the secret.
  static const String hello = 'hello';

  /// Sender → receiver. What is on offer, so a person can confirm it.
  static const String offer = 'offer';

  /// Receiver → sender. The user said yes.
  static const String accept = 'accept';

  /// Sender → receiver. The configuration itself.
  static const String payload = 'payload';

  /// Receiver → sender. Applied, and safe to close.
  static const String done = 'done';
}

/// A transfer that did not complete, in words a dialog can show.
class TransferException implements Exception {
  const TransferException(this.message);

  final String message;

  @override
  String toString() => 'TransferException: $message';
}

/// What the receiving device is being offered, before it accepts.
class TransferOffer {
  const TransferOffer({
    required this.deviceName,
    required this.hosts,
    required this.identities,
    required this.tunnels,
    required this.knownHosts,
    required this.includesSecrets,
  });

  final String deviceName;
  final int hosts;
  final int identities;
  final int tunnels;
  final int knownHosts;

  /// Whether private keys and passwords are in this transfer. Shown to the
  /// user in as many words: it is the difference between copying a list of
  /// addresses and copying the keys to every one of them.
  final bool includesSecrets;
}

/// The sending half: shows a code, waits for one device, hands over once.
///
/// The listener exists only while this object does. There is no background
/// service, no persistent port and no discovery beacon — the app is reachable
/// exactly while a person is looking at the QR code, which is the smallest
/// window the feature can work in.
class TransferSender {
  TransferSender._(this._server, this.code, this._payload);

  /// Binds an ephemeral port on every interface and prepares a code for it.
  ///
  /// Port 0: the OS picks a free one. A fixed port would be a fingerprint —
  /// something a scanner could look for on a network to find machines running
  /// this app — and there is no reason to have one when the port travels in
  /// the code.
  static Future<TransferSender> start({
    required TransferPayload payload,
    required String deviceName,
    List<String>? addresses,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final found = addresses ?? await localAddresses();
    if (found.isEmpty) {
      await server.close();
      throw const TransferException(
        'This device is not on a network, so there is nowhere to send from. '
        'Join the same Wi-Fi as the other device and try again.',
      );
    }
    return TransferSender._(
      server,
      PairingCode.generate(
        addresses: found,
        port: server.port,
        deviceName: deviceName,
      ),
      payload,
    );
  }

  final ServerSocket _server;
  final TransferPayload _payload;

  /// The code to render as a QR. Contains the secret; never log or persist it.
  final PairingCode code;

  /// Every non-loopback IPv4 address this device has.
  static Future<List<String>> localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return [
      for (final interface in interfaces)
        for (final address in interface.addresses) address.address,
    ];
  }

  /// Completes when one device has taken the payload.
  ///
  /// The first connection to get through the sealed handshake wins and the
  /// listener closes behind it. A second device scanning the same code finds
  /// nothing, which is the point of the code being single-use.
  Future<String> handOver({Duration timeout = kTransferTtl}) async {
    final sessionKey = TransferKeySchedule.sessionKey(code.secret);

    try {
      await for (final socket in _server.timeout(
        timeout,
        onTimeout: (sink) => sink.addError(
          const TransferException('Nobody scanned the code in time.'),
        ),
      )) {
        try {
          return await _serve(socket, sessionKey);
        } on Object {
          // A connection that fails the handshake is not this device's peer —
          // a port scanner, or someone guessing. Drop it and keep waiting for
          // the one that scanned the code.
          socket.destroy();
        }
      }
      throw const TransferException('The transfer was cancelled.');
    } finally {
      await close();
    }
  }

  Future<String> _serve(Socket socket, Uint8List sessionKey) async {
    final channel = SealedChannel(
      sessionKey: sessionKey,
      sending: TransferDirection.senderToReceiver,
    );
    final frames = StreamQueue<Uint8List>(decodeFrames(socket));

    try {
      final hello = channel.open(await frames.next);
      if (hello['type'] != TransferMessage.hello) {
        throw const TransferException('The other device said something odd.');
      }
      final receiverName = hello['device'] as String? ?? 'that device';

      socket.add(
        encodeFrame(
          channel.seal({
            'type': TransferMessage.offer,
            'device': code.deviceName,
            'hosts': _payload.hostCount,
            'identities': _payload.identityCount,
            'tunnels': _payload.tunnelCount,
            'knownHosts': _payload.knownHostCount,
            'secrets': _payload.secrets.isNotEmpty,
          }),
        ),
      );
      await socket.flush();

      final answer = channel.open(await frames.next);
      if (answer['type'] != TransferMessage.accept) {
        throw const TransferException('The other device declined.');
      }

      socket.add(
        encodeFrame(
          channel.seal({
            'type': TransferMessage.payload,
            'payload': _payload.toJson(),
          }),
        ),
      );
      await socket.flush();

      final done = channel.open(await frames.next);
      if (done['type'] != TransferMessage.done) {
        throw const TransferException('The other device did not confirm.');
      }
      return receiverName;
    } finally {
      await frames.cancel(immediate: true);
      socket.destroy();
    }
  }

  /// Closes the listener. Safe to call twice.
  Future<void> close() async {
    try {
      await _server.close();
    } on Object {
      // Already closed.
    }
  }
}

/// The receiving half: scans a code, connects, shows what is offered, applies.
///
/// Split across two calls on purpose. [connect] gets as far as the offer and
/// stops; [accept] is what a person's tap triggers. A design where scanning
/// alone pulled the data would mean a QR code on a poster could write to
/// someone's app — the confirmation is not a formality, it is the boundary.
class TransferReceiver {
  TransferReceiver._(this._socket, this._channel, this._frames, this.offer);

  final Socket _socket;
  final SealedChannel _channel;
  final StreamQueue<Uint8List> _frames;

  /// What the sender is offering. Shown before anything is written.
  final TransferOffer offer;

  /// Dials the sender and reads its offer.
  ///
  /// Tries every address in the code, because only this device knows which of
  /// the sender's interfaces it can actually reach — a laptop on Wi-Fi and
  /// Ethernet advertises both, and one of them is often a network this phone
  /// is not on.
  static Future<TransferReceiver> connect(
    PairingCode code, {
    required String deviceName,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    Object? lastError;

    for (final address in code.addresses) {
      Socket? socket;
      try {
        socket = await Socket.connect(address, code.port, timeout: timeout);
        return await _handshake(socket, code, deviceName);
      } on Object catch (error) {
        lastError = error;
        socket?.destroy();
      }
    }

    throw TransferException(
      'Could not reach ${code.deviceName}. Check both devices are on the '
      'same network. (${lastError ?? 'no route'})',
    );
  }

  static Future<TransferReceiver> _handshake(
    Socket socket,
    PairingCode code,
    String deviceName,
  ) async {
    final channel = SealedChannel(
      sessionKey: TransferKeySchedule.sessionKey(code.secret),
      sending: TransferDirection.receiverToSender,
    );
    final frames = StreamQueue<Uint8List>(decodeFrames(socket));

    socket.add(
      encodeFrame(
        channel.seal({'type': TransferMessage.hello, 'device': deviceName}),
      ),
    );
    await socket.flush();

    final offered = channel.open(await frames.next);
    if (offered['type'] != TransferMessage.offer) {
      await frames.cancel(immediate: true);
      socket.destroy();
      throw const TransferException('That device is not offering a transfer.');
    }

    return TransferReceiver._(
      socket,
      channel,
      frames,
      TransferOffer(
        deviceName: offered['device'] as String? ?? code.deviceName,
        hosts: offered['hosts'] as int? ?? 0,
        identities: offered['identities'] as int? ?? 0,
        tunnels: offered['tunnels'] as int? ?? 0,
        knownHosts: offered['knownHosts'] as int? ?? 0,
        includesSecrets: offered['secrets'] as bool? ?? false,
      ),
    );
  }

  /// Takes the payload. Only ever called after the user has seen [offer].
  Future<TransferPayload> accept() async {
    try {
      _socket.add(encodeFrame(_channel.seal({'type': TransferMessage.accept})));
      await _socket.flush();

      final message = _channel.open(await _frames.next);
      if (message['type'] != TransferMessage.payload) {
        throw const TransferException('The other device sent nothing.');
      }
      final body = message['payload'];
      if (body is! Map<String, Object?>) {
        throw const TransferException('The transfer arrived malformed.');
      }

      final payload = TransferPayload.fromJson(body);

      // Told only after it is safely decoded — the sender closes on `done`,
      // so saying it early would end the connection before we knew whether
      // there was anything worth keeping.
      _socket.add(encodeFrame(_channel.seal({'type': TransferMessage.done})));
      await _socket.flush();

      return payload;
    } finally {
      await close();
    }
  }

  /// Hangs up without taking anything.
  Future<void> close() async {
    await _frames.cancel(immediate: true);
    _socket.destroy();
  }
}
