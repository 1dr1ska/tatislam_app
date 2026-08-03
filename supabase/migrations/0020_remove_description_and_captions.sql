-- =============================================================================
-- Migration 0020: Remove unused columns — description, caption, captions
-- =============================================================================
-- Removes the description column from publications (fully replaced by
-- content blocks) and cleans up any remaining caption/captions fields
-- from content_blocks data that were missed in migration 0019.
-- =============================================================================

-- Remove description from publications (replaced by content blocks)
alter table publications drop column if exists description;

-- Clean up any remaining caption/captions from content_blocks JSONB data
update content_blocks set data = data - 'caption' where data ? 'caption';
update content_blocks set data = data - 'captions' where data ? 'captions';