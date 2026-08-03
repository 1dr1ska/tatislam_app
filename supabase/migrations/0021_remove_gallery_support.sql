-- =============================================================================
-- Migration 0021: Remove gallery support from content_blocks
-- =============================================================================
-- Converts existing content_blocks that have 'paths' (array) in their data
-- to the new 'path' (single string) format. Once the old data is migrated,
-- only the 'path' key is used for image blocks.
-- =============================================================================

-- Convert galleries: take the first path from the array and store it as 'path'
update content_blocks
set data = jsonb_build_object('path', data->'paths'->>0)
where data ? 'paths' and not data ? 'path';

-- Remove any remaining 'paths' keys that weren't migrated (shouldn't exist,
-- but just in case)
update content_blocks set data = data - 'paths' where data ? 'paths';