-- =============================================================================
-- Migration 0014: Add background_image to sections
-- =============================================================================
-- Each section can now have an optional background image path (relative to assets/).
-- If null, the default background is used on the main screen.
-- =============================================================================

alter table sections add column if not exists background_image text;