import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../crypto/key_schedule.dart';

/// A QR code that could not be read as one of ours.
class PairingCodeException implements Exception {
  const PairingCodeException(this.message);

  final String message;

  @override
  String toString() => 'PairingCodeException: $message';
}

/// Everything the scanning device needs, and nothing else.
///
/// Encoded as a URI rather than raw JSON: it is shorter for the same content
/// (a denser QR, easier to scan across a room), it is unambiguous about
/// version, and it leaves the door open to registering the scheme so a photo
/// of the code could open the app directly.
///
/// The secret travels **in the code itself**. That is the whole design: the
/// camera is the secure channel, and possession of the code is what proves a
/// device is the one standing in front of the screen. It follows that the
/// code must be treated as the credential it is — single-use, short-lived,
/// and never persisted, photographed or logged.
class PairingCode {
  PairingCode({
    required this.addresses,
    required this.port,
    required Uint8List secret,
    required this.deviceName,
  }) : secret = Uint8List.fromList(secret) {
    if (secret.length < kTransferSecretBytes) {
      throw ArgumentError.value(
        secret.length,
        'secret',
        'must be at least $kTransferSecretBytes bytes',
      );
    }
    if (addresses.isEmpty) {
      throw ArgumentError.value(addresses, 'addresses', 'must not be empty');
    }
  }

  /// A fresh code with a new secret from [Random.secure].
  factory PairingCode.generate({
    required List<String> addresses,
    required int port,
    required String deviceName,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    return PairingCode(
      addresses: addresses,
      port: port,
      secret: Uint8List.fromList(
        List.generate(kTransferSecretBytes, (_) => source.nextInt(256)),
      ),
      deviceName: deviceName,
    );
  }

  static const String scheme = 'sshetu';
  static const int version = 1;

  /// Every address the sender is reachable on.
  ///
  /// More than one because a laptop routinely has several — Wi-Fi, Ethernet, a
  /// VPN interface — and only the phone can tell which of them it can actually
  /// reach. Guessing on the sender's side gets it wrong exactly when someone
  /// is on a network they did not configure.
  final List<String> addresses;

  final int port;

  /// The shared secret, from which both ends derive their channel keys.
  final Uint8List secret;

  /// Shown on the receiver before it accepts, so a person can tell they are
  /// talking to their own laptop.
  final String deviceName;

  /// `sshetu://transfer/v1?h=…&p=…&s=…&n=…`
  String encode() {
    final query = <String>[
      for (final address in addresses) 'h=${Uri.encodeQueryComponent(address)}',
      'p=$port',
      's=${base64Url.encode(secret).replaceAll('=', '')}',
      'n=${Uri.encodeQueryComponent(deviceName)}',
    ];
    return '$scheme://transfer/v$version?${query.join('&')}';
  }

  static PairingCode decode(String raw) {
    final Uri uri;
    try {
      uri = Uri.parse(raw.trim());
    } on FormatException {
      throw const PairingCodeException('not a pairing code');
    }

    if (uri.scheme != scheme || uri.host != 'transfer') {
      throw const PairingCodeException('not an SSHetu pairing code');
    }
    // The version is in the path, so a future format cannot be mistaken for
    // this one by a build that predates it.
    if (uri.path != '/v$version') {
      throw PairingCodeException(
        'this code is version ${uri.path.replaceFirst('/v', '')}; '
        'this app speaks version $version',
      );
    }

    final addresses = uri.queryParametersAll['h'] ?? const [];
    final port = int.tryParse(uri.queryParameters['p'] ?? '');
    final encoded = uri.queryParameters['s'];
    final name = uri.queryParameters['n'];

    if (addresses.isEmpty || port == null || encoded == null || name == null) {
      throw const PairingCodeException('pairing code is missing a field');
    }
    if (port < 1 || port > 65535) {
      throw const PairingCodeException('pairing code names an invalid port');
    }

    final Uint8List secret;
    try {
      secret = base64Url.decode(base64Url.normalize(encoded));
    } on FormatException {
      throw const PairingCodeException('pairing code secret is malformed');
    }
    if (secret.length < kTransferSecretBytes) {
      throw const PairingCodeException('pairing code secret is too short');
    }

    return PairingCode(
      addresses: addresses,
      port: port,
      secret: secret,
      deviceName: name,
    );
  }
}
