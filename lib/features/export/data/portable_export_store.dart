import 'package:sqflite/sqflite.dart';

import '../../../core/ssh/known_hosts_store.dart';
import '../../hosts/data/host_group_repository.dart';
import '../../hosts/data/host_repository.dart';
import '../../keys/data/identity_repository.dart';
import '../../snippets/data/snippet_repository.dart';
import '../../tunnels/data/tunnel_repository.dart';
import '../domain/json_import_plan.dart';
import '../domain/portable_export.dart';

/// Reads this device's configuration as a [PortableExport], and writes an
/// import's changes back.
///
/// Reads go through the repositories, so an export sees exactly what the app
/// shows — tombstoned rows left behind — and never touches the vault: there
/// is nothing in an export the keychain would have to release.
class PortableExportStore {
  const PortableExportStore({
    required this.database,
    required this.hosts,
    required this.groups,
    required this.identities,
    required this.tunnels,
    required this.snippets,
    required this.knownHosts,
  });

  final Database database;
  final HostRepository hosts;
  final HostGroupRepository groups;
  final IdentityRepository identities;
  final TunnelRepository tunnels;
  final SnippetRepository snippets;
  final KnownHostsStore knownHosts;

  Future<PortableExport> read({
    required DateTime now,
    required String appVersion,
  }) async => PortableExport(
    exportedAt: now,
    app: appVersion,
    groups: await groups.all(),
    identities: await identities.all(),
    hosts: await hosts.all(),
    tunnels: await tunnels.all(),
    snippets: await snippets.all(),
    knownHosts: knownHosts.all(),
  );

  /// Writes [changes] in **one transaction**: an import that fails halfway
  /// writes nothing, so trying again cannot duplicate the half that landed.
  ///
  /// Every row is an UPDATE when its id exists (tombstoned or not) and an
  /// INSERT otherwise — never `INSERT OR REPLACE`. REPLACE deletes the old
  /// row first, and that delete fires the foreign keys: updating a host would
  /// cascade away its tunnels, and updating a group would empty it.
  ///
  /// Hosts go in two passes, the way `HostRepository.saveAll` does it: a jump
  /// host may be later in the list than the host that uses it.
  ///
  /// Known-host pins are inserted only (the plan never includes one that
  /// would replace a pin here); the caller reloads the store's cache after.
  static Future<void> apply(Database database, JsonImportChanges changes) =>
      database.transaction((txn) async {
        for (final group in changes.groups) {
          await _upsert(txn, 'host_groups', HostGroupRepository.rowOf(group));
        }
        for (final host in changes.hosts) {
          await _upsert(
            txn,
            'hosts',
            HostRepository.rowOf(host)..['jump_host_id'] = null,
          );
        }
        for (final host in changes.hosts) {
          if (host.jumpHostId == null) continue;
          await txn.update(
            'hosts',
            {'jump_host_id': host.jumpHostId},
            where: 'id = ?',
            whereArgs: [host.id],
          );
        }
        for (final tunnel in changes.tunnels) {
          await _upsert(txn, 'tunnels', TunnelRepository.rowOf(tunnel));
        }
        for (final snippet in changes.snippets) {
          await _upsert(txn, 'snippets', SnippetRepository.rowOf(snippet));
        }
        for (final key in changes.knownHosts) {
          await txn.insert(
            'known_hosts',
            SqfliteKnownHostsStore.rowOf(key),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

  static Future<void> _upsert(
    Transaction txn,
    String table,
    Map<String, Object?> row,
  ) async {
    final updated = await txn.update(
      table,
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    if (updated == 0) await txn.insert(table, row);
  }
}
