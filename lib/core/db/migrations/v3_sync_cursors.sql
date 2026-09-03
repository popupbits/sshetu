-- v3 — bookkeeping for the Appwrite sync engine (lib/core/sync/).
--
-- One row per synced table, holding the `updated_at` of the newest remote row
-- that table has ever successfully pulled and applied. This is what makes a
-- pull incremental and resumable: the next pull asks for rows newer than this
-- cursor instead of the whole table, and the cursor only advances after a
-- fetched page is fully applied — inside the same transaction as the writes
-- it accounts for — so a crash mid-page leaves the cursor exactly where it
-- was and the next pull reprocesses that page rather than skipping it.
--
-- A row that has never been pulled simply has no entry here; there is no
-- sentinel value, because "never synced" and "synced everything up to
-- timestamp 0" are different states and only one of them is true before the
-- first sync.
CREATE TABLE sync_cursors (
  table_name     TEXT PRIMARY KEY NOT NULL,
  last_pulled_at INTEGER NOT NULL
);
