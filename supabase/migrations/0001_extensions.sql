-- =============================================================================
-- Migration 0001: Extensions
-- =============================================================================
-- Enables the extensions required by the rest of the schema.
-- pgcrypto provides gen_random_uuid(), used as the default for all primary keys.
-- =============================================================================

create extension if not exists "pgcrypto";
