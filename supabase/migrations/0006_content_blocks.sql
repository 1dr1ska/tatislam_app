-- =============================================================================
-- Migration 0006: Content blocks
-- =============================================================================
-- A publication's body is an ordered, unbounded list of blocks, in any
-- combination and any order (text, image, video, audio, and any block type
-- added later).
--
-- Block-specific payload lives in a single `data jsonb` column rather than a
-- growing set of nullable columns (image_path, video_url, audio_path, ...).
-- This is the key extensibility decision: adding a brand new block type
-- (pdf, quote, timeline, map, poll, ...) only requires:
--   1. extending the `type` CHECK below with the new value (one-line migration)
--   2. a new Dart model + renderer in the app
-- No new columns, no schema redesign, no backfill.
--
-- Shapes used by the built-in types (validated by the CHECK constraint
-- below; future/custom types are intentionally NOT constrained here so they
-- never require a migration):
--
--   text  -> { "text": string }
--   image -> { "path": string, "caption"?: string }
--            "path" is a Storage object path, resolved to a public URL by
--            the app — never a public URL itself.
--   video -> { "url": string, "provider": "youtube"|"rutube"|"vk"|"direct",
--              "caption"?: string }
--            Always an external URL. Never uploaded to Storage. `provider`
--            is auto-detected by the app from the URL.
--   audio -> { "source": "upload", "path": string, "caption"?: string }
--         or { "source": "external", "url": string, "caption"?: string }
--            Both an uploaded file (Storage path) and an external URL are
--            supported through the same block type.
-- =============================================================================

create table if not exists content_blocks (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references publications (id) on delete cascade,
  type text not null check (type in ('text', 'image', 'video', 'audio')),
  order_index integer not null default 0,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint content_blocks_data_is_object check (jsonb_typeof(data) = 'object'),

  -- Structural validation for the built-in types only. Custom types added
  -- in the future simply fall through the `else true` branch and are
  -- validated at the application layer instead — this is what keeps new
  -- block types migration-free.
  constraint content_blocks_data_shape check (
    case type
      when 'text' then (data ? 'text')
      when 'image' then (data ? 'path')
      when 'video' then (data ? 'url')
      when 'audio' then (
        (data ->> 'source' = 'upload' and data ? 'path') or
        (data ->> 'source' = 'external' and data ? 'url')
      )
      else true
    end
  )
);

create index if not exists idx_content_blocks_publication_order
  on content_blocks (publication_id, order_index);

drop trigger if exists trg_content_blocks_updated_at on content_blocks;
create trigger trg_content_blocks_updated_at
  before update on content_blocks
  for each row
  execute function set_updated_at();
