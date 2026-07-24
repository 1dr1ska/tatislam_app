-- =============================================================================
-- Migration 0004: Sections
-- =============================================================================
-- Sections are admin-managed content categories (e.g. "Мәкаләләр", "Хутбалар").
-- A publication can belong to any number of sections (see publication_sections).
-- =============================================================================

create table if not exists sections (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  is_visible boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_sections_sort_order on sections (sort_order);
create index if not exists idx_sections_is_visible on sections (is_visible);

drop trigger if exists trg_sections_updated_at on sections;
create trigger trg_sections_updated_at
  before update on sections
  for each row
  execute function set_updated_at();
