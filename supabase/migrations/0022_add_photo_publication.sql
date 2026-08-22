-- =============================================================================
-- Migration 0022: Photo publication type
-- =============================================================================
-- Adds a new 'photo' publication type. A photo publication is a full-screen
-- rectangle showing a single image (in its original aspect ratio) instead of
-- an icon + title card. The image's Storage path lives on the publications row
-- itself (<photo_path>), so the home grid can render the photo without loading
-- content_blocks.

-- 1. photo_path — Storage path of the single photo, only set for 'photo' rows.
alter table publications add column if not exists photo_path text;

-- 2. Add 'photo' to the type CHECK constraint.
alter table publications
  drop constraint if exists publications_type_check;

alter table publications
  add constraint publications_type_check
  check (type in ('article', 'admin', 'audio', 'video', 'photo'));