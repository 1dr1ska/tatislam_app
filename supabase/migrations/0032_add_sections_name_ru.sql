-- =============================================================================
-- Migration 0032: Russian section name
-- =============================================================================
-- Sections can now carry an optional Russian name. When the app's interface
-- language is Russian this name is shown instead of the primary (Tatar) one.
-- The name is stored in the section entity as `name` and read from `name_ru`;
-- when `name_ru` is null/blank the primary name is used as a fallback.

alter table sections
  add column if not exists name_ru text;

comment on column sections.name_ru is
  'Optional Russian name shown when the interface language is Russian.';