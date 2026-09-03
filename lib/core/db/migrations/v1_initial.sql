-- v1 — initial schema for SSH Navigator.
--
-- Two rules run through every table here.
--
-- 1. **No secret is ever stored in this database.** Not a password, not a key
--    passphrase, not private key material. Rows hold *references* into the
--    SecretVault (see lib/core/secrets/) and nothing more. SQLite here is not
--    encrypted and is included in device backups; treating it as a credential
--    store would put every user's servers in a plaintext file.
--
-- 2. **Rows are tombstoned, never hard-deleted**, and carry sync bookkeeping
--    from the start. Configuration syncs across a user's devices through
--    Appwrite, and a delete that leaves no trace cannot be propagated — the
--    row simply reappears from whichever device had not heard about it.

-- Millisecond epochs throughout, not ISO strings: they sort and compare as
-- integers and survive a device changing time zone.

------------------------------------------------------------------------------
-- Groups
------------------------------------------------------------------------------

-- A folder of hosts. Self-referencing so "work / eu-west / db" nests, which is
-- how anyone with more than a dozen servers actually organises them.
CREATE TABLE host_groups (
  id          TEXT PRIMARY KEY NOT NULL,
  name        TEXT NOT NULL,
  -- ON DELETE RESTRICT, not CASCADE: deleting a folder must not silently take
  -- its servers with it. The UI moves children out first, deliberately.
  parent_id   TEXT REFERENCES host_groups (id) ON DELETE RESTRICT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  deleted_at  INTEGER,
  -- 1 while local changes have not reached the backend yet.
  dirty       INTEGER NOT NULL DEFAULT 1,
  synced_at   INTEGER
);

CREATE INDEX idx_host_groups_parent
  ON host_groups (parent_id, sort_order)
  WHERE deleted_at IS NULL;

------------------------------------------------------------------------------
-- Identities (SSH keys)
------------------------------------------------------------------------------

-- A keypair the user owns. The PRIVATE key is NOT here — it lives in the vault
-- under `identity/<id>/private`, with its passphrase, if any, under
-- `identity/<id>/passphrase`.
--
-- The public key and fingerprint are stored in the clear on purpose: they are
-- not secret, and having them lets the app show a key, copy it to the
-- clipboard, and offer to install it on a host without unlocking anything.
CREATE TABLE identities (
  id              TEXT PRIMARY KEY NOT NULL,
  label           TEXT NOT NULL,
  -- 'ssh-ed25519', 'ecdsa-sha2-nistp256', 'ssh-rsa', ...
  key_type        TEXT NOT NULL,
  -- OpenSSH single-line form, safe to display and to paste into
  -- authorized_keys.
  public_key      TEXT,
  -- 'SHA256:<base64>', the same form `ssh-keygen -lf` prints.
  fingerprint     TEXT,
  -- Whether the private key is passphrase-protected. Known without decoding
  -- the key, so the UI can ask for the passphrase before it needs it rather
  -- than failing mid-connect.
  has_passphrase  INTEGER NOT NULL DEFAULT 0,
  -- 'generated' | 'imported' | 'ssh_config' — where it came from, so an
  -- imported key is never offered for deletion as casually as a generated one.
  origin          TEXT NOT NULL DEFAULT 'imported',
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL,
  deleted_at      INTEGER,
  dirty           INTEGER NOT NULL DEFAULT 1,
  synced_at       INTEGER
);

CREATE INDEX idx_identities_active
  ON identities (label)
  WHERE deleted_at IS NULL;

------------------------------------------------------------------------------
-- Hosts
------------------------------------------------------------------------------

CREATE TABLE hosts (
  id                TEXT PRIMARY KEY NOT NULL,
  group_id          TEXT REFERENCES host_groups (id) ON DELETE SET NULL,
  -- What the user calls it. Distinct from `hostname`, which is where it is.
  label             TEXT NOT NULL,
  hostname          TEXT NOT NULL,
  port              INTEGER NOT NULL DEFAULT 22,
  username          TEXT NOT NULL,

  -- 'password' | 'publicKey' | 'agent'. The password itself, when the user
  -- chose to save one, is at `host/<id>/password` in the vault.
  auth_method       TEXT NOT NULL DEFAULT 'publicKey',
  identity_id       TEXT REFERENCES identities (id) ON DELETE SET NULL,

  -- ProxyJump. Self-referencing, so a bastion is just another host and gets
  -- the same credential handling rather than a parallel half-implementation.
  -- RESTRICT because deleting a bastion silently would break every host behind
  -- it in a way that only shows up at connect time.
  jump_host_id      TEXT REFERENCES hosts (id) ON DELETE RESTRICT,

  -- dartssh2 4.0 dropped SHA-1 key exchange, ssh-rsa host keys and CBC ciphers
  -- from the defaults, so switches, routers and old embedded boxes that offer
  -- nothing else now fail to negotiate. This re-enables them FOR THIS HOST
  -- ONLY. Deliberately per-host and off by default: it weakens the connection,
  -- and a global switch would weaken every connection to fix one.
  allow_legacy_algorithms INTEGER NOT NULL DEFAULT 0,

  -- Sent on connect, before the shell is handed to the user. The obvious use
  -- is `tmux new -A -s main`, which is also the best answer to Android killing
  -- a backgrounded session.
  startup_command   TEXT,

  -- Seconds between keepalives, 0 to disable. Mobile radios drop idle TCP
  -- connections aggressively; this is what stops a session dying in a pocket.
  keepalive_seconds INTEGER NOT NULL DEFAULT 30,

  -- Terminal appearance overrides, null to follow the app default.
  terminal_theme    TEXT,
  font_size         REAL,

  notes             TEXT,
  -- Free-form, comma-separated. Searching is the point, not taxonomy.
  tags              TEXT,

  last_connected_at INTEGER,
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  deleted_at        INTEGER,
  dirty             INTEGER NOT NULL DEFAULT 1,
  synced_at         INTEGER
);

CREATE INDEX idx_hosts_group
  ON hosts (group_id, label)
  WHERE deleted_at IS NULL;

-- The host list opens on "recently used", so this is the index that matters
-- for the first screen.
CREATE INDEX idx_hosts_recent
  ON hosts (last_connected_at DESC)
  WHERE deleted_at IS NULL;

------------------------------------------------------------------------------
-- Known hosts
------------------------------------------------------------------------------

-- Trust-on-first-use, keyed by address rather than by host row: two saved
-- hosts pointing at the same machine must agree about its identity, and a host
-- that is deleted and re-added must not silently re-trust a key that changed
-- in between.
--
-- This table is deliberately NOT synced. A trust decision is made about a
-- network path from a device; pushing it to every other device would turn one
-- accepted key into fleet-wide trust, which is the opposite of what
-- verification is for.
CREATE TABLE known_hosts (
  hostname    TEXT NOT NULL,
  port        INTEGER NOT NULL,
  key_type    TEXT NOT NULL,
  -- 'SHA256:<base64>'. The fingerprint is enough to detect a substituted key
  -- and is safe to show the user verbatim; the key itself is not stored.
  fingerprint TEXT NOT NULL,
  trusted_at  INTEGER NOT NULL,
  PRIMARY KEY (hostname, port)
);

------------------------------------------------------------------------------
-- Port forwards
------------------------------------------------------------------------------

CREATE TABLE tunnels (
  id            TEXT PRIMARY KEY NOT NULL,
  host_id       TEXT NOT NULL REFERENCES hosts (id) ON DELETE CASCADE,
  label         TEXT NOT NULL,
  -- 'local' | 'remote' | 'dynamic'. A dynamic tunnel is a SOCKS proxy and
  -- leaves the target columns null.
  kind          TEXT NOT NULL,
  -- Defaults to 127.0.0.1. Binding 0.0.0.0 exposes the forward to the whole
  -- network, so it is a choice the user makes explicitly, never a default.
  listen_host   TEXT NOT NULL DEFAULT '127.0.0.1',
  listen_port   INTEGER NOT NULL,
  target_host   TEXT,
  target_port   INTEGER,
  auto_start    INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  deleted_at    INTEGER,
  dirty         INTEGER NOT NULL DEFAULT 1,
  synced_at     INTEGER
);

CREATE INDEX idx_tunnels_host
  ON tunnels (host_id)
  WHERE deleted_at IS NULL;
