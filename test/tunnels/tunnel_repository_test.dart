import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/db/database.dart';
import 'package:ssh_navigator/core/secrets/secret_vault.dart';
import 'package:ssh_navigator/features/hosts/data/host_repository.dart';
import 'package:ssh_navigator/features/hosts/domain/ssh_host.dart';
import 'package:ssh_navigator/features/tunnels/data/tunnel_repository.dart';
import 'package:ssh_navigator/features/tunnels/domain/tunnel.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase database;
  late HostRepository hosts;
  late TunnelRepository repository;

  final now = DateTime.utc(2026, 1, 1);

  setUp(() async {
    database = await openTestDatabase();
    hosts = HostRepository(
      database: database.raw,
      vault: InMemorySecretVault(),
    );
    repository = TunnelRepository(database: database.raw);
    // Every tunnel needs a real host row — `host_id` is `NOT NULL REFERENCES
    // hosts (id)`, so saving one against a host that does not exist would
    // fail the foreign key rather than exercise anything interesting.
    await hosts.save(
      SshHost(
        id: 'h1',
        label: 'box',
        hostname: 'box.example.com',
        username: 'deploy',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => database.close());

  Tunnel tunnel(
    String id, {
    String hostId = 'h1',
    TunnelKind kind = TunnelKind.local,
    String label = 'db',
    String listenHost = Tunnel.defaultListenHost,
    int listenPort = 5432,
    String? targetHost = 'db.internal',
    int? targetPort = 5432,
    bool autoStart = false,
  }) => Tunnel(
    id: id,
    hostId: hostId,
    label: label,
    kind: kind,
    listenHost: listenHost,
    listenPort: listenPort,
    targetHost: kind.requiresTarget ? targetHost : null,
    targetPort: kind.requiresTarget ? targetPort : null,
    autoStart: autoStart,
    createdAt: now,
    updatedAt: now,
  );

  group('round trip', () {
    test('a saved tunnel reads back with every field intact', () async {
      await repository.save(
        tunnel(
          't1',
          kind: TunnelKind.remote,
          listenHost: '0.0.0.0',
          listenPort: 8080,
          targetHost: '127.0.0.1',
          targetPort: 3000,
          autoStart: true,
        ),
      );

      final loaded = (await repository.byId('t1'))!;
      expect(loaded.kind, TunnelKind.remote);
      expect(loaded.listenHost, '0.0.0.0');
      expect(loaded.listenPort, 8080);
      expect(loaded.targetHost, '127.0.0.1');
      expect(loaded.targetPort, 3000);
      expect(loaded.autoStart, isTrue);
    });

    test(
      'a SOCKS forward reads back with no target, not a stored "null" string',
      () async {
        await repository.save(tunnel('t1', kind: TunnelKind.socks));
        final loaded = (await repository.byId('t1'))!;
        expect(loaded.kind, TunnelKind.socks);
        expect(loaded.targetHost, isNull);
        expect(loaded.targetPort, isNull);
      },
    );

    test('a tunnel with no listen_host set defaults to loopback', () async {
      // Exercises the schema's own default, not just the Dart model's —
      // a row written by raw SQL (a future migration, a sync payload) has to
      // come back the same safe way a row written through this repository
      // does.
      await database.raw.insert('tunnels', {
        'id': 't1',
        'host_id': 'h1',
        'label': 'db',
        'kind': 'local',
        'listen_port': 5432,
        'target_host': 'db.internal',
        'target_port': 5432,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });
      final loaded = (await repository.byId('t1'))!;
      expect(loaded.listenHost, '127.0.0.1');
    });
  });

  group('forHost', () {
    test('only returns tunnels for that host', () async {
      await hosts.save(
        SshHost(
          id: 'h2',
          label: 'other',
          hostname: 'other.example.com',
          username: 'deploy',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.save(tunnel('t1', hostId: 'h1'));
      await repository.save(tunnel('t2', hostId: 'h2'));

      final forH1 = await repository.forHost('h1');
      expect(forH1.map((t) => t.id), ['t1']);
    });
  });

  group('delete', () {
    test('tombstones the row rather than removing it', () async {
      await repository.save(tunnel('t1'));
      await repository.delete('t1', now: now);

      expect(await repository.byId('t1'), isNull);
      // Present but tombstoned, so the delete itself can sync — a row that
      // vanishes without trace reappears from whichever device had not heard
      // about the delete yet.
      final raw = await database.raw.query('tunnels', where: "id = 't1'");
      expect(raw, hasLength(1));
      expect(raw.single['deleted_at'], isNotNull);
      expect(raw.single['dirty'], 1);
    });

    test('a tombstoned tunnel is absent from forHost and all', () async {
      await repository.save(tunnel('t1'));
      await repository.delete('t1', now: now);

      expect(await repository.forHost('h1'), isEmpty);
      expect(await repository.all(), isEmpty);
    });
  });

  group('cascade from the host', () {
    test(
      'deleting the host row hard-deletes its tunnels, not just hides them',
      () async {
        // Unlike HostRepository.delete (a tombstone), removing the host row
        // itself is what `tunnels.host_id ... ON DELETE CASCADE` reacts to —
        // this proves the repository actually sees the result of that
        // cascade, not just that the raw SQL supports it (schema_test.dart
        // already covers the SQL in isolation).
        await repository.save(tunnel('t1'));
        expect(await repository.forHost('h1'), hasLength(1));

        await database.raw.delete('hosts', where: "id = 'h1'");

        expect(await repository.forHost('h1'), isEmpty);
        expect(await repository.all(), isEmpty);
        // Hard-deleted, not tombstoned: a forward pointing at a host that no
        // longer exists has no tombstone worth keeping.
        final raw = await database.raw.query('tunnels');
        expect(raw, isEmpty);
      },
    );
  });
}
