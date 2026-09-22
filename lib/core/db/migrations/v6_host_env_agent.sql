-- v6 — per-host environment variables and agent forwarding.
--
-- env_vars: a JSON object of variable name to value, e.g. {"EDITOR":"vim"},
-- or NULL for none. JSON rather than `KEY=VALUE` lines because a value may
-- hold a `=`, and an object has one reading where a hand-rolled line format
-- has as many as there are edge cases. Names are validated on the way in
-- (^[A-Za-z_][A-Za-z0-9_]*$) and again where they are used, because a name
-- becomes shell syntax on the server.
--
-- Configuration, not a secret — the same as `startup_command`, which is the
-- other text this app types into a shell for the user. Anything sensitive
-- belongs in the server's own files, not in a column that travels in a
-- transfer and a backup.
--
-- Nullable with no default, so a transfer or backup from v5, whose host rows
-- have no such column, still inserts cleanly.
ALTER TABLE hosts ADD COLUMN env_vars TEXT;

-- forward_agent: whether this host may use the keys this app holds to sign
-- in onward while connected (`ForwardAgent`). Off by default, and per host:
-- a server with agent access can authenticate as the user wherever those
-- keys are accepted. NOT NULL with a default, so a v5 row that omits it
-- lands as 0 — off, the safe reading.
ALTER TABLE hosts ADD COLUMN forward_agent INTEGER NOT NULL DEFAULT 0;
