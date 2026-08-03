-- =============================================================================
-- Migration 0019: Remove unused 'caption' and 'captions' from content_blocks data
-- =============================================================================
-- These fields are never displayed to the user, not editable, and not used
-- for search/filter/sort. The Dart codebase has been cleaned of all references.
-- This migration removes them from existing rows so the JSON stays clean.
-- =============================================================================

-- Remove 'caption' from image blocks (single-image format)
update content_blocks set data = data - 'caption' where type = 'image' and data ? 'caption';

-- Remove 'captions' from image blocks (gallery format)
update content_blocks set data = data - 'captions' where type = 'image' and data ? 'captions';

-- Remove 'caption' from video blocks
update content_blocks set data = data - 'caption' where type = 'video' and data ? 'caption';

-- Remove 'caption' from audio blocks
update content_blocks set data = data - 'caption' where type = 'audio' and data ? 'caption';