import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/transfer/domain/transfer_payload.dart';

import '../support/test_database.dart';

/// What travels between two devices, against the real schema.
///
/// The payload is rows rather than domain objects, so the thing worth testing
/// is that a real database can be read out of one and into another with
/// nothing lost — including a column nobody remembered to think about.
void main() {
  late AppDatabase source;
  late AppDatabase destination;
  late InMemorySecretVault sourceVault;
  late InMemorySecretVault destinationVault;

  setUp(() async {
    source = await openTestDatabase();
    destination = await openTestDatabase();
    sourceVault = InMemorySecretVault();
    destinationVault = InMemorySecretVault();
  });

  tearDown(() async {
    await source.raw.close();
    await destination.raw.close();
  });

  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> seed() async {
    await source.raw.insert('host_groups', {
      'id': 'g1',
      'name': 'Production',
      'sort_order': 0,
      'created_at': now,
      'updated_at': now,
    });
    await source.raw.insert('identities', {
      'id': 'k1',
      'label': 'laptop',
      'key_type': 'ssh-ed25519',
      'fingerprint': 'SHA256:abc',
      'has_passphrase': 0,
      'origin': 'generated',
      'created_at': now,
      'updated_at': now,
    });
    await source.raw.insert('hosts', {
      'id': 'h1',
      'group_id': 'g1',
      'label': 'web',
      'hostname': 'web.example.com',
      'port': 22,
      'username': 'root',
      'auth_method': 'publicKey',
      'identity_id': 'k1',
      'allow_legacy_algorithms': 0,
      'keepalive_seconds': 30,
      'notes': 'the one behind the bastion',
      'created_at': now,
      'updated_at': now,
    });
    await source.raw.insert('tunnels', {
      'id': 't1',
      'host_id': 'h1',
      'label': 'postgres',
      'kind': 'local',
      'listen_host': '127.0.0.1',
      'listen_port': 5432,
      'target_host': 'db.internal',
      'target_port': 5432,
      'auto_start': 0,
      'created_at': now,
      'updated_at': now,
    });
    await source.raw.insert('known_hosts', {
      'hostname': 'web.example.com',
      'port': 22,
      'key_type': 'ssh-ed25519',
      'fingerprint': 'SHA256:server',
      'trusted_at': now,
    });

    await sourceVault.write(SecretRef.identityPrivateKey('k1'), 'PRIVATE-KEY');
    await sourceVault.write(SecretRef.hostPassword('h1'), 'hunter2');
  }

  test('a whole configuration crosses intact', () async {
    await seed();

    final payload = await (await TransferPayload.read(
      source.raw,
      includeSecrets: true,
    )).withSecrets(sourceVault);
    await payload.apply(destination.raw, vault: destinationVault);

    final hosts = await destination.raw.query('hosts');
    expect(hosts, hasLength(1));
    expect(hosts.single['hostname'], 'web.example.com');
    // Every column, not just the ones a hand-written mapper would remember.
    expect(hosts.single['notes'], 'the one behind the bastion');
    expect(hosts.single['group_id'], 'g1');
    expect(hosts.single['identity_id'], 'k1');

    expect(await destination.raw.query('tunnels'), hasLength(1));
    expect(await destination.raw.query('identities'), hasLength(1));
    expect(await destination.raw.query('host_groups'), hasLength(1));
  });

  test('trusted host keys travel', () async {
    // Carried on purpose: re-verifying a fingerprint from a café is worse
    // than importing one that was verified at home.
    await seed();

    final payload = await (await TransferPayload.read(
      source.raw,
      includeSecrets: false,
    )).withSecrets(sourceVault);
    await payload.apply(destination.raw, vault: destinationVault);

    expect(payload.knownHostCount, 1);
    expect(await destination.raw.query('known_hosts'), hasLength(1));
  });

  test('secrets travel only when asked for', () async {
    await seed();

    final without = await (await TransferPayload.read(
      source.raw,
      includeSecrets: false,
    )).withSecrets(sourceVault);
    expect(without.secrets, isEmpty);

    final with_ = await (await TransferPayload.read(
      source.raw,
      includeSecrets: true,
    )).withSecrets(sourceVault);
    expect(with_.secrets, hasLength(2));
  });

  test('a private key lands in the slot that reads it back', () async {
    // The failure this catches is silent: a wrong storage key writes the key
    // somewhere nothing looks, and the host just asks for a password forever.
    await seed();

    final payload = await (await TransferPayload.read(
      source.raw,
      includeSecrets: true,
    )).withSecrets(sourceVault);
    await payload.apply(destination.raw, vault: destinationVault);

    expect(
      await destinationVault.read(SecretRef.identityPrivateKey('k1')),
      'PRIVATE-KEY',
    );
    expect(
      await destinationVault.read(SecretRef.hostPassword('h1')),
      'hunter2',
    );
  });

  test('a deleted host is not sent', () async {
    await seed();
    await source.raw.update(
      'hosts',
      {'deleted_at': now},
      where: 'id = ?',
      whereArgs: ['h1'],
    );

    final payload = await (await TransferPayload.read(
      source.raw,
      includeSecrets: false,
    )).withSecrets(sourceVault);

    expect(payload.hostCount, 0);
  });

  test('sending twice is not sending double', () async {
    await seed();
    final payload = await (await TransferPayload.read(
      source.raw,
      includeSecrets: true,
    )).withSecrets(sourceVault);

    await payload.apply(destination.raw, vault: destinationVault);
    await payload.apply(destination.raw, vault: destinationVault);

    expect(await destination.raw.query('hosts'), hasLength(1));
    expect(await destination.raw.query('tunnels'), hasLength(1));
  });

  test('a schema mismatch is refused with something actionable', () async {
    await seed();
    final payload = await (await TransferPayload.read(
      source.raw,
      includeSecrets: false,
    )).withSecrets(sourceVault);
    final fromTheFuture = TransferPayload(
      schemaVersion: payload.schemaVersion + 5,
      tables: payload.tables,
      secrets: const {},
    );

    expect(
      () => fromTheFuture.apply(destination.raw, vault: destinationVault),
      throwsA(
        isA<TransferPayloadException>().having(
          (e) => e.message,
          'message',
          contains('Update SSHetu on both'),
        ),
      ),
    );
  });

  test('the payload survives JSON, which is how it travels', () async {
    await seed();
    final original = await (await TransferPayload.read(
      source.raw,
      includeSecrets: true,
    )).withSecrets(sourceVault);

    final restored = TransferPayload.fromJson(original.toJson());
    await restored.apply(destination.raw, vault: destinationVault);

    expect(await destination.raw.query('hosts'), hasLength(1));
    expect(
      await destinationVault.read(SecretRef.identityPrivateKey('k1')),
      'PRIVATE-KEY',
    );
  });

  test('a malformed payload is refused rather than half-applied', () {
    expect(
      () => TransferPayload.fromJson({'nothing': 'useful'}),
      throwsA(isA<TransferPayloadException>()),
    );
  });
}
