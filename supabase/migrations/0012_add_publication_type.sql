-- =============================================================================
-- Migration 0012: Add type column to publications
-- =============================================================================
-- This migration adds a type column to the publications table to match the
-- PublicationModel in the Dart code. The type field is used to distinguish
-- between different types of publications (e.g., article, admin, news).

alter table publications 
add column if not exists type text not null default 'article' check (type in ('article', 'admin', 'news'));