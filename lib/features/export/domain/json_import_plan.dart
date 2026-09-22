import 'dart:convert';

import '../../../core/ssh/host_key.dart';
import '../../hosts/domain/host_group.dart';
import '../../hosts/domain/ssh_host.dart';
import '../../snippets/domain/snippet.dart';
import '../../tunnels/domain/tunnel.dart';
import 'portable_export.dart';

/// What to do with an incoming host that looks like one already saved — the
/// same `user@host:port` — but carries a different id.
enum ConflictRule {
  /// Update the saved host with the file's settings, keeping the saved id,
  /// so its tunnels, password and history stay attached.
  merge,

  /// Keep the saved host as it is and add the file's as a second one.
  addAsNew,
}

/// What importing one host would do.
enum HostImportAction {
  /// No saved host has this id or this address.
  add,

  /// A saved host has this id, and the file changes it.
  update,

  /// A saved host has this id, and the file says exactly what it already
  /// says.
  unchanged,

  /// No saved host has this id, but one has the same address. Resolved by
  /// the [ConflictRule].
  conflict,
}

/// One host from the file, and what importing it would do.
class HostImportRow {
  const HostImportRow({
    required this.incoming,
    required this.action,
    this.existing,
    this.linkedIdentityId,
    this.missingKey,
  });

  final SshHost incoming;
  final HostImportAction action;

  /// The saved host it matched, by id or by address.
  final SshHost? existing;

  /// The saved identity this host will use, found by fingerprint.
  final String? linkedIdentityId;

  /// The key this host names that this device does not have.
  final MissingKey? missingKey;
}

/// A key the file's hosts use that this device does not hold.
///
/// An export never carries private keys, so this is the list of what the
/// user still has to bring over — by an encrypted backup, a device transfer,
/// or pasting the key in — before those hosts can sign in with it.
class MissingKey {
  const MissingKey({
    required this.fingerprint,
    required this.label,
    required this.keyType,
    required this.hostLabels,
  });

  /// Null when the file named a key but not which one.
  final String? fingerprint;
  final String label;
  final String keyType;

  /// The hosts that will be imported without a key because of it.
  final List<String> hostLabels;
}

/// The counts of a kind that is simply matched by id.
class KindCounts {
  const KindCounts({this.added = 0, this.updated = 0, this.unchanged = 0});

  final int added;
  final int updated;
  final int unchanged;

  int get changes => added + updated;
}

/// What an import would change, worked out before anything is written.
///
/// The rules, in the order they apply:
///
/// 1. **A host is matched by id first.** Ids survive an export, so the same
///    id is the same host, and the file's copy updates the saved one.
/// 2. **Else by address** — hostname (ignoring case), port and username.
///    That is a *conflict*: probably the same server, saved separately on
///    two devices. The user chooses once for all of them: [ConflictRule.merge]
///    or [ConflictRule.addAsNew].
/// 3. **Keys are matched by fingerprint**, never by id: a key generated on
///    two devices has two ids and one fingerprint. A host whose key this
///    device lacks is imported without one, and [missingKeys] says which
///    keys to bring over.
/// 4. **A saved trust decision is never overwritten.** A known-host pin in
///    the file that disagrees with one here is left out and counted.
///
/// Pure: [JsonImportPlan.build] reads two [PortableExport]s — the file and
/// what is on this device — and [resolve] says what to write.
class JsonImportPlan {
  const JsonImportPlan._({
    required this.source,
    required this.local,
    required this.hosts,
    required this.missingKeys,
    required this.groups,
    required this.snippets,
    required this.knownHostsAdded,
    required this.knownHostsUnchanged,
    required this.knownHostsConflicting,
  });

  final PortableExport source;
  final PortableExport local;
  final List<HostImportRow> hosts;
  final List<MissingKey> missingKeys;
  final KindCounts groups;
  final KindCounts snippets;
  final int knownHostsAdded;
  final int knownHostsUnchanged;

  /// Pins in the file that disagree with this device's. Left out.
  final int knownHostsConflicting;

  int _count(HostImportAction action) =>
      hosts.where((h) => h.action == action).length;

  int get newHosts => _count(HostImportAction.add);
  int get updatedHosts => _count(HostImportAction.update);
  int get unchangedHosts => _count(HostImportAction.unchanged);
  int get conflicts => _count(HostImportAction.conflict);

  List<HostImportRow> get conflictRows =>
      hosts.where((h) => h.action == HostImportAction.conflict).toList();

  /// Whether applying would change nothing at all.
  bool get isEmpty =>
      newHosts == 0 &&
      updatedHosts == 0 &&
      conflicts == 0 &&
      groups.changes == 0 &&
      snippets.changes == 0 &&
      knownHostsAdded == 0 &&
      resolve(ConflictRule.merge).tunnels.isEmpty;

  static JsonImportPlan build({
    required PortableExport source,
    required PortableExport local,
  }) {
    final localHostsById = {for (final h in local.hosts) h.id: h};
    final localHostsByAddress = <String, SshHost>{};
    for (final host in local.hosts) {
      localHostsByAddress.putIfAbsent(_address(host), () => host);
    }
    final localIdentityByFingerprint = <String, String>{};
    for (final identity in local.identities) {
      final fp = PortableExport.fingerprintOfIdentity(identity);
      if (fp == null) continue;
      localIdentityByFingerprint.putIfAbsent(fp, () => identity.id);
    }
    final localIdentityIds = {for (final i in local.identities) i.id};

    final missing = <String, _MissingBuilder>{};
    final rows = <HostImportRow>[];
    for (final incoming in source.hosts) {
      String? linked;
      MissingKey? missingKey;
      final wanted = incoming.identityId;
      if (wanted != null) {
        final fp = source.fingerprintForHost(incoming);
        linked = fp == null
            // A file that names a key without saying which may still name
            // one this device has by id — the same device, exported and
            // re-imported. Anything else cannot be linked safely.
            ? (localIdentityIds.contains(wanted) ? wanted : null)
            : localIdentityByFingerprint[fp];
        if (linked == null) {
          final identity = source.identities
              .where((i) => i.id == wanted)
              .firstOrNull;
          final key = fp ?? 'id:$wanted';
          (missing[key] ??= _MissingBuilder(
            fingerprint: fp,
            label: identity?.label ?? wanted,
            keyType: identity?.keyType ?? 'unknown',
          )).hosts.add(incoming.label);
          missingKey = missing[key]!.build();
        }
      }

      final byId = localHostsById[incoming.id];
      final byAddress = byId == null
          ? localHostsByAddress[_address(incoming)]
          : null;

      final HostImportAction action;
      if (byId != null) {
        // References read as the file gives them: which id a jump host ends
        // up under depends on the rule, which is not chosen yet. An update by
        // id is between two copies of one row, so they almost always agree.
        final merged = _mergeHost(
          incoming: incoming,
          existing: byId,
          linkedIdentityId: linked,
        );
        action = _sameHost(merged, byId)
            ? HostImportAction.unchanged
            : HostImportAction.update;
      } else if (byAddress != null) {
        action = HostImportAction.conflict;
      } else {
        action = HostImportAction.add;
      }

      rows.add(
        HostImportRow(
          incoming: incoming,
          action: action,
          existing: byId ?? byAddress,
          linkedIdentityId: linked,
          missingKey: missingKey,
        ),
      );
    }

    // Groups: by id, then by name — a folder called "work" on both devices
    // is one folder, whatever its id.
    var groupsAdded = 0, groupsUpdated = 0, groupsUnchanged = 0;
    final localGroupsById = {for (final g in local.groups) g.id: g};
    final localGroupNames = {
      for (final g in local.groups) g.name.toLowerCase(),
    };
    for (final group in source.groups) {
      final existing = localGroupsById[group.id];
      if (existing != null) {
        if (_sameJson(
          PortableExport.groupJson(group),
          PortableExport.groupJson(existing),
        )) {
          groupsUnchanged++;
        } else {
          groupsUpdated++;
        }
      } else if (localGroupNames.contains(group.name.toLowerCase())) {
        groupsUnchanged++;
      } else {
        groupsAdded++;
      }
    }

    var snippetsAdded = 0, snippetsUpdated = 0, snippetsUnchanged = 0;
    final localSnippetsById = {for (final s in local.snippets) s.id: s};
    for (final snippet in source.snippets) {
      final existing = localSnippetsById[snippet.id];
      if (existing != null) {
        if (_sameJson(
          PortableExport.snippetJson(snippet),
          PortableExport.snippetJson(existing),
        )) {
          snippetsUnchanged++;
        } else {
          snippetsUpdated++;
        }
      } else if (_hasSameSnippet(local.snippets, snippet)) {
        snippetsUnchanged++;
      } else {
        snippetsAdded++;
      }
    }

    var pinsAdded = 0, pinsSame = 0, pinsConflicting = 0;
    final localPins = {for (final k in local.knownHosts) _pin(k): k};
    for (final key in source.knownHosts) {
      final existing = localPins[_pin(key)];
      if (existing == null) {
        pinsAdded++;
      } else if (existing.fingerprint == key.fingerprint &&
          existing.keyType == key.keyType) {
        pinsSame++;
      } else {
        pinsConflicting++;
      }
    }

    return JsonImportPlan._(
      source: source,
      local: local,
      hosts: rows,
      missingKeys: [for (final m in missing.values) m.build()],
      groups: KindCounts(
        added: groupsAdded,
        updated: groupsUpdated,
        unchanged: groupsUnchanged,
      ),
      snippets: KindCounts(
        added: snippetsAdded,
        updated: snippetsUpdated,
        unchanged: snippetsUnchanged,
      ),
      knownHostsAdded: pinsAdded,
      knownHostsUnchanged: pinsSame,
      knownHostsConflicting: pinsConflicting,
    );
  }

  /// The rows to write under [rule]. Everything in it is written in one
  /// transaction; see `JsonImportWriter`.
  JsonImportChanges resolve(ConflictRule rule) {
    // Groups first: hosts name them.
    final localGroupsById = {for (final g in local.groups) g.id: g};
    final localGroupByName = <String, HostGroup>{};
    for (final group in local.groups) {
      localGroupByName.putIfAbsent(group.name.toLowerCase(), () => group);
    }
    final groupIdMap = <String, String>{};
    final groups = <HostGroup>[];
    for (final group in source.groups) {
      final existing = localGroupsById[group.id];
      if (existing != null) {
        groupIdMap[group.id] = group.id;
        if (!_sameJson(
          PortableExport.groupJson(group),
          PortableExport.groupJson(existing),
        )) {
          groups.add(group);
        }
        continue;
      }
      final sameName = localGroupByName[group.name.toLowerCase()];
      if (sameName != null) {
        groupIdMap[group.id] = sameName.id;
        continue;
      }
      groupIdMap[group.id] = group.id;
      groups.add(group);
    }
    for (final group in local.groups) {
      groupIdMap.putIfAbsent(group.id, () => group.id);
    }

    // Which id each incoming host ends up under, decided before any host is
    // built, because a host's jump host may come later in the file.
    final hostIdMap = <String, String>{
      for (final host in local.hosts) host.id: host.id,
    };
    for (final row in hosts) {
      hostIdMap[row.incoming.id] =
          row.action == HostImportAction.conflict && rule == ConflictRule.merge
          ? row.existing!.id
          : row.incoming.id;
    }

    final hostsToWrite = <SshHost>[];
    for (final row in hosts) {
      if (row.action == HostImportAction.unchanged) continue;
      final existing = switch (row.action) {
        HostImportAction.update => row.existing,
        HostImportAction.conflict when rule == ConflictRule.merge =>
          row.existing,
        _ => null,
      };
      hostsToWrite.add(
        existing == null
            ? _remap(row.incoming, row.linkedIdentityId, hostIdMap, groupIdMap)
            : _mergeHost(
                incoming: row.incoming,
                existing: existing,
                linkedIdentityId: row.linkedIdentityId,
                references: (hosts: hostIdMap, groups: groupIdMap),
              ),
      );
    }

    // Tunnels follow their host. One whose host is neither in the file nor
    // here has nowhere to go and is left out; one that already exists on
    // that host in all but id is not duplicated.
    final localTunnelsById = {for (final t in local.tunnels) t.id: t};
    final tunnels = <Tunnel>[];
    var tunnelsSkipped = 0;
    for (final tunnel in source.tunnels) {
      final hostId = hostIdMap[tunnel.hostId];
      if (hostId == null) {
        tunnelsSkipped++;
        continue;
      }
      final moved = _withHost(tunnel, hostId);
      final existing = localTunnelsById[tunnel.id];
      if (existing != null) {
        if (!_sameJson(
          PortableExport.tunnelJson(moved),
          PortableExport.tunnelJson(existing),
        )) {
          tunnels.add(moved);
        }
        continue;
      }
      if (local.tunnels.any((t) => _sameForward(t, moved))) continue;
      tunnels.add(moved);
    }

    final localSnippetsById = {for (final s in local.snippets) s.id: s};
    final snippets = <Snippet>[];
    for (final snippet in source.snippets) {
      final existing = localSnippetsById[snippet.id];
      final write = existing == null
          ? !_hasSameSnippet(local.snippets, snippet)
          : !_sameJson(
              PortableExport.snippetJson(snippet),
              PortableExport.snippetJson(existing),
            );
      if (write) snippets.add(snippet);
    }

    final localPins = {for (final k in local.knownHosts) _pin(k)};
    final knownHosts = [
      for (final key in source.knownHosts)
        if (!localPins.contains(_pin(key))) key,
    ];

    return JsonImportChanges(
      groups: groups,
      hosts: hostsToWrite,
      tunnels: tunnels,
      snippets: snippets,
      knownHosts: knownHosts,
      tunnelsSkipped: tunnelsSkipped,
    );
  }

  // ---------------------------------------------------------------------------

  static String _address(SshHost host) =>
      '${host.username}@${host.hostname.toLowerCase()}:${host.port}';

  static String _pin(KnownHostKey key) => '${key.hostname}:${key.port}';

  static bool _sameJson(Map<String, Object?> a, Map<String, Object?> b) =>
      jsonEncode(a) == jsonEncode(b);

  static bool _sameHost(SshHost a, SshHost b) => _sameJson(
    PortableExport.hostJson(a, null),
    PortableExport.hostJson(b, null),
  );

  static bool _hasSameSnippet(List<Snippet> local, Snippet snippet) =>
      local.any((s) => s.label == snippet.label && s.body == snippet.body);

  static bool _sameForward(Tunnel a, Tunnel b) =>
      a.hostId == b.hostId &&
      a.kind == b.kind &&
      a.listenHost == b.listenHost &&
      a.listenPort == b.listenPort &&
      a.targetHost == b.targetHost &&
      a.targetPort == b.targetPort;

  /// [incoming] as written for a host that is new here: its references
  /// pointed at what they became, or cleared when they point nowhere.
  static SshHost _remap(
    SshHost incoming,
    String? linkedIdentityId,
    Map<String, String> hostIdMap,
    Map<String, String> groupIdMap,
  ) {
    final group = incoming.groupId == null
        ? null
        : groupIdMap[incoming.groupId];
    final jump = incoming.jumpHostId == null
        ? null
        : hostIdMap[incoming.jumpHostId];
    return incoming.copyWith(
      groupId: group,
      clearGroupId: group == null,
      identityId: linkedIdentityId,
      clearIdentityId: linkedIdentityId == null,
      jumpHostId: jump,
      clearJumpHostId: jump == null,
    );
  }

  /// The file's settings written onto [existing].
  ///
  /// The file wins for everything it can speak for. Two things it cannot:
  /// a key it names that this device lacks does not unlink the key the saved
  /// host already uses, and the most recent connection is whichever happened
  /// last.
  static SshHost _mergeHost({
    required SshHost incoming,
    required SshHost existing,
    required String? linkedIdentityId,
    ({Map<String, String> hosts, Map<String, String> groups})? references,
  }) {
    final remapped = references == null
        ? incoming
        : _remap(
            incoming,
            linkedIdentityId,
            references.hosts,
            references.groups,
          );
    final identity =
        linkedIdentityId ??
        (incoming.identityId == null ? null : existing.identityId);
    final group = remapped.groupId;
    final jump = remapped.jumpHostId;
    final lastA = incoming.lastConnectedAt;
    final lastB = existing.lastConnectedAt;
    final last = lastA == null
        ? lastB
        : lastB == null
        ? lastA
        : (lastA.isAfter(lastB) ? lastA : lastB);

    return SshHost(
      id: existing.id,
      label: incoming.label,
      hostname: incoming.hostname,
      port: incoming.port,
      username: incoming.username,
      authMethod: incoming.authMethod,
      groupId: group,
      identityId: identity,
      jumpHostId: jump == existing.id ? null : jump,
      allowLegacyAlgorithms: incoming.allowLegacyAlgorithms,
      forwardAgent: incoming.forwardAgent,
      tmuxMode: incoming.tmuxMode,
      keepaliveSeconds: incoming.keepaliveSeconds,
      startupCommand: incoming.startupCommand,
      terminalTheme: incoming.terminalTheme,
      fontSize: incoming.fontSize,
      notes: incoming.notes,
      tags: incoming.tags,
      envVars: incoming.envVars,
      lastConnectedAt: last,
      // Same id: the file's history is the host's history. Different id: the
      // saved host is the older record of this server.
      createdAt: incoming.id == existing.id
          ? incoming.createdAt
          : existing.createdAt,
      updatedAt: incoming.updatedAt,
    );
  }

  static Tunnel _withHost(Tunnel tunnel, String hostId) =>
      hostId == tunnel.hostId
      ? tunnel
      : Tunnel(
          id: tunnel.id,
          hostId: hostId,
          label: tunnel.label,
          kind: tunnel.kind,
          listenHost: tunnel.listenHost,
          listenPort: tunnel.listenPort,
          targetHost: tunnel.targetHost,
          targetPort: tunnel.targetPort,
          autoStart: tunnel.autoStart,
          createdAt: tunnel.createdAt,
          updatedAt: tunnel.updatedAt,
        );
}

/// Exactly what an import writes.
class JsonImportChanges {
  const JsonImportChanges({
    required this.groups,
    required this.hosts,
    required this.tunnels,
    required this.snippets,
    required this.knownHosts,
    this.tunnelsSkipped = 0,
  });

  final List<HostGroup> groups;
  final List<SshHost> hosts;
  final List<Tunnel> tunnels;
  final List<Snippet> snippets;
  final List<KnownHostKey> knownHosts;

  /// Forwards whose host is neither in the file nor on this device.
  final int tunnelsSkipped;

  bool get isEmpty =>
      groups.isEmpty &&
      hosts.isEmpty &&
      tunnels.isEmpty &&
      snippets.isEmpty &&
      knownHosts.isEmpty;
}

class _MissingBuilder {
  _MissingBuilder({
    required this.fingerprint,
    required this.label,
    required this.keyType,
  });

  final String? fingerprint;
  final String label;
  final String keyType;
  final List<String> hosts = [];

  MissingKey build() => MissingKey(
    fingerprint: fingerprint,
    label: label,
    keyType: keyType,
    hostLabels: List.unmodifiable(hosts),
  );
}
