-- =============================================================================
-- Migration 0002: Helper functions
-- =============================================================================
-- Generic trigger function that keeps `updated_at` columns in sync.
-- Reused by every table that has an `updated_at` column.
-- =============================================================================

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;
