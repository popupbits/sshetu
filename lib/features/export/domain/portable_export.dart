import 'dart:convert';

import '../../../core/ssh/host_key.dart';
import '../../../core/ssh/openssh_import.dart';
import '../../../core/ssh/ssh_target.dart';
import '../../hosts/domain/host_env.dart';
import '../../hosts/domain/host_group.dart';
import '../../hosts/domain/host_tags.dart';
import '../../hosts/domain/ssh_host.dart';
import '../../keys/domain/ssh_identity.dart';
import '../../snippets/domain/snippet.dart';
import '../../tunnels/domain/tunnel.dart';

/// Why a file could not be read as an export. The screen turns each into its
/// own sentence; see `docs/export-format.md` for the format itself.
enum PortableExportProblem {
  /// Not JSON at all, or not a JSON object.
  notJson,

  /// JSON, but not ours: `format` is missing or names something else.
  notAnExport,

  /// Written by a newer SSHetu, in a version this build does not know.
  newerVersion,

  /// A `version` that is not a positive whole number.
  invalidVersion,

  /// Ours and a version we read, but an entry is missing a required field or
  /// has one of the wrong type. [PortableExportException.detail] names it.
  malformed,
}

class PortableExportException implements Exception {
  const PortableExportException(this.problem, {this.detail, this.version});

  final PortableExportProblem problem;

  /// Where a [PortableExportProblem.malformed] file went wrong, as a JSON
  /// path — `hosts[3].hostname`.
  final String? detail;

  /// The version a [PortableExportProblem.newerVersion] file declared.
  final int? version;

  @override
  String toString() =>
      'PortableExportException(${problem.name}'
      '${detail == null ? '' : ', $detail'}'
      '${version == null ? '' : ', v$version'})';
}

/// The plain JSON export: every piece of configuration, **no secret**.
///
/// The encrypted backup (`features/backup`) is how a user keeps *everything*,
/// keys and passwords included. This is the other thing a user of a
/// device-local app is owed: a way out. A readable, documented file another
/// tool — or a script, or a person with a text editor — can use without
/// SSHetu, and that SSHetu can read back without loss.
///
/// Built from domain objects rather than raw rows, unlike a transfer: a
/// transfer is between two copies of this app and can afford to mirror the
/// schema, but a file meant for other programs has to hold still while the
/// schema moves. `docs/export-format.md` is the contract; [version] changes
/// only when that contract does.
///
/// What is deliberately absent: private keys, key passphrases and saved
/// passwords. Identities travel as their public half and fingerprint, so an
/// import can link a host to a key the receiving device already holds.
class PortableExport {
  const PortableExport({
    required this.exportedAt,
    required this.app,
    this.groups = const [],
    this.identities = const [],
    this.hosts = const [],
    this.tunnels = const [],
    this.snippets = const [],
    this.knownHosts = const [],
    this.hostIdentityFingerprints = const {},
  });

  static const String format = 'sshetu-export';

  /// The only version this build writes, and the newest it reads.
  static const int version = 1;

  final DateTime exportedAt;

  /// The SSHetu build that wrote it — provenance only, never interpreted.
  final String app;

  final List<HostGroup> groups;
  final List<SshIdentity> identities;
  final List<SshHost> hosts;
  final List<Tunnel> tunnels;
  final List<Snippet> snippets;
  final List<KnownHostKey> knownHosts;

  /// Host id to the fingerprint of the key it uses, as read from a file.
  ///
  /// Carried on each host as well as in `identities`, so a file someone
  /// trimmed by hand — hosts kept, key list deleted — can still link hosts to
  /// the keys a device already has. [fingerprintForHost] prefers this and
  /// falls back to [identities].
  final Map<String, String> hostIdentityFingerprints;

  /// The fingerprint of the key [host] names, if the file says.
  String? fingerprintForHost(SshHost host) {
    final carried = hostIdentityFingerprints[host.id];
    if (carried != null) return carried;
    final id = host.identityId;
    if (id == null) return null;
    for (final identity in identities) {
      if (identity.id == id) return fingerprintOfIdentity(identity);
    }
    return null;
  }

  /// An identity's fingerprint, computed from its public key when the row
  /// has none recorded.
  static String? fingerprintOfIdentity(SshIdentity identity) {
    final recorded = identity.fingerprint;
    if (recorded != null && recorded.isNotEmpty) return recorded;
    final pub = identity.publicKey;
    return pub == null ? null : OpenSshScanner.fingerprintOf(pub);
  }

  /// The file's text: pretty-printed, keys in a fixed order, every list
  /// sorted, and a trailing newline — so the same configuration always
  /// produces the same bytes and two exports diff cleanly.
  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  Map<String, Object?> toJson() {
    final byIdentity = {
      for (final identity in identities)
        identity.id: fingerprintOfIdentity(identity),
    };
    return {
      'format': format,
      'version': version,
      'exportedAt': _time(exportedAt),
      'app': app,
      // Said in the file as well as the UI. Someone who finds this file in a
      // folder years from now should not have to wonder.
      'containsSecrets': false,
      'groups': [for (final g in _byId(groups, (g) => g.id)) groupJson(g)],
      'identities': [
        for (final i in _byId(identities, (i) => i.id)) identityJson(i),
      ],
      'hosts': [
        for (final h in _byId(hosts, (h) => h.id))
          hostJson(
            h,
            h.identityId == null
                ? null
                : byIdentity[h.identityId] ?? hostIdentityFingerprints[h.id],
          ),
      ],
      'tunnels': [for (final t in _byId(tunnels, (t) => t.id)) tunnelJson(t)],
      'snippets': [
        for (final s in _byId(snippets, (s) => s.id)) snippetJson(s),
      ],
      'knownHosts': [
        for (final k in [...knownHosts]..sort(_compareKnownHosts))
          knownHostJson(k),
      ],
    };
  }

  static const String _bom = '\u{FEFF}';

  /// Reads a file's text. Throws [PortableExportException].
  static PortableExport decode(String text) {
    Object? decoded;
    try {
      // A BOM is legal at the front of a UTF-8 file and jsonDecode rejects
      // it; Windows editors add one when a user saves a hand edit.
      decoded = jsonDecode(text.startsWith(_bom) ? text.substring(1) : text);
    } on FormatException {
      throw const PortableExportException(PortableExportProblem.notJson);
    }
    if (decoded is! Map<String, Object?>) {
      throw const PortableExportException(PortableExportProblem.notJson);
    }
    return fromJson(decoded);
  }

  static PortableExport fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const PortableExportException(PortableExportProblem.notAnExport);
    }
    final found = json['version'];
    if (found is! int || found < 1) {
      throw const PortableExportException(PortableExportProblem.invalidVersion);
    }
    if (found > version) {
      throw PortableExportException(
        PortableExportProblem.newerVersion,
        version: found,
      );
    }

    final exportedAt = DateTime.tryParse(
      json['exportedAt'] is String ? json['exportedAt']! as String : '',
    )?.toUtc();
    // A hand-written file may leave the bookkeeping out. The moment it was
    // exported is the honest stand-in; failing that, now.
    final reader = _Reader(exportedAt ?? DateTime.now().toUtc());
    final fingerprints = <String, String>{};
    final hosts = reader.list(json, 'hosts', (r, path) {
      final host = _readHost(r, path);
      final fp = r.optString('identityFingerprint');
      if (fp != null && fp.isNotEmpty) fingerprints[host.id] = fp;
      return host;
    });

    return PortableExport(
      exportedAt:
          exportedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      app: json['app'] is String ? json['app']! as String : '',
      groups: reader.list(json, 'groups', _readGroup),
      identities: reader.list(json, 'identities', _readIdentity),
      hosts: hosts,
      tunnels: reader.list(json, 'tunnels', _readTunnel),
      snippets: reader.list(json, 'snippets', _readSnippet),
      knownHosts: reader.list(json, 'knownHosts', _readKnownHost),
      hostIdentityFingerprints: fingerprints,
    );
  }

  // ---------------------------------------------------------------------------
  // Writing. One function per kind, keys in the order docs/export-format.md
  // lists them. Every key is always present — null rather than absent — so a
  // reader can see the whole shape from any one entry.

  static Map<String, Object?> groupJson(HostGroup g) => {
    'id': g.id,
    'name': g.name,
    'sortOrder': g.sortOrder,
    'createdAt': _time(g.createdAt),
    'updatedAt': _time(g.updatedAt),
  };

  static Map<String, Object?> identityJson(SshIdentity i) => {
    'id': i.id,
    'label': i.label,
    'keyType': i.keyType,
    'publicKey': i.publicKey,
    'fingerprint': fingerprintOfIdentity(i),
    'hasPassphrase': i.hasPassphrase,
    'origin': i.origin.name,
    'createdAt': _time(i.createdAt),
    'updatedAt': _time(i.updatedAt),
  };

  static Map<String, Object?> hostJson(
    SshHost h,
    String? identityFingerprint,
  ) => {
    'id': h.id,
    'label': h.label,
    'hostname': h.hostname,
    'port': h.port,
    'username': h.username,
    'authMethod': h.authMethod.name,
    'groupId': h.groupId,
    'identityId': h.identityId,
    'identityFingerprint': identityFingerprint,
    'jumpHostId': h.jumpHostId,
    'allowLegacyAlgorithms': h.allowLegacyAlgorithms,
    'forwardAgent': h.forwardAgent,
    'tmuxMode': h.tmuxMode.exportValue,
    'keepaliveSeconds': h.keepaliveSeconds,
    'startupCommand': h.startupCommand,
    'terminalTheme': h.terminalTheme,
    'fontSize': h.fontSize,
    'notes': h.notes,
    'tags': h.tags,
    'envVars': h.envVars,
    'lastConnectedAt': h.lastConnectedAt == null
        ? null
        : _time(h.lastConnectedAt!),
    'createdAt': _time(h.createdAt),
    'updatedAt': _time(h.updatedAt),
  };

  static Map<String, Object?> tunnelJson(Tunnel t) => {
    'id': t.id,
    'hostId': t.hostId,
    'label': t.label,
    'kind': t.kind.storageValue,
    'listenHost': t.listenHost,
    'listenPort': t.listenPort,
    'targetHost': t.targetHost,
    'targetPort': t.targetPort,
    'autoStart': t.autoStart,
    'createdAt': _time(t.createdAt),
    'updatedAt': _time(t.updatedAt),
  };

  static Map<String, Object?> snippetJson(Snippet s) => {
    'id': s.id,
    'label': s.label,
    'body': s.body,
    'description': s.description,
    'tags': s.tags,
    'sortOrder': s.sortOrder,
    'createdAt': _time(s.createdAt),
    'updatedAt': _time(s.updatedAt),
  };

  static Map<String, Object?> knownHostJson(KnownHostKey k) => {
    'hostname': k.hostname,
    'port': k.port,
    'keyType': k.keyType,
    'fingerprint': k.fingerprint,
    'trustedAt': _time(k.trustedAt),
  };

  // ---------------------------------------------------------------------------
  // Reading.

  static HostGroup _readGroup(_Entry r, String path) => HostGroup(
    id: r.string('id'),
    name: r.string('name'),
    sortOrder: r.optInt('sortOrder') ?? 0,
    createdAt: r.time('createdAt'),
    updatedAt: r.time('updatedAt'),
  );

  static SshIdentity _readIdentity(_Entry r, String path) => SshIdentity(
    id: r.string('id'),
    label: r.string('label'),
    keyType: r.optString('keyType') ?? 'unknown',
    publicKey: r.optString('publicKey'),
    fingerprint: r.optString('fingerprint'),
    hasPassphrase: r.optBool('hasPassphrase') ?? false,
    origin: IdentityOrigin.values.firstWhere(
      (o) => o.name == r.optString('origin'),
      orElse: () => IdentityOrigin.imported,
    ),
    createdAt: r.time('createdAt'),
    updatedAt: r.time('updatedAt'),
  );

  static SshHost _readHost(_Entry r, String path) {
    final port = r.optInt('port') ?? 22;
    if (port < 1 || port > 65535) r.fail('port');
    return SshHost(
      id: r.string('id'),
      label: r.string('label'),
      hostname: r.string('hostname'),
      port: port,
      username: r.string('username'),
      authMethod: SshAuthMethod.values.firstWhere(
        (m) => m.name == r.optString('authMethod'),
        // The same reading the repository gives a value it does not know.
        orElse: () => SshAuthMethod.publicKey,
      ),
      groupId: r.optString('groupId'),
      identityId: r.optString('identityId'),
      jumpHostId: r.optString('jumpHostId'),
      allowLegacyAlgorithms: r.optBool('allowLegacyAlgorithms') ?? false,
      forwardAgent: r.optBool('forwardAgent') ?? false,
      // Missing (a file from before v7) or unknown follows the setting.
      tmuxMode: HostTmuxMode.fromStorage(r.optString('tmuxMode')),
      keepaliveSeconds: r.optInt('keepaliveSeconds') ?? 30,
      startupCommand: r.optString('startupCommand'),
      terminalTheme: r.optString('terminalTheme'),
      fontSize: r.optDouble('fontSize'),
      notes: r.optString('notes'),
      tags: HostTags.normalize(r.stringList('tags')),
      envVars: {
        for (final entry in r.stringMap('envVars').entries)
          // The host editor's rules: a name becomes shell syntax on the
          // server, so a file cannot smuggle in one the editor would refuse.
          if (HostEnv.problemAt([(entry.key, entry.value)], 0) == null)
            entry.key: entry.value,
      },
      lastConnectedAt: r.optTime('lastConnectedAt'),
      createdAt: r.time('createdAt'),
      updatedAt: r.time('updatedAt'),
    );
  }

  static Tunnel _readTunnel(_Entry r, String path) {
    final listenPort = r.optInt('listenPort');
    if (!Tunnel.isValidPort(listenPort)) r.fail('listenPort');
    final kind = TunnelKind.fromStorage(r.string('kind'));
    final targetPort = r.optInt('targetPort');
    final targetHost = r.optString('targetHost');
    if (kind.requiresTarget &&
        (targetHost == null || !Tunnel.isValidPort(targetPort))) {
      r.fail(targetHost == null ? 'targetHost' : 'targetPort');
    }
    return Tunnel(
      id: r.string('id'),
      hostId: r.string('hostId'),
      label: r.string('label'),
      kind: kind,
      listenHost: r.optString('listenHost') ?? Tunnel.defaultListenHost,
      listenPort: listenPort!,
      targetHost: kind.requiresTarget ? targetHost : null,
      targetPort: kind.requiresTarget ? targetPort : null,
      autoStart: r.optBool('autoStart') ?? false,
      createdAt: r.time('createdAt'),
      updatedAt: r.time('updatedAt'),
    );
  }

  static Snippet _readSnippet(_Entry r, String path) => Snippet(
    id: r.string('id'),
    label: r.string('label'),
    body: r.string('body'),
    description: r.optString('description'),
    tags: HostTags.normalize(r.stringList('tags')),
    sortOrder: r.optInt('sortOrder') ?? 0,
    createdAt: r.time('createdAt'),
    updatedAt: r.time('updatedAt'),
  );

  static KnownHostKey _readKnownHost(_Entry r, String path) => KnownHostKey(
    hostname: r.string('hostname'),
    port: r.optInt('port') ?? 22,
    keyType: r.string('keyType'),
    fingerprint: r.string('fingerprint'),
    trustedAt: r.time('trustedAt'),
  );

  // ---------------------------------------------------------------------------

  /// UTC, millisecond precision — exactly what the database stores, so a
  /// round trip changes nothing.
  static String _time(DateTime value) => value.toUtc().toIso8601String();

  static List<T> _byId<T>(List<T> items, String Function(T) id) =>
      [...items]..sort((a, b) => id(a).compareTo(id(b)));

  static int _compareKnownHosts(KnownHostKey a, KnownHostKey b) {
    final byName = a.hostname.compareTo(b.hostname);
    return byName != 0 ? byName : a.port.compareTo(b.port);
  }
}

/// Reads one list of entries, naming the entry that fails.
class _Reader {
  _Reader(this._fallbackTime);

  final DateTime _fallbackTime;

  List<T> list<T>(
    Map<String, Object?> json,
    String key,
    T Function(_Entry entry, String path) read,
  ) {
    final raw = json[key];
    // Absent is "none": a file trimmed to only hosts is still a valid file.
    if (raw == null) return const [];
    if (raw is! List) {
      throw PortableExportException(
        PortableExportProblem.malformed,
        detail: key,
      );
    }
    return [
      for (var i = 0; i < raw.length; i++)
        if (raw[i] is Map<String, Object?>)
          read(
            _Entry(raw[i] as Map<String, Object?>, '$key[$i]', _fallbackTime),
            '$key[$i]',
          )
        else
          throw PortableExportException(
            PortableExportProblem.malformed,
            detail: '$key[$i]',
          ),
    ];
  }
}

/// Typed access to one JSON object, failing with the field's path.
class _Entry {
  _Entry(this._json, this._path, this._fallbackTime);

  final Map<String, Object?> _json;
  final String _path;
  final DateTime _fallbackTime;

  Never fail(String field) => throw PortableExportException(
    PortableExportProblem.malformed,
    detail: '$_path.$field',
  );

  String string(String field) {
    final value = _json[field];
    if (value is! String || value.isEmpty) fail(field);
    return value;
  }

  String? optString(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is! String) fail(field);
    return value;
  }

  int? optInt(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is int) return value;
    // 22.0 is a whole number a hand edit or another tool may well write.
    if (value is double && value == value.roundToDouble()) return value.toInt();
    fail(field);
  }

  double? optDouble(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is! num) fail(field);
    return value.toDouble();
  }

  bool? optBool(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is! bool) fail(field);
    return value;
  }

  /// A bookkeeping timestamp: absent falls back to the export's own time,
  /// present but unparsable is an error.
  DateTime time(String field) => optTime(field) ?? _fallbackTime;

  /// Absent is null; present but unparsable is an error.
  DateTime? optTime(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is! String) fail(field);
    return DateTime.tryParse(value)?.toUtc() ?? fail(field);
  }

  List<String> stringList(String field) {
    final value = _json[field];
    if (value == null) return const [];
    if (value is! List || value.any((v) => v is! String)) fail(field);
    return value.cast<String>();
  }

  Map<String, String> stringMap(String field) {
    final value = _json[field];
    if (value == null) return const {};
    if (value is! Map || value.values.any((v) => v is! String)) fail(field);
    return value.cast<String, String>();
  }
}
