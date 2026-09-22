import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/hosts/data/host_repository.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/keys/data/identity_repository.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/transfer/domain/transfer_payload.dart';
import 'package:sshetu/features/tunnels/data/tunnel_repository.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';

import '../support/test_database.dart';

/// Saving a row that other rows point at must leave those rows alone.
///
/// Every repository once saved with `INSERT OR REPLACE`, whose hidden DELETE
/// fires the foreign keys: editing a host erased its tunnels, editing a key
/// unlinked every host using it, and saving a bastion that others jump
/// through failed on ON DELETE RESTRICT. These pin each one.
void main() {
  late AppDatabase database;
  late HostRepository hosts;
  late TunnelRepository tunnels;
  late IdentityRepository identities;
  final now = DateTime.utc(2026, 9, 22);

  setUp(() async {
    database = await openTestDatabase();
    final vault = InMemorySecretVault();
    hosts = HostRepository(database: database.raw, vault: vault);
    tunnels = TunnelRepository(database: database.raw);
    identities = IdentityRepository(database: database.raw, vault: vault);
  });

  tearDown(() => database.close());

  SshHost host(String id, {String? jumpHostId, String? identityId}) => SshHost(
    id: id,
    label: id,
    hostname: '$id.example.com',
    username: 'deploy',
    jumpHostId: jumpHostId,
    identityId: identityId,
    createdAt: now,
    updatedAt: now,
  );

  Tunnel tunnel(String id, String hostId) => Tunnel(
    id: id,
    hostId: hostId,
    label: id,
    kind: TunnelKind.local,
    listenPort: 8080,
    targetHost: '127.0.0.1',
    targetPort: 80,
    createdAt: now,
    updatedAt: now,
  );

  test('editing a host keeps its tunnels', () async {
    await hosts.save(host('h1'));
    await tunnels.save(tunnel('t1', 'h1'));

    await hosts.save(host('h1').copyWith(label: 'renamed'));

    expect((await hosts.byId('h1'))!.label, 'renamed');
    expect(await tunnels.forHost('h1'), hasLength(1));
  });

  test('editing a bastion that other hosts jump through succeeds', () async {
    await hosts.save(host('bastion'));
    await hosts.save(host('inner', jumpHostId: 'bastion'));

    await hosts.save(host('bastion').copyWith(label: 'renamed bastion'));

    expect((await hosts.byId('bastion'))!.label, 'renamed bastion');
    expect((await hosts.byId('inner'))!.jumpHostId, 'bastion');
  });

  test('saveAll over existing hosts keeps their tunnels', () async {
    await hosts.save(host('h1'));
    await tunnels.save(tunnel('t1', 'h1'));

    await hosts.saveAll([host('h1').copyWith(label: 'again')]);

    expect(await tunnels.forHost('h1'), hasLength(1));
  });

  test('editing a key keeps the hosts that use it linked', () async {
    final key = SshIdentity(
      id: 'k1',
      label: 'laptop',
      keyType: 'ssh-ed25519',
      createdAt: now,
      updatedAt: now,
    );
    await identities.save(key);
    await hosts.save(host('h1', identityId: 'k1'));

    await identities.save(key.copyWith(label: 'renamed key'));

    expect((await hosts.byId('h1'))!.identityId, 'k1');
  });

  test('receiving a transfer twice keeps this device\'s own tunnels and '
      'accepts a bastion listed after the host behind it', () async {
    // Here: a host with a tunnel the other device never had.
    await hosts.save(host('h1'));
    await tunnels.save(tunnel('local-only', 'h1'));

    Map<String, Object?> row(SshHost h) => {...HostRepository.rowOf(h)};
    final payload = TransferPayload(
      schemaVersion: TransferPayload.oldestApplicableSchema,
      tables: {
        // The inner host first: its bastion arrives later in the list.
        'hosts': [
          row(host('inner', jumpHostId: 'h1')),
          row(host('h1').copyWith(label: 'from the other device')),
        ],
      },
      secrets: const {},
    );

    await payload.apply(database.raw, vault: InMemorySecretVault());
    await payload.apply(database.raw, vault: InMemorySecretVault());

    expect((await hosts.byId('h1'))!.label, 'from the other device');
    expect((await hosts.byId('inner'))!.jumpHostId, 'h1');
    expect(await tunnels.forHost('h1'), hasLength(1));
  });
}
