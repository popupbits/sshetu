import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/host_key.dart';
import 'package:sshetu/features/export/domain/json_import_plan.dart';
import 'package:sshetu/features/export/domain/portable_export.dart';
import 'package:sshetu/features/hosts/domain/host_group.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';

import 'sample_config.dart';

PortableExport device({
  List<HostGroup> groups = const [],
  List<SshIdentity> identities = const [],
  List<SshHost> hosts = const [],
  List<Tunnel> tunnels = const [],
  List<KnownHostKey> knownHosts = const [],
}) => PortableExport(
  exportedAt: t2,
  app: '',
  groups: groups,
  identities: identities,
  hosts: hosts,
  tunnels: tunnels,
  knownHosts: knownHosts,
);

void main() {
  test('into an empty device, everything is new', () {
    final plan = JsonImportPlan.build(source: sampleExport(), local: device());
    expect(plan.newHosts, 2);
    expect(plan.updatedHosts + plan.unchangedHosts + plan.conflicts, 0);
    expect(plan.groups.added, 1);
    expect(plan.snippets.added, 1);
    expect(plan.knownHostsAdded, 1);

    final changes = plan.resolve(ConflictRule.merge);
    expect(
      changes.hosts.map((h) => h.id),
      unorderedEquals(['h-web', 'h-bastion']),
    );
    expect(changes.tunnels, hasLength(2));
    // The file names a key this device lacks: imported without it.
    expect(changes.hosts.firstWhere((h) => h.id == 'h-web').identityId, isNull);
    expect(plan.missingKeys.single.fingerprint, identity.fingerprint);
    expect(plan.missingKeys.single.hostLabels, ['web-1']);
    // Every other reference survives.
    final webHost = changes.hosts.firstWhere((h) => h.id == 'h-web');
    expect(webHost.jumpHostId, 'h-bastion');
    expect(webHost.groupId, 'g-work');
  });

  test('importing the same configuration again changes nothing', () {
    final plan = JsonImportPlan.build(
      source: sampleExport(),
      local: sampleExport(),
    );
    expect(plan.unchangedHosts, 2);
    expect(plan.isEmpty, isTrue);
    expect(plan.resolve(ConflictRule.merge).isEmpty, isTrue);
    expect(plan.missingKeys, isEmpty);
  });

  test('the same id with different settings is an update, not a conflict', () {
    final local = device(
      identities: [identity],
      hosts: [
        web.copyWith(label: 'old name', port: 2200),
        bastion,
      ],
    );
    final plan = JsonImportPlan.build(source: sampleExport(), local: local);
    expect(plan.updatedHosts, 1);
    expect(plan.unchangedHosts, 1);
    expect(plan.conflicts, 0);
    final written = plan.resolve(ConflictRule.addAsNew).hosts.single;
    expect(written.id, 'h-web');
    expect(written.label, 'web-1');
    expect(written.port, 22);
  });

  group('a host saved under another id at the same address', () {
    final savedHere = SshHost(
      id: 'local-web',
      label: 'my web box',
      hostname: 'WEB1.internal',
      username: 'deploy',
      notes: 'kept here',
      lastConnectedAt: DateTime.utc(2027),
      createdAt: DateTime.utc(2025),
      updatedAt: DateTime.utc(2025),
    );
    final localTunnel = Tunnel(
      id: 'local-tunnel',
      hostId: 'local-web',
      label: 'mine',
      kind: TunnelKind.local,
      listenPort: 8080,
      targetHost: 'localhost',
      targetPort: 80,
      createdAt: t0,
      updatedAt: t0,
    );
    JsonImportPlan plan() => JsonImportPlan.build(
      source: sampleExport(),
      local: device(hosts: [savedHere], tunnels: [localTunnel]),
    );

    test('is a conflict', () {
      expect(plan().conflicts, 1);
      expect(plan().conflictRows.single.existing!.id, 'local-web');
      expect(plan().newHosts, 1);
    });

    test('merge updates the saved host and keeps its id', () {
      final changes = plan().resolve(ConflictRule.merge);
      final merged = changes.hosts.firstWhere(
        (h) => h.hostname == 'web1.internal',
      );
      expect(merged.id, 'local-web');
      expect(merged.label, 'web-1');
      expect(merged.notes, web.notes);
      expect(merged.envVars, web.envVars);
      // History: the older record's creation, the later connection.
      expect(merged.createdAt, DateTime.utc(2025));
      expect(merged.lastConnectedAt, DateTime.utc(2027));
      expect(changes.hosts.where((h) => h.id == 'h-web'), isEmpty);
      // The file's tunnel moves onto the saved host.
      final moved = changes.tunnels.firstWhere((t) => t.id == 't-db');
      expect(moved.hostId, 'local-web');
    });

    test('add as new keeps both', () {
      final changes = plan().resolve(ConflictRule.addAsNew);
      expect(changes.hosts.map((h) => h.id), contains('h-web'));
      expect(changes.hosts.map((h) => h.id), isNot(contains('local-web')));
      expect(changes.tunnels.firstWhere((t) => t.id == 't-db').hostId, 'h-web');
    });

    test('a jump host that merged is followed to its new id', () {
      final localBastion = bastion.copyWith();
      final renamed = SshHost(
        id: 'local-bastion',
        label: 'b',
        hostname: localBastion.hostname,
        port: localBastion.port,
        username: localBastion.username,
        createdAt: t0,
        updatedAt: t0,
      );
      final changes = JsonImportPlan.build(
        source: sampleExport(),
        local: device(hosts: [renamed]),
      ).resolve(ConflictRule.merge);
      expect(
        changes.hosts.firstWhere((h) => h.id == 'h-web').jumpHostId,
        'local-bastion',
      );
    });
  });

  group('keys are linked by fingerprint', () {
    test('to a key saved here under a different id', () {
      final sameKey = SshIdentity(
        id: 'another-id',
        label: 'same key, other device',
        keyType: 'ssh-ed25519',
        publicKey: kPublicKey,
        createdAt: t0,
        updatedAt: t0,
      );
      final plan = JsonImportPlan.build(
        source: sampleExport(),
        local: device(identities: [sameKey]),
      );
      expect(plan.missingKeys, isEmpty);
      final webHost = plan
          .resolve(ConflictRule.merge)
          .hosts
          .firstWhere((h) => h.id == 'h-web');
      expect(webHost.identityId, 'another-id');
    });

    test('never to a different key that happens to share the id', () {
      final impostor = SshIdentity(
        id: 'k-laptop',
        label: 'different key',
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:somethingelse',
        createdAt: t0,
        updatedAt: t0,
      );
      final plan = JsonImportPlan.build(
        source: sampleExport(),
        local: device(identities: [impostor]),
      );
      expect(plan.missingKeys, hasLength(1));
      expect(
        plan
            .resolve(ConflictRule.merge)
            .hosts
            .firstWhere((h) => h.id == 'h-web')
            .identityId,
        isNull,
      );
    });

    test('an update never unlinks the key a saved host already uses', () {
      final local = device(
        hosts: [
          web.copyWith(identityId: 'k-local', label: 'x'),
          bastion,
        ],
      );
      // The device has no identity with the file's fingerprint.
      final written = JsonImportPlan.build(
        source: sampleExport(),
        local: local,
      ).resolve(ConflictRule.merge).hosts.single;
      expect(written.identityId, 'k-local');
    });
  });

  test('a group with the same name is reused', () {
    final mine = HostGroup(
      id: 'my-work',
      name: 'work',
      createdAt: t0,
      updatedAt: t0,
    );
    final plan = JsonImportPlan.build(
      source: sampleExport(),
      local: device(groups: [mine]),
    );
    final changes = plan.resolve(ConflictRule.merge);
    expect(changes.groups, isEmpty);
    expect(changes.hosts.firstWhere((h) => h.id == 'h-web').groupId, 'my-work');
  });

  test('a trusted key here is never replaced by the file', () {
    final mine = KnownHostKey(
      hostname: pin.hostname,
      port: pin.port,
      keyType: 'ssh-ed25519',
      fingerprint: 'SHA256:mine',
      trustedAt: t0,
    );
    final plan = JsonImportPlan.build(
      source: sampleExport(),
      local: device(knownHosts: [mine]),
    );
    expect(plan.knownHostsConflicting, 1);
    expect(plan.knownHostsAdded, 0);
    expect(plan.resolve(ConflictRule.merge).knownHosts, isEmpty);
  });

  test('a tunnel with no host anywhere is left out', () {
    final source = PortableExport(
      exportedAt: t0,
      app: '',
      tunnels: [forward.copyWith()],
    );
    final changes = JsonImportPlan.build(
      source: source,
      local: device(),
    ).resolve(ConflictRule.merge);
    expect(changes.tunnels, isEmpty);
    expect(changes.tunnelsSkipped, 1);
  });
}
