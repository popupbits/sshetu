-- v2 — repair hosts the OpenSSH import mislabelled as password-only.
--
-- The import mapped "this config entry has no IdentityFile" to password
-- authentication. That is not what it means. `ssh` with no IdentityFile offers
-- the user's default keys and only falls back to a password if the server
-- refuses them, and `~/.ssh/config` entries very commonly name no key at all —
-- so the mapping turned nine out of ten imported hosts into password prompts
-- for connections that had a perfectly good key available.
--
-- The import is fixed. These rows are the ones it already wrote.
--
-- Narrow on purpose. It touches only rows that are simultaneously
-- password-authenticated AND have no key selected, which is exactly the shape
-- the bug produced: a host the user deliberately set to password-only in the
-- editor has that same shape today, but the editor that lets them say so
-- ships in this same version, so no such row can exist yet.
--
-- It also only ever moves a host towards offering a key, never away. A host
-- that cannot use one still falls back to a password, so the worst case is an
-- unnecessary key offer, not a connection that stops working.

UPDATE hosts
   SET auth_method = 'publicKey',
       updated_at  = updated_at,
       dirty       = 1
 WHERE auth_method = 'password'
   AND identity_id IS NULL
   AND deleted_at IS NULL;
