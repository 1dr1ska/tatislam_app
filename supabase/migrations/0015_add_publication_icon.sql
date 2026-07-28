-- =============================================================================
-- Migration 0015: Add icon column to publications table
-- =============================================================================
-- The app no longer uses coverImagePath. Instead, each publication gets an icon
-- identifier that maps to a local asset via AppIcons.paths.
-- Example values: 'аудио', 'книга', 'перо', 'руки', 'ютуб', etc.

alter table publications add column if not exists icon text;

-- Copy cover_image_path into icon as a starting point for existing rows
-- (cover_image_path is not removed yet, to allow rollback).
update publications set icon = 'книга' where icon is null;