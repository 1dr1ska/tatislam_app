-- =============================================================================
-- Migration 0031: Image albums in content blocks (multiple photos per block)
-- =============================================================================
-- One 'image' content block can now hold several photos. The canonical data
-- shape is an ordered list:
--
--   image -> { "paths": ["blocks/.../a.jpg", "blocks/.../b.jpg", ...] }
--
-- Legacy rows stored a single photo under "path":
--
--   image -> { "path": "blocks/.../a.jpg" }
--
-- The CHECK constraint (since migration 0011) already accepts both shapes,
-- and the app keeps reading both — no schema change is required here.
-- This migration only normalises existing rows to the new canonical format,
-- so every image block is a uniform "paths" array.

-- 1. Backfill legacy single-photo blocks into the new list format. Rows that
--    already use "paths" are left untouched.
update content_blocks
set data = jsonb_build_object('paths', jsonb_build_array(data->>'path'))
where type = 'image'
  and data ? 'path'
  and not data ? 'paths';

-- 2. Keep the documented shape comment in sync with reality.
comment on table content_blocks is $$
A publication's body is an ordered, unbounded list of blocks, in any
combination and any order (text, image, video, audio, and any block type
added later).

Block-specific payload lives in a single `data jsonb` column. Adding a brand
new block type only requires extending the `type` CHECK + a new Dart model
and renderer — no new columns (see the shape CHECK constraint below; future
custom types fall through the `else true` branch intentionally).

Shapes used by the built-in types:

  text  -> { "text": string }
  image -> { "paths": string[] }                       (album, canonical)
        or { "path": string }                          (legacy single photo)
           "path"/"paths" are Storage object paths, resolved to public URLs
           by the app — never public URLs themselves.
  video -> { "url": string, "provider": "youtube"|"rutube"|"vk"|"direct" }
           Always an external URL. Never uploaded to Storage.
  audio -> { "source": "upload", "path": string }
        or { "source": "external", "url": string }
$$;