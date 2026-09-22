import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/hosts/data/host_group_repository.dart';
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

  test('re-sending keeps hosts in their groups', () async {
    // `apply` replaces by id, and REPLACE deletes the old row first — which
    // fires `hosts.group_id ON DELETE SET NULL`. The hosts are re-inserted
    // after the groups, so they must come out filed, not orphaned.
    await seed();
    final payload = await TransferPayload.read(
      source.raw,
      includeSecrets: false,
    );

    await payload.apply(destination.raw, vault: destinationVault);
    await payload.apply(destination.raw, vault: destinationVault);

    final host = (await destination.raw.query('hosts')).single;
    expect(host['group_id'], 'g1');
    expect(await destination.raw.query('host_groups'), hasLength(1));
  });

  test(
    'a deleted group does not travel, and its hosts arrive unfiled',
    () async {
      await seed();
      await HostGroupRepository(database: source.raw)
          .delete('g1', now: DateTime.utc(2026, 2));

      final payload = await TransferPayload.read(
        source.raw,
        includeSecrets: false,
      );
      await payload.apply(destination.raw, vault: destinationVault);

      expect(await destination.raw.query('host_groups'), isEmpty);
      final host = (await destination.raw.query('hosts')).single;
      expect(host['group_id'], isNull);
    },
  );

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

  group('snippets', () {
    Future<void> seedSnippets() async {
      await source.raw.insert('snippets', {
        'id': 's1',
        'label': 'Tail logs',
        'body': 'cd {{dir:/var/log}}\ntail -f syslog',
        'description': 'follow it',
        'tags': 'logs,ops',
        'sort_order': 2,
        'created_at': now,
        'updated_at': now,
      });
      await source.raw.insert('snippets', {
        'id': 's-deleted',
        'label': 'gone',
        'body': 'true',
        'created_at': now,
        'updated_at': now,
        'deleted_at': now,
      });
    }

    test('travel with every column, and tombstones stay behind', () async {
      await seed();
      await seedSnippets();

      final payload = await TransferPayload.read(
        source.raw,
        includeSecrets: false,
      );
      expect(payload.snippetCount, 1);

      // Through JSON, the way it actually crosses.
      await TransferPayload.fromJson(payload.toJson())
          .apply(destination.raw, vault: destinationVault);

      final rows = await destination.raw.query('snippets');
      expect(rows, hasLength(1));
      expect(rows.single, {
        'id': 's1',
        'label': 'Tail logs',
        'body': 'cd {{dir:/var/log}}\ntail -f syslog',
        'description': 'follow it',
        'tags': 'logs,ops',
        'sort_order': 2,
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      });
    });

    test('replace by id, like every other row', () async {
      await seedSnippets();
      await destination.raw.insert('snippets', {
        'id': 's1',
        'label': 'older copy',
        'body': 'ls',
        'created_at': now,
        'updated_at': now,
      });

      await (await TransferPayload.read(
        source.raw,
        includeSecrets: false,
      )).apply(destination.raw, vault: destinationVault);

      final rows = await destination.raw.query('snippets');
      expect(rows.single['label'], 'Tail logs');
    });

    test('a payload from before snippets still applies', () async {
      // A v4 backup has no snippets table at all. Refusing it would strand
      // every backup written before this update.
      await seed();
      final current = await TransferPayload.read(
        source.raw,
        includeSecrets: false,
      );
      final json = current.toJson();
      final tables = Map<String, Object?>.from(json['tables']! as Map)
        ..remove('snippets');
      final fromV4 = TransferPayload.fromJson({
        ...json,
        'schema': 4,
        'tables': tables,
      });

      await destination.raw.insert('snippets', {
        'id': 'mine',
        'label': 'already here',
        'body': 'uptime',
        'created_at': now,
        'updated_at': now,
      });
      await fromV4.apply(destination.raw, vault: destinationVault);

      expect(await destination.raw.query('hosts'), hasLength(1));
      // "No snippets sent" is not "delete the snippets that are here".
      expect(await destination.raw.query('snippets'), hasLength(1));
    });

    test('a payload older than transfer itself is refused', () {
      final ancient = TransferPayload(
        schemaVersion: TransferPayload.oldestApplicableSchema - 1,
        tables: const {},
        secrets: const {},
      );
      expect(
        () => ancient.apply(destination.raw, vault: destinationVault),
        throwsA(isA<TransferPayloadException>()),
      );
    });
  });

  group('host columns added in v6: env_vars, forward_agent', () {
    test('travel with the host', () async {
      await seed();
      await source.raw.update('hosts', {
        'env_vars': '{"EDITOR":"vim","MSG":"it\'s \$HOME"}',
        'forward_agent': 1,
      }, where: "id = 'h1'");

      final payload = await TransferPayload.read(
        source.raw,
        includeSecrets: false,
      );
      await TransferPayload.fromJson(payload.toJson())
          .apply(destination.raw, vault: destinationVault);

      final row = (await destination.raw.query('hosts')).single;
      expect(row['env_vars'], '{"EDITOR":"vim","MSG":"it\'s \$HOME"}');
      expect(row['forward_agent'], 1);
    });

    test('a v5 payload, whose hosts lack both columns, still applies', () {
      // A nullable column, and a NOT NULL one with a default, leave every
      // older row insertable, so v5 payloads — every backup written before
      // this update — stay within the applicable range.
      expect(TransferPayload.canApply(5), isTrue);
      expect(TransferPayload.oldestApplicableSchema, lessThanOrEqualTo(5));
    });

    test('...and lands with no variables and no agent forwarding', () async {
      await seed();
      final current = await TransferPayload.read(
        source.raw,
        includeSecrets: false,
      );
      final json = current.toJson();
      final tables = Map<String, Object?>.from(json['tables']! as Map);
      tables['hosts'] = [
        for (final row in tables['hosts']! as List)
          Map<String, Object?>.from(row as Map)
            ..remove('env_vars')
            ..remove('forward_agent'),
      ];
      final fromV5 = TransferPayload.fromJson({
        ...json,
        'schema': 5,
        'tables': tables,
      });

      await fromV5.apply(destination.raw, vault: destinationVault);

      final row = (await destination.raw.query('hosts')).single;
      expect(row['hostname'], 'web.example.com');
      expect(row['env_vars'], isNull);
      expect(row['forward_agent'], 0);
    });
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
