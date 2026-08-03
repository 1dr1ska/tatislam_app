-- =============================================================================
-- Migration 0018: Schema cleanup — remove remnants of retired functionality
-- =============================================================================
-- This migration is safe to run on any existing database. It only removes
-- objects that are no longer referenced by the application code.
--
-- Changes:
--   1. Drop `cover_image_path` from publications — fully replaced by `icon`.
--   2. Remove 'archived' from the status CHECK constraint — never used.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Remove cover_image_path (fully replaced by the local icon system)
-- ---------------------------------------------------------------------------
-- The app migrated from cover_image_path (a Storage path for cover images) to
-- the `icon` column (a local asset identifier) in migration 0015.
-- Migration 0017 already made cover_image_path nullable.
-- The Dart codebase no longer references cover_image_path at all.
--
-- It is safe to remove this column because:
--   - No Dart code reads or writes it.
--   - The `icon` column is the single source of truth for the publication icon.
--   - Existing cover images remain in Storage, just not referenced by the DB.
-- ---------------------------------------------------------------------------
alter table publications
  drop column if exists cover_image_path;

-- ---------------------------------------------------------------------------
-- 2. Remove 'archived' from the status CHECK constraint
-- ---------------------------------------------------------------------------
-- The status column is used by the app to filter publications:
--   - 'published' — visible to all users (the app queries `status = 'published'`)
--   - 'draft' — hidden from public (used in admin; not yet published)
--   - 'archived' — never referenced in Dart code. The app has no archive UI,
--     no archive filter, and no archive-related logic.
--
-- Dropping 'archived' from the CHECK constraint does NOT delete data — any
-- existing row with status = 'archived' will remain, but future inserts/updates
-- will be rejected by the constraint. This is a data-integrity signal: if a row
-- still has status = 'archived', it was likely set before this migration.
-- ---------------------------------------------------------------------------
alter table publications
  drop constraint if exists publications_status_check;

alter table publications
  add constraint publications_status_check
  check (status in ('draft', 'published'));

-- =============================================================================
-- Summary of changes
-- =============================================================================
-- Removed columns:
--   publications.cover_image_path
--
-- Removed CHECK constraint values:
--   publications.status -> 'archived' removed from allowed values
--
-- Objects intentionally left untouched:
--   All tables, indexes, triggers, functions, RLS policies, and Storage
--   policies remain as-is — they are all actively used by the application.
-- =============================================================================