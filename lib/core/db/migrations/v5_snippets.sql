-- v5 — saved commands ("snippets") that can be typed into a session.
--
-- A snippet is a label and a body of shell text, optionally with `{{name}}`
-- placeholders the app fills in when it is used (see
-- lib/features/snippets/domain/snippet_template.dart). Like every other
-- configuration table it holds no secret: a body is text the user will type
-- into a terminal anyway, and anything sensitive belongs in a placeholder
-- that is asked for at the moment of use, not in this file.
--
-- Tombstoned rather than deleted, the same as hosts and tunnels, so the
-- repositories share one idea of "gone". There is no `dirty` / `synced_at`
-- pair: those columns on the older tables are vestigial (see v4), and a new
-- table has no reason to inherit them.
CREATE TABLE snippets (
  id           TEXT PRIMARY KEY NOT NULL,
  label        TEXT NOT NULL,
  body         TEXT NOT NULL,
  description  TEXT,
  -- Comma-separated, written through HostTags so a snippet's tags follow the
  -- same rules as a host's.
  tags         TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  deleted_at   INTEGER
);

CREATE INDEX idx_snippets_active
  ON snippets (sort_order, label)
  WHERE deleted_at IS NULL;
