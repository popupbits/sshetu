import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/hosts/data/host_group_repository.dart';
import 'package:sshetu/features/hosts/data/host_repository.dart';
import 'package:sshetu/features/hosts/domain/host_group.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';

import '../support/test_database.dart';

/// Groups against the real schema, foreign keys switched on.
void main() {
  late AppDatabase database;
  late HostGroupRepository groups;
  late HostRepository hosts;

  final now = DateTime.utc(2026, 1, 1);
  final later = DateTime.utc(2026, 2, 1);

  setUp(() async {
    database = await openTestDatabase();
    groups = HostGroupRepository(database: database.raw);
    hosts = HostRepository(
      database: database.raw,
      vault: InMemorySecretVault(),
    );
  });

  tearDown(() => database.close());

  HostGroup group(String id, {String name = 'Production', int order = 0}) =>
      HostGroup(
        id: id,
        name: name,
        sortOrder: order,
        createdAt: now,
        updatedAt: now,
      );

  SshHost host(String id, {String? groupId}) => SshHost(
    id: id,
    label: id,
    hostname: '$id.example.com',
    username: 'root',
    groupId: groupId,
    createdAt: now,
    updatedAt: now,
  );

  test('a saved group reads back', () async {
    await groups.save(group('g1'));
    expect(await groups.all(), [group('g1')]);
    expect(await groups.byId('g1'), group('g1'));
  });

  test('all() is in sort order, then name', () async {
    await groups.save(group('b', name: 'beta', order: 1));
    await groups.save(group('a', name: 'Alpha', order: 1));
    await groups.save(group('z', name: 'zulu'));

    expect((await groups.all()).map((g) => g.id), ['z', 'a', 'b']);
  });

  test('nextSortOrder puts a new group last', () async {
    expect(await groups.nextSortOrder(), 0);
    await groups.save(group('a', order: 4));
    expect(await groups.nextSortOrder(), 5);
  });

  test('renaming keeps the hosts in the group', () async {
    // The trap this guards: INSERT OR REPLACE deletes the old row first, and
    // that delete fires ON DELETE SET NULL on every host in the group.
    await groups.save(group('g1'));
    await hosts.save(host('h1', groupId: 'g1'));

    await groups.save(group('g1').copyWith(name: 'Prod', updatedAt: later));

    expect((await groups.byId('g1'))!.name, 'Prod');
    expect((await hosts.byId('h1'))!.groupId, 'g1');
  });

  test('delete tombstones the group and moves its hosts out', () async {
    await groups.save(group('g1'));
    await groups.save(group('g2', name: 'Staging'));
    await hosts.save(host('in', groupId: 'g1'));
    await hosts.save(host('other', groupId: 'g2'));
    await hosts.save(host('loose'));

    await groups.delete('g1', now: later);

    expect((await groups.all()).map((g) => g.id), ['g2']);
    expect(await groups.byId('g1'), isNull);

    // Every host is still here; only the one in the deleted group moved.
    expect((await hosts.all()).map((h) => h.id).toSet(), {
      'in',
      'other',
      'loose',
    });
    expect((await hosts.byId('in'))!.groupId, isNull);
    expect((await hosts.byId('other'))!.groupId, 'g2');

    // The moved host is marked changed, so the edit is not invisible.
    final row = (await database.raw.query('hosts', where: "id = 'in'")).single;
    expect(row['updated_at'], later.millisecondsSinceEpoch);

    // A tombstone, not a hard delete.
    final tomb = (await database.raw.query(
      'host_groups',
      where: "id = 'g1'",
    )).single;
    expect(tomb['deleted_at'], later.millisecondsSinceEpoch);
  });

  test('delete lifts child groups to the top level', () async {
    // Groups nest in the schema even though the UI shows one level; a
    // child must not keep pointing at a tombstoned parent.
    await groups.save(group('parent'));
    await database.raw.insert('host_groups', {
      'id': 'child',
      'name': 'child',
      'parent_id': 'parent',
      'sort_order': 0,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });

    await groups.delete('parent', now: later);

    final child = (await database.raw.query(
      'host_groups',
      where: "id = 'child'",
    )).single;
    expect(child['parent_id'], isNull);
    expect(child['deleted_at'], isNull);
  });
}
