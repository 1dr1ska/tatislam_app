-- =============================================================================
-- Migration 0017: Make cover_image_path nullable
-- =============================================================================
-- The app has migrated from cover_image_path to the local icon system.
-- cover_image_path is no longer used by the application code.
-- Making it nullable to allow creating publications without a cover image.
-- =============================================================================

alter table publications
  alter column cover_image_path drop not null;