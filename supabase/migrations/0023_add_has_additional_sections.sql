-- =============================================================================
-- Migration 0023: Toggle for additional sections on publications
-- =============================================================================
-- Adds a per-publication flag controlling whether the additional-sections
-- feature is enabled. When disabled, the publication appears only in its
-- primary section regardless of any stored section memberships.
alter table publications add column if not exists has_additional_sections boolean not null default false;
