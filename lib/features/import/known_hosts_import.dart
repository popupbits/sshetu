import '../../core/ssh/host_key.dart';
import '../../core/ssh/known_hosts_file.dart';
import '../../core/ssh/known_hosts_store.dart';

/// A host the file and this device disagree about: the device already
/// trusts a key for it, and none of the file's keys for it is that key.
///
/// Never resolved by the import. Overwriting a pin is exactly what host key
/// verification exists to stop happening quietly; the user forgets the old
/// pin deliberately, from the trusted-keys screen, and imports again.
class KnownHostsConflict {
  const KnownHostsConflict({
    required this.address,
    required this.trusted,
    required this.fileKeys,
  });

  /// `host`, or `host:port` off port 22.
  final String address;

  /// What this device trusts now.
  final KnownHostKey trusted;

  /// What the file says instead.
  final List<KnownHostsEntry> fileKeys;
}

/// What importing a parsed `known_hosts` file would do, worked out before
/// anything is written — the preview the user confirms.
class KnownHostsImportPreview {
  const KnownHostsImportPreview({
    required this.parsed,
    required this.toTrust,
    required this.alreadyTrusted,
    required this.conflicts,
    required this.alternateKeys,
  });

  final KnownHostsParseResult parsed;

  /// New pins, plain and hashed. Written by [applyKnownHostsImport].
  final List<KnownHostKey> toTrust;

  /// Hosts (or hashed lines) whose key this device already trusts.
  final int alreadyTrusted;

  final List<KnownHostsConflict> conflicts;

  /// Further keys for a host that is imported, or already trusted, under
  /// another key type. A device pins one key per plain `host:port`; the one
  /// kept is the type a connection negotiates first, so the others would
  /// never be the one shown.
  final int alternateKeys;

  int get newHashed => toTrust.where((k) => k.isHashed).length;

  bool get isEmpty => toTrust.isEmpty;
}

/// Sorts [parsed] against the keys this device already trusts.
///
/// **Plain names** are grouped by `host:port`. A host this device has no pin
/// for is new, and gets the file's preferred key (see
/// [kImportableKeyTypes]). A host it does have a pin for is either already
/// trusted — one of the file's keys is that pin — or a conflict.
///
/// **Hashed names** cannot be grouped: OpenSSH hashes each line with its
/// own salt, so two keys for one host look like two strangers. Each line is
/// checked against every existing pin by hashing that pin's address; an
/// unmatched line is new and is stored hashed, to be matched by name when a
/// connection asks (see `matchingKnownHosts`). A matched line of the same
/// key type but a different fingerprint is a conflict; of a different key
/// type it is an alternate key for a host already trusted.
KnownHostsImportPreview previewKnownHostsImport(
  KnownHostsParseResult parsed,
  List<KnownHostKey> existing, {
  required DateTime now,
}) {
  final toTrust = <KnownHostKey>[];
  final conflicts = <KnownHostsConflict>[];
  var alreadyTrusted = 0;
  var alternates = 0;

  bool same(KnownHostKey pin, KnownHostsEntry entry) =>
      pin.fingerprint == entry.fingerprint &&
      hostKeyFamily(pin.keyType) == hostKeyFamily(entry.keyType);

  // Plain names, grouped by address in file order.
  final groups = <(String, int), List<KnownHostsEntry>>{};
  for (final entry in parsed.entries.where((e) => !e.isHashed)) {
    (groups[(entry.host, entry.port)] ??= []).add(entry);
  }
  for (final MapEntry(key: (host, port), value: keys) in groups.entries) {
    final pins = matchingKnownHosts(existing, host, port);
    if (pins.isNotEmpty) {
      if (pins.any((pin) => keys.any((entry) => same(pin, entry)))) {
        alreadyTrusted++;
        alternates += _distinctKeys(keys) - 1;
      } else {
        conflicts.add(
          KnownHostsConflict(
            address: _address(host, port),
            trusted: pins.first,
            fileKeys: keys,
          ),
        );
      }
      continue;
    }
    final preferred = _preferred(keys);
    alternates += _distinctKeys(keys) - 1;
    toTrust.add(
      KnownHostKey(
        hostname: host,
        port: port,
        keyType: preferred.keyType,
        fingerprint: preferred.fingerprint,
        trustedAt: now,
      ),
    );
  }

  // Hashed names, one line at a time.
  final seenHashed = <String>{};
  final plainPins = existing.where((k) => !k.isHashed).toList();
  for (final entry in parsed.entries.where((e) => e.isHashed)) {
    if (!seenHashed.add(entry.host)) continue;
    final pins = [
      for (final pin in plainPins)
        if (hashedNameMatches(
          entry.host,
          knownHostsName(pin.hostname, pin.port),
        ))
          pin,
      for (final pin in existing)
        if (pin.isHashed && pin.hostname == entry.host) pin,
    ];
    if (pins.isEmpty) {
      toTrust.add(
        KnownHostKey(
          hostname: entry.host,
          port: 0,
          keyType: entry.keyType,
          fingerprint: entry.fingerprint,
          trustedAt: now,
        ),
      );
      continue;
    }
    if (pins.any((pin) => same(pin, entry))) {
      alreadyTrusted++;
      continue;
    }
    final rival = pins
        .where(
          (pin) => hostKeyFamily(pin.keyType) == hostKeyFamily(entry.keyType),
        )
        .firstOrNull;
    if (rival == null) {
      alternates++;
      continue;
    }
    conflicts.add(
      KnownHostsConflict(
        address: rival.isHashed
            ? rival.hostname
            : _address(rival.hostname, rival.port),
        trusted: rival,
        fileKeys: [entry],
      ),
    );
  }

  return KnownHostsImportPreview(
    parsed: parsed,
    toTrust: toTrust,
    alreadyTrusted: alreadyTrusted,
    conflicts: conflicts,
    alternateKeys: alternates,
  );
}

/// Trusts every new key in [preview]. Conflicts and existing pins are not
/// touched — the preview never put them in [KnownHostsImportPreview.toTrust].
/// Returns how many were written.
Future<int> applyKnownHostsImport(
  KnownHostsStore store,
  KnownHostsImportPreview preview,
) async {
  for (final key in preview.toTrust) {
    await store.trust(key);
  }
  return preview.toTrust.length;
}

String _address(String host, int port) => port == 22 ? host : '$host:$port';

/// The key a connection would be shown first, by dartssh2's preference.
KnownHostsEntry _preferred(List<KnownHostsEntry> keys) {
  var best = keys.first;
  for (final entry in keys) {
    if (kImportableKeyTypes.indexOf(entry.keyType) <
        kImportableKeyTypes.indexOf(best.keyType)) {
      best = entry;
    }
  }
  return best;
}

int _distinctKeys(List<KnownHostsEntry> keys) =>
    {for (final entry in keys) entry.fingerprint}.length;
