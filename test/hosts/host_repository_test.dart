import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/db/database.dart';
import 'package:ssh_navigator/core/secrets/secret_ref.dart';
import 'package:ssh_navigator/core/secrets/secret_vault.dart';
import 'package:ssh_navigator/core/ssh/ssh_target.dart';
import 'package:ssh_navigator/features/hosts/data/host_repository.dart';
import 'package:ssh_navigator/features/hosts/domain/ssh_host.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretVault vault;
  late HostRepository repository;

  final now = DateTime.utc(2026, 1, 1);

  setUp(() async {
    database = await openTestDatabase();
    vault = InMemorySecretVault();
    repository = HostRepository(database: database.raw, vault: vault);
  });

  tearDown(() => database.close());

  SshHost host(
    String id, {
    String? jumpHostId,
    DateTime? lastConnectedAt,
    String label = 'box',
  }) => SshHost(
    id: id,
    label: label,
    hostname: '$id.example.com',
    username: 'deploy',
    jumpHostId: jumpHostId,
    lastConnectedAt: lastConnectedAt,
    createdAt: now,
    updatedAt: now,
  );

  group('round trip', () {
    test('a saved host reads back with every field intact', () async {
      await repository.save(
        SshHost(
          id: 'h1',
          label: 'build box',
          hostname: 'build.example.com',
          port: 2222,
          username: 'ci',
          authMethod: SshAuthMethod.password,
          allowLegacyAlgorithms: true,
          startupCommand: 'tmux new -A -s main',
          keepaliveSeconds: 15,
          tags: const ['prod', 'eu'],
          createdAt: now,
          updatedAt: now,
        ),
      );

      final loaded = (await repository.byId('h1'))!;
      expect(loaded.label, 'build box');
      expect(loaded.port, 2222);
      expect(loaded.authMethod, SshAuthMethod.password);
      expect(loaded.allowLegacyAlgorithms, isTrue);
      expect(loaded.startupCommand, 'tmux new -A -s main');
      expect(loaded.keepaliveSeconds, 15);
      expect(loaded.tags, ['prod', 'eu']);
    });

    test('a host with no tags reads back with an empty list, not [""]', () async {
      // The join/split round trip is the classic place an empty string becomes
      // a phantom tag that then shows up as a blank chip in the UI.
      await repository.save(host('h1'));
      expect((await repository.byId('h1'))!.tags, isEmpty);
    });
  });

  group('listing', () {
    test('is ordered by recency, so the host you want is at the top', () async {
      await repository.save(host('old', lastConnectedAt: DateTime.utc(2025)));
      await repository.save(host('recent', lastConnectedAt: DateTime.utc(2026)));
      await repository.save(host('never'));

      final ids = (await repository.all()).map((h) => h.id).toList();
      expect(ids.first, 'recent');
      expect(ids, containsAll(['recent', 'old', 'never']));
    });
  });

  group('delete', () {
    test('tombstones the row rather than removing it', () async {
      await repository.save(host('h1'));
      await repository.delete('h1', now: now);

      expect(await repository.byId('h1'), isNull);
      // Still physically present, so the deletion can be synced. A row that
      // vanishes without trace reappears from whichever device missed it.
      final raw = await database.raw.query('hosts', where: "id = 'h1'");
      expect(raw, hasLength(1));
      expect(raw.single['deleted_at'], isNotNull);
    });

    test('destroys the saved password for real', () async {
      await repository.save(host('h1'));
      await vault.write(const SecretRef.hostPassword('h1'), 'hunter2');

      await repository.delete('h1', now: now);

      expect(
        await vault.contains(const SecretRef.hostPassword('h1')),
        isFalse,
        reason: 'keeping a credential for a deleted host is the wrong half '
            'to remember',
      );
    });
  });

  group('targetFor', () {
    test('a direct host has no jump', () async {
      await repository.save(host('h1'));
      final target = await repository.targetFor((await repository.byId('h1'))!);
      expect(target.jumpTarget, isNull);
      expect(target.chain, hasLength(1));
    });

    test('resolves a chain in dial order', () async {
      await repository.save(host('edge'));
      await repository.save(host('bastion', jumpHostId: 'edge'));
      await repository.save(host('db', jumpHostId: 'bastion'));

      final target = await repository.targetFor((await repository.byId('db'))!);

      expect(
        target.chain.map((t) => t.hostname).toList(),
        ['edge.example.com', 'bastion.example.com', 'db.example.com'],
      );
    });

    test('carries the host id so its secrets can be found', () async {
      await repository.save(host('h1'));
      final target = await repository.targetFor((await repository.byId('h1'))!);
      expect(target.credentialId, 'h1');
    });

    test('breaks a jump cycle instead of recursing forever', () async {
      // Reachable by hand or by a bad import. A stack overflow is a much worse
      // way to learn about a typo than simply connecting.
      await repository.save(host('a'));
      await repository.save(host('b', jumpHostId: 'a'));
      await database.raw.update(
        'hosts',
        {'jump_host_id': 'b'},
        where: "id = 'a'",
      );

      final target = await repository.targetFor((await repository.byId('b'))!);

      expect(target.chain.length, lessThanOrEqualTo(3));
      expect(target.hostname, 'b.example.com');
    });

    test('a jump host that was deleted stops the chain rather than throwing', () async {
      await repository.save(host('bastion'));
      await repository.save(host('db', jumpHostId: 'bastion'));
      // Tombstoned, so byId no longer finds it.
      await repository.delete('bastion', now: now);

      final target = await repository.targetFor(
        (await repository.byId('db'))!,
      );
      expect(target.jumpTarget, isNull);
    });
  });
}
