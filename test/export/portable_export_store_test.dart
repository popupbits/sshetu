import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/export/data/portable_export_store.dart';
import 'package:sshetu/features/export/domain/json_import_plan.dart';
import 'package:sshetu/features/export/portable_export_service.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';

import '../support/test_database.dart';
import 'sample_config.dart';

/// Export and import against the real schema.
void main() {
  final exportTime = DateTime.utc(2026, 9, 22, 10);

  Future<
    ({AppDatabase db, ProviderContainer container, InMemorySecretVault vault})
  >
  open() async {
    final db = await openTestDatabase();
    final vault = InMemorySecretVault();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    return (db: db, container: container, vault: vault);
  }

  /// Writes the sample configuration through the app's own repositories.
  Future<void> seed(ProviderContainer c, {bool withIdentity = true}) async {
    await c.read(hostGroupRepositoryProvider).save(sampleGroup);
    if (withIdentity) {
      await c
          .read(identityRepositoryProvider)
          .save(identity, privateKey: 'PRIVATE KEY MATERIAL');
    }
    await c.read(hostRepositoryProvider).saveAll([
      withIdentity ? web : web.copyWith(clearIdentityId: true),
      bastion,
    ]);
    await c.read(tunnelRepositoryProvider).save(forward);
    await c.read(tunnelRepositoryProvider).save(socks);
    await c.read(snippetRepositoryProvider).save(snippet);
    await (await c.read(knownHostsProvider.future)).trust(pin);
  }

  Future<String> exportOf(ProviderContainer c) => c
      .read(portableExportControllerProvider)
      .exportText(appVersion: '1.0.0+1', now: exportTime);

  test('the export of a real database is the golden file', () async {
    final a = await open();
    await seed(a.container);
    expect(await exportOf(a.container), sampleExport(at: exportTime).encode());
  });

  test('no secret reaches the file', () async {
    final a = await open();
    await seed(a.container);
    await a.vault.write(SecretRef.hostPassword('h-bastion'), 'hunter2-secret');
    final text = await exportOf(a.container);
    expect(text, isNot(contains('PRIVATE KEY MATERIAL')));
    expect(text, isNot(contains('hunter2-secret')));
  });

  test('export, import, export: lossless, every field', () async {
    final a = await open();
    await seed(a.container);
    final first = await exportOf(a.container);

    // The receiving device already holds the key — by backup or transfer —
    // which is the only way an export's hosts can be linked to it.
    final b = await open();
    await b.container
        .read(identityRepositoryProvider)
        .save(identity, privateKey: 'PRIVATE KEY MATERIAL');

    final controller = b.container.read(portableExportControllerProvider);
    final plan = await controller.plan(first);
    expect(plan.newHosts, 2);
    expect(plan.missingKeys, isEmpty);
    await controller.apply(plan, ConflictRule.merge);

    expect(await exportOf(b.container), first);
  });

  test('a key saved under another id is linked by fingerprint', () async {
    final a = await open();
    await seed(a.container);
    final text = await exportOf(a.container);

    final b = await open();
    await b.container
        .read(identityRepositoryProvider)
        .save(
          SshIdentity(
            id: 'mine',
            label: 'same key',
            keyType: 'ssh-ed25519',
            publicKey: kPublicKey,
            fingerprint: identity.fingerprint,
            createdAt: t0,
            updatedAt: t0,
          ),
        );
    final controller = b.container.read(portableExportControllerProvider);
    await controller.apply(await controller.plan(text), ConflictRule.merge);

    final saved = await b.container.read(hostRepositoryProvider).byId('h-web');
    expect(saved!.identityId, 'mine');
  });

  test('a missing key: the host is imported without it', () async {
    final a = await open();
    await seed(a.container);
    final text = await exportOf(a.container);

    final b = await open();
    final controller = b.container.read(portableExportControllerProvider);
    final plan = await controller.plan(text);
    expect(plan.missingKeys.single.label, 'laptop');
    await controller.apply(plan, ConflictRule.merge);

    final saved = await b.container.read(hostRepositoryProvider).byId('h-web');
    expect(saved!.identityId, isNull);
    expect(await b.container.read(identityRepositoryProvider).all(), isEmpty);
  });

  test('updating a host by id keeps its tunnels', () async {
    // The regression this guards: INSERT OR REPLACE on a host deletes the
    // row first, and the cascade takes its tunnels with it.
    final a = await open();
    await seed(a.container);
    // A raw UPDATE, so the setup cannot itself be what deletes a tunnel.
    await a.db.raw.update(
      'hosts',
      {'label': 'renamed here'},
      where: 'id = ?',
      whereArgs: ['h-web'],
    );

    final controller = a.container.read(portableExportControllerProvider);
    final plan = await controller.plan(sampleExport().encode());
    expect(plan.updatedHosts, 1);
    await controller.apply(plan, ConflictRule.merge);

    final tunnels = await a.container.read(tunnelRepositoryProvider).all();
    expect(tunnels.map((t) => t.id), unorderedEquals(['t-db', 't-socks']));
    expect(
      (await a.container.read(hostRepositoryProvider).byId('h-web'))!.label,
      'web-1',
    );
  });

  test('merge and add-as-new against a host saved under another id', () async {
    for (final rule in ConflictRule.values) {
      final b = await open();
      await b.container
          .read(hostRepositoryProvider)
          .save(
            _withId(
              web.copyWith(
                label: 'mine',
                clearGroupId: true,
                clearJumpHostId: true,
              ),
              'local-web',
            ),
          );
      final controller = b.container.read(portableExportControllerProvider);
      final plan = await controller.plan(sampleExport().encode());
      expect(plan.conflicts, 1, reason: rule.name);
      await controller.apply(plan, rule);

      final hosts = await b.container.read(hostRepositoryProvider).all();
      final ids = hosts.map((h) => h.id).toSet();
      if (rule == ConflictRule.merge) {
        expect(ids, {'local-web', 'h-bastion'});
        expect(hosts.firstWhere((h) => h.id == 'local-web').label, 'web-1');
      } else {
        expect(ids, {'local-web', 'h-web', 'h-bastion'});
        expect(hosts.firstWhere((h) => h.id == 'local-web').label, 'mine');
      }
    }
  });

  test('the write is one transaction', () async {
    final a = await open();
    final store = PortableExportStore(
      database: a.db.raw,
      hosts: a.container.read(hostRepositoryProvider),
      groups: a.container.read(hostGroupRepositoryProvider),
      identities: a.container.read(identityRepositoryProvider),
      tunnels: a.container.read(tunnelRepositoryProvider),
      snippets: a.container.read(snippetRepositoryProvider),
      knownHosts: await a.container.read(knownHostsProvider.future),
    );
    final changes = JsonImportChanges(
      groups: const [],
      hosts: [bastion],
      // A tunnel whose host exists nowhere fails the foreign key...
      tunnels: [_withHost(forward, 'nowhere')],
      snippets: const [],
      knownHosts: const [],
    );
    await expectLater(
      PortableExportStore.apply(a.db.raw, changes),
      throwsA(anything),
    );
    // ...and takes the host written before it down too.
    expect(await store.hosts.all(), isEmpty);
  });
}

SshHost _withId(SshHost h, String id) => SshHost(
  id: id,
  label: h.label,
  hostname: h.hostname,
  port: h.port,
  username: h.username,
  authMethod: h.authMethod,
  groupId: h.groupId,
  jumpHostId: h.jumpHostId,
  createdAt: h.createdAt,
  updatedAt: h.updatedAt,
);

Tunnel _withHost(Tunnel t, String hostId) => Tunnel(
  id: t.id,
  hostId: hostId,
  label: t.label,
  kind: t.kind,
  listenPort: t.listenPort,
  targetHost: t.targetHost,
  targetPort: t.targetPort,
  createdAt: t.createdAt,
  updatedAt: t.updatedAt,
);
