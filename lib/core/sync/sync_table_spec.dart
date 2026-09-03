/// One local table [SyncEngine] pushes to and pulls from Appwrite.
///
/// A small hand-written registry, in the same spirit as
/// `core/bootstrap.dart`'s steps and `core/router/routes.dart`'s paths:
/// adding a synced table means adding an entry to [syncTables], not touching
/// the push/pull/merge code.
///
/// [columns] is the exact set of local columns the engine will ever read to
/// push or write to apply a pull — deliberately **not** `id`, `dirty` or
/// `synced_at`. `id` is carried by the row itself (it is the Appwrite row
/// id, not a synced attribute); `dirty`/`synced_at` are local bookkeeping the
/// remote side has no use for. Any local column left out of this list is a
/// column the engine has never heard of and will never send or overwrite —
/// which is how a per-device field like `hosts.last_connected_at` stays
/// per-device without a special case anywhere in the merge logic: a pulled
/// row is applied with `UPDATE ... SET <only these columns>`, never with a
/// full-row replace that would reset everything else to its default.
class SyncTableSpec {
  const SyncTableSpec({
    required this.localTable,
    required this.remoteTable,
    required this.columns,
    this.deferredForeignKeys = const [],
  });

  /// The SQLite table name.
  final String localTable;

  /// The Appwrite table (collection) id. Kept separate from [localTable] even
  /// though every entry below uses the same string for both, so a rename on
  /// either side is a one-line change here rather than a rename that has to
  /// happen in lockstep.
  final String remoteTable;

  final List<String> columns;

  /// Columns that reference another row in *this same table* (only
  /// `hosts.jump_host_id` today) and so cannot always be applied on first
  /// write.
  ///
  /// A pulled page can contain a host and the bastion it jumps through in the
  /// same batch — exactly like an OpenSSH import batch (see
  /// `HostRepository.saveAll`) — so every row in a page is written with these
  /// columns cleared first, and [SyncEngine] fixes them up in a second pass
  /// once every row in the page exists. Skipping this would fail the foreign
  /// key check on whichever row happens to be applied first.
  final List<String> deferredForeignKeys;
}

/// Every table this app syncs.
///
/// `known_hosts` is deliberately absent. See the comment on that table in
/// `v1_initial.sql`: a trust decision made on one device must not become
/// fleet-wide trust, so it has no `dirty`/`synced_at` columns at all and
/// cannot be added here without a schema change that is its own decision.
const List<SyncTableSpec> syncTables = <SyncTableSpec>[
  SyncTableSpec(
    localTable: 'host_groups',
    remoteTable: 'host_groups',
    columns: [
      'name',
      'parent_id',
      'sort_order',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  ),
  SyncTableSpec(
    localTable: 'identities',
    remoteTable: 'identities',
    columns: [
      'label',
      'key_type',
      'public_key',
      'fingerprint',
      'has_passphrase',
      'origin',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  ),
  SyncTableSpec(
    localTable: 'hosts',
    remoteTable: 'hosts',
    columns: [
      'group_id',
      'label',
      'hostname',
      'port',
      'username',
      'auth_method',
      'identity_id',
      'jump_host_id',
      'allow_legacy_algorithms',
      'startup_command',
      'keepalive_seconds',
      'terminal_theme',
      'font_size',
      'notes',
      'tags',
      // last_connected_at is intentionally not here — see the class comment.
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    deferredForeignKeys: ['jump_host_id'],
  ),
  SyncTableSpec(
    localTable: 'tunnels',
    remoteTable: 'tunnels',
    columns: [
      'host_id',
      'label',
      'kind',
      'listen_host',
      'listen_port',
      'target_host',
      'target_port',
      'auto_start',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  ),
];
