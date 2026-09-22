import 'package:sqflite/sqflite.dart';

import '../../../core/db/upsert.dart';
import '../../../core/secrets/secret_ref.dart';
import '../../../core/secrets/secret_vault.dart';
import '../../../core/ssh/ssh_target.dart';
import '../domain/host_env.dart';
import '../domain/host_tags.dart';
import '../domain/ssh_host.dart';

/// Reads and writes saved hosts.
///
/// Deletes are **tombstones**, never `DELETE`: configuration syncs across a
/// user's devices, and a row that vanishes without trace cannot be propagated
/// — it simply reappears from whichever device had not heard about it. The
/// secrets that belong to a deleted host are destroyed for real, though; there
/// is no reason to keep a password for a server the user removed.
class HostRepository {
  HostRepository({required this.database, required this.vault});

  final Database database;
  final SecretVault vault;

  static const _table = 'hosts';

  /// Every host the user has not deleted, most recently used first.
  ///
  /// Recency rather than alphabetical: the host you want is nearly always one
  /// you used lately, and a list sorted by name buries it under whatever
  /// happens to start with 'a'.
  Future<List<SshHost>> all() async {
    final rows = await database.query(
      _table,
      where: 'deleted_at IS NULL',
      orderBy: 'last_connected_at DESC, label COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<SshHost?> byId(String id) async {
    final rows = await database.query(
      _table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  /// Inserts or updates [host] — never by REPLACE, which would delete its
  /// tunnels on the way (see [upsertRow]).
  Future<void> save(SshHost host) =>
      upsertRow(database, _table, _toRow(host), id: host.id);

  /// Saves several hosts in one transaction.
  ///
  /// Used by the OpenSSH import, where a partial write is the worst outcome:
  /// half a config imported leaves the user unsure what they now have, and
  /// re-importing would duplicate the half that landed.
  ///
  /// Written in **two passes**, because a batch can reference itself:
  /// `jump_host_id` points at another host in the same batch, and a config
  /// routinely lists a server above the bastion it connects through. Inserting
  /// in list order then fails the foreign key on the first host whose bastion
  /// has not been written yet — and takes the whole import down with it.
  ///
  /// So every row goes in with its jump link cleared, and the links are
  /// applied once all the rows exist. This needs no ordering and no
  /// topological sort, and it cannot be defeated by a cycle.
  Future<void> saveAll(Iterable<SshHost> hosts) async {
    final records = hosts.toList();
    await database.transaction((txn) async {
      for (final host in records) {
        await upsertRow(
          txn,
          _table,
          _toRow(host)..['jump_host_id'] = null,
          id: host.id,
        );
      }
      for (final host in records) {
        if (host.jumpHostId == null) continue;
        await txn.update(
          _table,
          {'jump_host_id': host.jumpHostId},
          where: 'id = ?',
          whereArgs: [host.id],
        );
      }
    });
  }

  /// Tombstones [id] and destroys its secrets.
  Future<void> delete(String id, {required DateTime now}) async {
    await database.update(
      _table,
      {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    // The row is kept so the delete can sync; the password is not. Keeping a
    // credential for a host the user removed would be the wrong half to
    // remember.
    await vault.deleteAll(SecretRef.forHost(id));
  }

  /// Records that a host was just connected to, so it rises to the top.
  Future<void> touch(String id, {required DateTime now}) => database.update(
    _table,
    {'last_connected_at': now.millisecondsSinceEpoch},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Builds the transport target for [host], resolving its jump chain.
  ///
  /// Cycles are broken rather than followed. A host configured — by hand or by
  /// a bad import — to jump through itself would otherwise recurse until the
  /// stack gives out, and a stack overflow is a much worse way to learn about
  /// a typo than simply connecting directly.
  Future<SshTarget> targetFor(SshHost host) async {
    final seen = <String>{host.id};
    SshTarget? jump;

    // Walk outward from the host to the outermost bastion, collecting the
    // chain, then build targets back down so each one nests in its jump.
    final chain = <SshHost>[];
    var current = host;
    while (current.jumpHostId != null) {
      final next = await byId(current.jumpHostId!);
      if (next == null || !seen.add(next.id)) break;
      chain.add(next);
      current = next;
    }

    for (final hop in chain.reversed) {
      jump = hop.toTarget(jumpTarget: jump);
    }
    return host.toTarget(jumpTarget: jump);
  }

  /// The row [host] is stored as — for a writer that has to work inside
  /// its own transaction, such as the JSON import.
  static Map<String, Object?> rowOf(SshHost host) => _toRow(host);

  static Map<String, Object?> _toRow(SshHost host) => {
    'id': host.id,
    'group_id': host.groupId,
    'label': host.label,
    'hostname': host.hostname,
    'port': host.port,
    'username': host.username,
    'auth_method': host.authMethod.name,
    'identity_id': host.identityId,
    'jump_host_id': host.jumpHostId,
    'allow_legacy_algorithms': host.allowLegacyAlgorithms ? 1 : 0,
    'startup_command': host.startupCommand,
    'keepalive_seconds': host.keepaliveSeconds,
    'terminal_theme': host.terminalTheme,
    'font_size': host.fontSize,
    'notes': host.notes,
    // Sanitized here as well as in the editor: an import or a transfer can
    // hand over a tag with a comma in it, and that is one tag on the way in
    // and two on the way out.
    'tags': HostTags.join(host.tags),
    'env_vars': HostEnv.encode(host.envVars),
    'forward_agent': host.forwardAgent ? 1 : 0,
    'tmux_mode': host.tmuxMode.storageValue,
    'last_connected_at': host.lastConnectedAt?.millisecondsSinceEpoch,
    'created_at': host.createdAt.millisecondsSinceEpoch,
    'updated_at': host.updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'dirty': 1,
  };

  static SshHost _fromRow(Map<String, Object?> row) => SshHost(
    id: row['id']! as String,
    groupId: row['group_id'] as String?,
    label: row['label']! as String,
    hostname: row['hostname']! as String,
    port: row['port']! as int,
    username: row['username']! as String,
    authMethod: SshAuthMethod.values.firstWhere(
      (m) => m.name == row['auth_method'],
      // A value written by a newer version of the app must not crash an older
      // one; falling back to key auth is the safe reading.
      orElse: () => SshAuthMethod.publicKey,
    ),
    identityId: row['identity_id'] as String?,
    jumpHostId: row['jump_host_id'] as String?,
    allowLegacyAlgorithms: (row['allow_legacy_algorithms'] as int? ?? 0) == 1,
    startupCommand: row['startup_command'] as String?,
    keepaliveSeconds: row['keepalive_seconds'] as int? ?? 30,
    terminalTheme: row['terminal_theme'] as String?,
    fontSize: (row['font_size'] as num?)?.toDouble(),
    notes: row['notes'] as String?,
    tags: HostTags.parse(row['tags'] as String?),
    envVars: HostEnv.parse(row['env_vars'] as String?),
    forwardAgent: (row['forward_agent'] as int? ?? 0) == 1,
    tmuxMode: HostTmuxMode.fromStorage(row['tmux_mode'] as String?),
    lastConnectedAt: _time(row['last_connected_at']),
    createdAt: _time(row['created_at'])!,
    updatedAt: _time(row['updated_at'])!,
  );

  static DateTime? _time(Object? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
}
