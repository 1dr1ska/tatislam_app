-- =============================================================================
-- Migration 0011: Support image galleries in content blocks
-- =============================================================================
-- This migration updates the content_blocks table to support image galleries
-- while maintaining backward compatibility with existing single-image blocks.
--
-- The updated schema allows for:
--   image -> { "path": string, "caption"?: string } (single image, backward compatible)
--         or { "paths": string[], "captions"?: string[] } (gallery, new format)
-- =============================================================================

-- Drop the old constraint
alter table content_blocks drop constraint content_blocks_data_shape;

-- Add the new constraint that supports both single images and galleries
alter table content_blocks
  add constraint content_blocks_data_shape check (
    case type
      when 'text' then (data ? 'text')
      when 'image' then (
        -- Either single image format (backward compatibility)
        (data ? 'path') or
        -- Or gallery format (new)
        (data ? 'paths' and jsonb_typeof(data->'paths') = 'array')
      )
      when 'video' then (data ? 'url')
      when 'audio' then (
        (data ->> 'source' = 'upload' and data ? 'path') or
        (data ->> 'source' = 'external' and data ? 'url')
      )
      else true
    end
  );

-- Update the documentation comment in the migration
comment on table content_blocks is $$
A publication's body is an ordered, unbounded list of blocks, in any
combination and any order (text, image, video, audio, and any block type
added later).

Block-specific payload lives in a single `data jsonb` column rather than a
growing set of nullable columns (image_path, video_url, audio_path, ...).
This is the key extensibility decision: adding a brand new block type
(pdf, quote, timeline, map, poll, ...) only requires:
  1. extending the `type` CHECK with the new value (one-line migration)
  2. a new Dart model + renderer in the app
No new columns, no schema redesign, no backfill.

Shapes used by the built-in types (validated by the CHECK constraint
below; future/custom types are intentionally NOT constrained here so they
never require a migration):

  text  -> { "text": string }
  image -> { "path": string, "caption"?: string } (single image)
        or { "paths": string[], "captions"?: string[] } (gallery)
           "path" or "paths" are Storage object paths, resolved to public URLs
           by the app — never public URLs themselves.
  video -> { "url": string, "provider": "youtube"|"rutube"|"vk"|"direct",
             "caption"?: string }
           Always an external URL. Never uploaded to Storage. `provider`
           is auto-detected by the app from the URL.
  audio -> { "source": "upload", "path": string, "caption"?: string }
        or { "source": "external", "url": string, "caption"?: string }
           Both an uploaded file (Storage path) and an external URL are
           supported through the same block type.
$$;