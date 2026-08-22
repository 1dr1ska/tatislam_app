-- =============================================================================
-- Migration 0024: Publications view for section pagination
-- =============================================================================
-- The old app code fetched ALL publication_id rows for a section, then used
-- `.inFilter('id', ...)` on the publications table. With thousands of rows in
-- a section this becomes slow (full id list over the wire + a huge IN clause).
--
-- This view exposes the JOIN publications ↔ publication_sections directly, so
-- PostgREST can apply ordering + range() (limit/offset) inside Postgres —
-- only the requested page of rows is ever returned.
create view publications_by_section_view as
select
  p.*
from publications p
join publication_sections ps on ps.publication_id = p.id
where p.status = 'published'
order by p.published_at desc;