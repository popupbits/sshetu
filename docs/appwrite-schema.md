# Appwrite schema

What `lib/core/sync/` and `lib/core/secrets/appwrite_secret_vault.dart`
expect to exist in the Appwrite project, written so it can be created by hand
in the console or scripted with the CLI/server SDK. Nothing here is created
by the app itself — there is no bootstrap step that provisions a database,
deliberately, since running arbitrary schema-creation calls from a client app
that ships to end users is its own security question this project has not
taken on.

**The project id in `lib/core/config/app_config.dart` (`APPWRITE_PROJECT`,
defaulting to `sshetu`) is a placeholder.** So is the database id
(`APPWRITE_DATABASE`, defaulting to `sshetu`). Point them at a real
Appwrite project and database with `--dart-define` before any of this is
reachable — see the doc comment on `AppConfig`.

## Conventions used throughout

- **One table per synced local table**, same name on both sides:
  `host_groups`, `identities`, `hosts`, `tunnels`, plus `secrets` for
  `AppwriteSecretVault`. `known_hosts` has no remote table at all — see
  `v1_initial.sql`'s comment on that table for why, and
  `lib/core/sync/sync_table_spec.dart` for the registry this mirrors.
- **Row id = local id.** Every row is created with an explicit `rowId` equal
  to the local `TEXT PRIMARY KEY` (a host, identity, group or tunnel's own
  `id`), never an auto-generated one. This is what makes a push idempotent —
  retrying a row after a dropped connection updates the same document rather
  than creating a second one — and what makes a pull's merge a plain id
  lookup.
- **Row-level permissions, not a shared collection-level rule.** Every row is
  created with exactly `read`, `update` and `delete` for
  `user:<the owner's Appwrite user id>` (see `AppwriteSyncRemote.upsertRow`
  and `AppwriteSecretRemote.write`). No row is ever readable by anyone else,
  including another authenticated user of the same project. Collection-level
  "any authenticated user" permissions are **not** set on any table below —
  that would let user A list user B's hosts.
- **A `user_id` string attribute is kept on every row anyway**, even though
  runtime queries never filter on it (Appwrite already scopes `listRows` to
  what the session can read). It exists so a row's ownership can be read
  straight off the console without cross-referencing permissions, which is
  the only way to sanity-check this schema by hand.
- **Booleans are `Integer` (0/1), not `Boolean`.** SQLite has no boolean type
  — these columns are already stored as 0/1 locally — so mirroring that
  avoids a conversion layer that would exist purely for these columns.
  (`has_passphrase`, `allow_legacy_algorithms`, `auto_start`.)
- **Timestamps are `Integer` milliseconds since epoch**, matching
  `v1_initial.sql`'s own convention exactly (see its header comment): they
  sort and compare as integers and survive a device changing time zone. Not
  Appwrite's own `$createdAt`/`$updatedAt` — those are ISO 8601 strings on
  Appwrite's clock, and the sync engine's last-writer-wins comparison and
  pull cursor both need the same millisecond-integer `updated_at` the local
  database already writes on every edit.
- **No relationship attributes.** `hosts.identity_id`, `hosts.group_id`,
  `hosts.jump_host_id` and `tunnels.host_id` are plain `String` attributes
  holding another row's id, exactly as they are locally. Appwrite
  relationship attributes would require the referenced table to exist first,
  complicate the two-pass write `SyncEngine` already does for
  `jump_host_id` (see `SyncTableSpec.deferredForeignKeys`), and buy nothing a
  string id does not already provide, since nothing here ever queries
  "hosts in this group" *on the backend* — every read this app does is local.

## Tables

### `host_groups`

| Attribute | Type | Size | Required | Notes |
|---|---|---|---|---|
| `name` | String | 200 | yes | |
| `parent_id` | String | 36 | no | another `host_groups` row's id |
| `sort_order` | Integer | — | yes | default `0` |
| `created_at` | Integer | — | yes | ms epoch |
| `updated_at` | Integer | — | yes | ms epoch; the LWW and pull-cursor field |
| `deleted_at` | Integer | — | no | ms epoch; null unless tombstoned |
| `user_id` | String | 36 | yes | see Conventions |

Indexes: `key` index on `updated_at` (the pull query is
`Query.greaterThan('updated_at', since)` ordered by it).

Permissions: none at the collection level. Row-level only (see Conventions).

### `identities`

| Attribute | Type | Size | Required | Notes |
|---|---|---|---|---|
| `label` | String | 200 | yes | |
| `key_type` | String | 40 | yes | e.g. `ssh-ed25519` |
| `public_key` | String | 4000 | no | OpenSSH single-line form; not secret |
| `fingerprint` | String | 100 | no | `SHA256:<base64>`; not secret |
| `has_passphrase` | Integer | — | yes | 0/1, see Conventions |
| `origin` | String | 20 | yes | `generated` \| `imported` \| `ssh_config` |
| `created_at` | Integer | — | yes | ms epoch |
| `updated_at` | Integer | — | yes | ms epoch |
| `deleted_at` | Integer | — | no | ms epoch |
| `user_id` | String | 36 | yes | |

Indexes: `key` index on `updated_at`.

**The private key and its passphrase are never here.** They go through
`SecretVault` to the `secrets` table below, addressed by
`SecretRef.identityPrivateKey`/`identityPassphrase`, exactly as
`v1_initial.sql` documents for the local database.

### `hosts`

| Attribute | Type | Size | Required | Notes |
|---|---|---|---|---|
| `group_id` | String | 36 | no | a `host_groups` row's id |
| `label` | String | 200 | yes | |
| `hostname` | String | 255 | yes | |
| `port` | Integer | — | yes | default `22` |
| `username` | String | 100 | yes | |
| `auth_method` | String | 20 | yes | `password` \| `publicKey` \| `agent` |
| `identity_id` | String | 36 | no | an `identities` row's id |
| `jump_host_id` | String | 36 | no | another `hosts` row's id; see `SyncTableSpec.deferredForeignKeys` |
| `allow_legacy_algorithms` | Integer | — | yes | 0/1, default `0` |
| `startup_command` | String | 500 | no | |
| `keepalive_seconds` | Integer | — | yes | default `30` |
| `terminal_theme` | String | 100 | no | |
| `font_size` | Float | — | no | |
| `notes` | String | 2000 | no | |
| `tags` | String | 500 | no | comma-separated |
| `created_at` | Integer | — | yes | ms epoch |
| `updated_at` | Integer | — | yes | ms epoch |
| `deleted_at` | Integer | — | no | ms epoch |
| `user_id` | String | 36 | yes | |

Indexes: `key` index on `updated_at`.

**Deliberately absent: `last_connected_at`.** It is per-device usage — when
*this* device last opened a session — not shared configuration. Syncing it
would let one device's connection history overwrite another's "most recently
used" ordering. `SyncTableSpec` excludes it from the columns the engine ever
reads or writes, so it is never sent and a pulled row's `UPDATE` never
touches it locally.

**The saved password, if any, is never here.** It goes through `SecretVault`
to `secrets`, addressed by `SecretRef.hostPassword`.

### `tunnels`

| Attribute | Type | Size | Required | Notes |
|---|---|---|---|---|
| `host_id` | String | 36 | yes | a `hosts` row's id |
| `label` | String | 200 | yes | |
| `kind` | String | 20 | yes | `local` \| `remote` \| `dynamic` |
| `listen_host` | String | 100 | yes | default `127.0.0.1` |
| `listen_port` | Integer | — | yes | |
| `target_host` | String | 255 | no | |
| `target_port` | Integer | — | no | |
| `auto_start` | Integer | — | yes | 0/1, default `0` |
| `created_at` | Integer | — | yes | ms epoch |
| `updated_at` | Integer | — | yes | ms epoch |
| `deleted_at` | Integer | — | no | ms epoch |
| `user_id` | String | 36 | yes | |

Indexes: `key` index on `updated_at`.

### `secrets`

Backs `AppwriteSecretVault`, not `SyncEngine` — a different write pattern
(get/set by id, no `updated_at`, no pull cursor, no last-writer-wins) because
`SecretRef` carries no timestamp to compare. See the doc comment at the top
of `lib/core/secrets/appwrite_secret_vault.dart` before touching this table;
it is the one place this schema stores something genuinely secret.

| Attribute | Type | Size | Required | Notes |
|---|---|---|---|---|
| `value` | String | 65535 | yes | **`encrypt` enabled** — see below |
| `owner_id` | String | 36 | yes | the host/identity id this secret belongs to |
| `kind` | String | 20 | yes | `password` \| `private` \| `passphrase` |
| `user_id` | String | 36 | yes | |

Row id: **not** the owning host/identity's id. It is a truncated SHA-256 of
the local `SecretRef.storageKey` (`AppwriteSecretVault._rowId`) — Appwrite row
ids are capped at 36 characters from a limited charset, and
`identity/<uuid>/private` alone can already exceed that. `owner_id` and `kind`
are what make a row identifiable by hand from the console, since the id
itself no longer is and `value` cannot be queried at all (see below).

Indexes: **none on `value`** — an `encrypt` attribute cannot be indexed or
queried, by Appwrite's own design (that is what "encrypted at rest" is
supposed to mean). Every access is a get-row-by-id or a row-permission-scoped
list, never a filter on secret content.

**`value` must have Appwrite's `encrypt` option enabled when this attribute
is created.** This is the crux of the credential-storage decision recorded in
`docs/prior-art.md`: `encrypt` encrypts at rest with the *server's* key
(`_APP_OPENSSL_KEY_V1`), so Appwrite itself — an operator, a backup, a breach
of the instance — can decrypt it. That was raised and accepted deliberately,
in exchange for not building a client-sealed vault's recovery and
first-device-login flow. If that tradeoff changes, this table (and
`AppwriteSecretVault`) is the entire blast radius; nothing else in the app
knows secrets can be remote at all.

Permissions: none at the collection level. Row-level only, identical in shape
to the synced tables above.

## Creating it with the script

```sh
cd sshetu_appwrite_setup
cp .env.example .env        # fill in APPWRITE_API_KEY
dart pub get
dart run bin/setup_appwrite.dart --check    # what is missing; writes nothing
dart run bin/setup_appwrite.dart            # create or finish the job
```

Idempotent and non-destructive: every step either creates what is missing or
sees a 409 and moves on. It is a separate package so the app never depends on
the server SDK, and so a key with write access to the database is never
reachable from anything that ships to a device.

The table and column definitions in `bin/setup_appwrite.dart` mirror this
document. If you change one, change the other — the script is the executable
copy, this is the explained one.

## Creating this by hand

Console: **Database → your database → Create table**, name matching the
table id above, then add each attribute with its type/size/required exactly
as listed, remembering to tick **Encryption** on `secrets.value`. Leave
collection-level permissions empty — every read/write goes through row
permissions set by the app on first write (`AppwriteSyncRemote.upsertRow`,
`AppwriteSecretRemote.write`), so there is nothing to configure here beyond
"authenticated users may create rows in this table", which every table needs
so `createRow` can succeed for a brand-new row before that row has any
permissions of its own yet.

Scripted (Appwrite CLI / server SDK): each table above is a
`databases.createTable` (or `createCollection`, depending on SDK version)
call followed by one `createStringAttribute` / `createIntegerAttribute` /
`createFloatAttribute` per row in its table, and one
`createIndex(..., type: 'key', attributes: ['updated_at'])` for every synced
table except `secrets`. `secrets.value` is
`createStringAttribute(..., size: 65535, required: true, encrypt: true)` —
the `encrypt` flag is the whole point of that table and easy to miss when
scripting from this doc rather than reading the SDK signature.
