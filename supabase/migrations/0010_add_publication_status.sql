-- =============================================================================
-- Migration 0010: Add status to publications
-- =============================================================================

alter table publications 
add column if not exists status text check (status in ('draft', 'published', 'archived')) default 'draft';