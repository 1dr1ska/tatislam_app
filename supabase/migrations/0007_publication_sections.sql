-- =============================================================================
-- Migration 0007: Publication <-> Section (many-to-many)
-- =============================================================================

create table if not exists publication_sections (
  publication_id uuid not null references publications (id) on delete cascade,
  section_id uuid not null references sections (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (publication_id, section_id)
);

create index if not exists idx_publication_sections_section_id
  on publication_sections (section_id);
