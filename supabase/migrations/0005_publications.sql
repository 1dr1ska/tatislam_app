-- =============================================================================
-- Migration 0005: Publications
-- =============================================================================
-- Publication metadata only. The actual body of a publication is an ordered
-- list of rows in content_blocks (see migration 0006). This keeps
-- publications lightweight and lets a publication contain any mix of
-- text/image/video/audio blocks in any order.
--
-- cover_image_path stores a Storage *path* (not a full URL), e.g.
-- "covers/<publication_id>.jpg". The app resolves this to a public URL via
-- Supabase Storage, which keeps the DB decoupled from bucket/CDN changes.
-- =============================================================================

create table if not exists publications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  cover_image_path text not null,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_publications_published_at on publications (published_at desc);

drop trigger if exists trg_publications_updated_at on publications;
create trigger trg_publications_updated_at
  before update on publications
  for each row
  execute function set_updated_at();
