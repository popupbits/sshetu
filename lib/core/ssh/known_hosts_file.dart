import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Reading OpenSSH's `known_hosts` format (`sshd(8)`, "SSH_KNOWN_HOSTS FILE
/// FORMAT"), for importing the host keys a desktop's own `ssh` already
/// trusts.
///
/// Each line is `[marker] hostnames keytype base64-key [comment]`, where
/// hostnames is a comma-separated list of names, `[name]:port` for a port
/// other than 22, or a single hashed entry `|1|salt|hash`.

/// Key types the app can verify, in dartssh2's host-key preference order —
/// the order that decides which of a server's keys a connection is shown.
/// `ssh-rsa` stands for every RSA signature algorithm; see
/// [hostKeyFamily].
const kImportableKeyTypes = [
  'ssh-ed25519',
  'ssh-rsa',
  'ecdsa-sha2-nistp521',
  'ecdsa-sha2-nistp384',
  'ecdsa-sha2-nistp256',
];

/// The key a host-key algorithm name signs with.
///
/// A server's RSA key is one key however it is negotiated — `ssh-rsa`,
/// `rsa-sha2-256` and `rsa-sha2-512` are three signature algorithms over the
/// same blob, with the same fingerprint — and which one a connection uses
/// depends on what the client offers, not on the server's identity. Every
/// other algorithm name names its key type exactly.
String hostKeyFamily(String algorithm) => switch (algorithm) {
  'rsa-sha2-256' || 'rsa-sha2-512' => 'ssh-rsa',
  _ => algorithm,
};

/// The name a host is recorded under in `known_hosts`: bare on port 22,
/// `[host]:port` otherwise — which is also the string a hashed entry hashes.
String knownHostsName(String host, int port) =>
    port == 22 ? host : '[$host]:$port';

/// `SHA256:` plus the unpadded base64 of the key blob's SHA-256 — exactly
/// what dartssh2 hands the host-key verifier, so an imported pin compares
/// equal to the one a connection presents.
String hostKeyFingerprint(Uint8List blob) =>
    'SHA256:${base64.encode(sha256.convert(blob).bytes).replaceAll('=', '')}';

/// Whether [hashedName] (`|1|base64 salt|base64 hash`) is the hash of
/// [name] — HMAC-SHA1 keyed with the salt, as OpenSSH writes them under
/// `HashKnownHosts yes`. False for anything malformed.
bool hashedNameMatches(String hashedName, String name) {
  final parts = _splitHashed(hashedName);
  if (parts == null) return false;
  final (salt, hash) = parts;
  final digest = Hmac(sha1, salt).convert(utf8.encode(name)).bytes;
  if (digest.length != hash.length) return false;
  var diff = 0;
  for (var i = 0; i < digest.length; i++) {
    diff |= digest[i] ^ hash[i];
  }
  return diff == 0;
}

/// Whether [hostname] is a hashed `known_hosts` name rather than a real one.
bool isHashedHostName(String hostname) => _splitHashed(hostname) != null;

(Uint8List, Uint8List)? _splitHashed(String value) {
  if (!value.startsWith('|1|')) return null;
  final parts = value.substring(3).split('|');
  if (parts.length != 2) return null;
  try {
    final salt = base64.decode(parts[0]);
    final hash = base64.decode(parts[1]);
    if (salt.length != 20 || hash.length != 20) return null;
    return (salt, hash);
  } on FormatException {
    return null;
  }
}

/// One usable key line, for one name. A line naming three hosts yields
/// three of these.
class KnownHostsEntry {
  const KnownHostsEntry({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.line,
  });

  /// The host name, lowercased — or the whole `|1|salt|hash` string for a
  /// hashed entry, whose real name cannot be recovered.
  final String host;

  /// The port, or 0 for a hashed entry: the port is inside the hash.
  final int port;

  final String keyType;
  final String fingerprint;

  /// 1-based, for pointing at the line in a summary.
  final int line;

  bool get isHashed => port == 0;

  @override
  String toString() => 'KnownHostsEntry($host:$port, $keyType, line $line)';
}

/// Why a line produced no entry.
enum KnownHostsSkip {
  /// `@revoked` — a key to *refuse*. This app pins keys it trusts; it has no
  /// list of keys to refuse, so the line cannot be honoured and is reported.
  revoked,

  /// `@cert-authority` — trusts every host key a CA signed. The app does not
  /// verify host certificates.
  certAuthority,

  /// A key type the app cannot verify (`ssh-dss`, security-key types).
  unsupportedKeyType,

  /// Not a line in the format at all, or a key that does not decode.
  malformed,
}

/// Everything a `known_hosts` file held, sorted into what can be imported
/// and what cannot.
class KnownHostsParseResult {
  const KnownHostsParseResult({
    required this.entries,
    required this.skipped,
    required this.wildcardNames,
  });

  /// Plain and hashed entries, in file order.
  final List<KnownHostsEntry> entries;

  /// Lines that yielded nothing, by reason, as 1-based line numbers.
  final Map<KnownHostsSkip, List<int>> skipped;

  /// Names that are patterns (`*.example.com`, `10.0.0.?`) or negations
  /// (`!bastion`): they describe many hosts or none, and a pin is for one
  /// `host:port`. Counted per name, not per line.
  final int wildcardNames;

  int skippedCount(KnownHostsSkip reason) => skipped[reason]?.length ?? 0;
}

/// Parses the text of a `known_hosts` file. Never throws: a line that makes
/// no sense is reported as [KnownHostsSkip.malformed] and the rest still
/// count.
KnownHostsParseResult parseKnownHosts(String text) {
  final entries = <KnownHostsEntry>[];
  final skipped = <KnownHostsSkip, List<int>>{};
  var wildcards = 0;

  void skip(KnownHostsSkip reason, int line) =>
      (skipped[reason] ??= []).add(line);

  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final lineNumber = i + 1;
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    var fields = line.split(RegExp(r'\s+'));
    if (fields.first.startsWith('@')) {
      switch (fields.first) {
        case '@revoked':
          skip(KnownHostsSkip.revoked, lineNumber);
        case '@cert-authority':
          skip(KnownHostsSkip.certAuthority, lineNumber);
        default:
          skip(KnownHostsSkip.malformed, lineNumber);
      }
      continue;
    }
    if (fields.length < 3) {
      skip(KnownHostsSkip.malformed, lineNumber);
      continue;
    }
    final names = fields[0];
    final keyType = fields[1];
    fields = fields.sublist(2);

    if (!kImportableKeyTypes.contains(keyType)) {
      // A key type is a short token of letters, digits and punctuation; a
      // line whose second field is not even that is broken, not unusual.
      skip(
        RegExp(r'^[a-z0-9@.\-]+$').hasMatch(keyType)
            ? KnownHostsSkip.unsupportedKeyType
            : KnownHostsSkip.malformed,
        lineNumber,
      );
      continue;
    }

    final blob = _decodeKey(fields.first, keyType);
    if (blob == null) {
      skip(KnownHostsSkip.malformed, lineNumber);
      continue;
    }
    final fingerprint = hostKeyFingerprint(blob);

    if (names.startsWith('|')) {
      if (!isHashedHostName(names)) {
        skip(KnownHostsSkip.malformed, lineNumber);
        continue;
      }
      entries.add(
        KnownHostsEntry(
          host: names,
          port: 0,
          keyType: keyType,
          fingerprint: fingerprint,
          line: lineNumber,
        ),
      );
      continue;
    }

    var produced = false;
    var broken = false;
    for (final name in names.split(',')) {
      if (name.isEmpty) continue;
      if (name.startsWith('!') || name.contains('*') || name.contains('?')) {
        wildcards++;
        continue;
      }
      final address = _parseName(name);
      if (address == null) {
        broken = true;
        continue;
      }
      entries.add(
        KnownHostsEntry(
          host: address.$1,
          port: address.$2,
          keyType: keyType,
          fingerprint: fingerprint,
          line: lineNumber,
        ),
      );
      produced = true;
    }
    if (broken && !produced) skip(KnownHostsSkip.malformed, lineNumber);
  }

  return KnownHostsParseResult(
    entries: entries,
    skipped: skipped,
    wildcardNames: wildcards,
  );
}

/// `host` or `[host]:port`, lowercased. Null for a bracket that does not
/// close, a port that is not one, or a name with characters no host has.
(String, int)? _parseName(String name) {
  var host = name;
  var port = 22;
  if (name.startsWith('[')) {
    final match = RegExp(r'^\[([^\]]+)\]:(\d{1,5})$').firstMatch(name);
    if (match == null) return null;
    host = match.group(1)!;
    port = int.parse(match.group(2)!);
    if (port < 1 || port > 65535) return null;
  }
  if (host.isEmpty || RegExp(r'[\s\[\]|,]').hasMatch(host)) return null;
  return (host.toLowerCase(), port);
}

/// The key blob, when [encoded] is valid base64 whose embedded type name
/// (the blob's first SSH string) is [keyType]. A key that claims one type
/// and holds another is corrupt, and its fingerprint would pin nothing.
Uint8List? _decodeKey(String encoded, String keyType) {
  final Uint8List blob;
  try {
    blob = base64.decode(encoded);
  } on FormatException {
    return null;
  }
  if (blob.length < 4) return null;
  final length = ByteData.sublistView(blob, 0, 4).getUint32(0);
  if (length != keyType.length || blob.length < 4 + length) return null;
  final embedded = ascii.decode(
    blob.sublist(4, 4 + length),
    allowInvalid: true,
  );
  return embedded == keyType ? blob : null;
}
