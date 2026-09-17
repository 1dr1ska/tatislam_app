-- =============================================================================
-- Migration 0030: Default section for photo publications
-- =============================================================================
-- A photo publication always needs a primary section. Instead of hard-coding a
-- fixed section, admins choose which section new photo publications should
-- preselect. The flag lives on the sections table itself (sections are dynamic
-- objects), and at most one section can be the default.
-- =============================================================================

alter table sections add column if not exists is_default_for_photo boolean not null default false;

-- Enforce "at most one default": the partial unique index only rows where the
-- flag is true, and every such row produces the same constant index entry.
create unique index if not exists idx_sections_single_photo_default
  on sections ((true))
  where is_default_for_photo = true;