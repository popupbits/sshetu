import 'package:dartssh2/dartssh2.dart';

/// Which algorithms a connection is allowed to negotiate.
///
/// dartssh2 4.0 removed SHA-1 key exchange, `ssh-rsa` host-key signatures and
/// CBC ciphers from its defaults, so a server that offers nothing else now
/// fails to negotiate instead of connecting weakly. That is the right default
/// and this app keeps it.
///
/// But "fails to negotiate" is also what happens in front of a switch, a
/// router, a BMC or an embedded board that will never get a firmware update.
/// Refusing to talk to those at all is not security, it is an app the user
/// abandons for one that works. So the legacy set can be turned back on —
/// **per host, never globally, never silently**:
///
///  * per host, because one appliance must not weaken every other connection;
///  * never silently, because the user is accepting a real downgrade and has
///    to be told what it costs, in the host editor, at the moment they choose;
///  * and the connection fails *first*. Discovering the weak algorithms only
///    after a successful connection would mean the choice was never made.
abstract final class SshAlgorithmPolicy {
  /// The modern set: exactly dartssh2 4.0's defaults.
  static const SSHAlgorithms modern = SSHAlgorithms();

  /// The modern set plus the algorithms 4.0 dropped.
  ///
  /// Legacy entries are appended, never prepended, so preference order still
  /// picks the strongest algorithm both ends support. Turning this on lets an
  /// old device connect; it does not downgrade a modern one.
  static const SSHAlgorithms permissive = SSHAlgorithms(
    kex: [
      // Modern, in dartssh2's own preference order.
      SSHKexType.x25519Rfc,
      SSHKexType.x25519,
      SSHKexType.nistp521,
      SSHKexType.nistp384,
      SSHKexType.nistp256,
      SSHKexType.dhGexSha256,
      SSHKexType.dh14Sha256,
      // Legacy: SHA-1 key exchange, and 1024-bit DH last of all.
      SSHKexType.dhGexSha1,
      SSHKexType.dh14Sha1,
      SSHKexType.dh1Sha1,
    ],
    hostkey: [
      SSHHostkeyType.ed25519,
      SSHHostkeyType.rsaSha512,
      SSHHostkeyType.rsaSha256,
      SSHHostkeyType.ecdsa521,
      SSHHostkeyType.ecdsa384,
      SSHHostkeyType.ecdsa256,
      // Legacy: SHA-1 RSA host key signatures.
      SSHHostkeyType.rsaSha1,
    ],
    cipher: [
      SSHCipherType.aes256gcm,
      SSHCipherType.aes128gcm,
      SSHCipherType.chacha20poly1305,
      SSHCipherType.aes256ctr,
      SSHCipherType.aes128ctr,
      // Legacy: CBC. Unauthenticated encryption; last resort.
      SSHCipherType.aes256cbc,
      SSHCipherType.aes192cbc,
      SSHCipherType.aes128cbc,
    ],
    mac: [
      SSHMacType.hmacSha256Etm,
      SSHMacType.hmacSha512Etm,
      SSHMacType.hmacSha256,
      SSHMacType.hmacSha512,
      SSHMacType.hmacSha1,
      // Legacy.
      SSHMacType.hmacSha256_96,
      SSHMacType.hmacSha512_96,
      SSHMacType.hmacMd5,
    ],
  );

  /// The set to use for a host, given its opt-in.
  static SSHAlgorithms forHost({required bool allowLegacy}) =>
      allowLegacy ? permissive : modern;

  // What the host editor tells the user next to the switch is the
  // `hostEditorLegacyHelp` string in lib/l10n — it names what [permissive]
  // adds, so a change to these lists changes that string too.
}
