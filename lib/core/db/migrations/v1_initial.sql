-- v1 — initial schema for SSH Navigator.
--
-- A single example table so the migration runner has something real to apply
-- and the app has a table to read on first launch. Replace it with the real
-- schema, keeping the migration numbering.

CREATE TABLE items (
  id          TEXT PRIMARY KEY NOT NULL,
  title       TEXT NOT NULL,
  notes       TEXT,
  -- Millisecond epochs, not ISO strings: they sort and compare as integers
  -- and survive time-zone changes on the device.
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  -- Tombstone rather than a hard delete, so an undo is possible and a future
  -- sync has something to propagate.
  deleted_at  INTEGER
);

-- Partial index: every list query filters out deleted rows, and excluding
-- them from the index keeps it small as tombstones accumulate.
CREATE INDEX idx_items_active
  ON items (updated_at DESC)
  WHERE deleted_at IS NULL;
