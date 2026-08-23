-- =============================================================================
-- Migration 0024: Publications view for section pagination
-- =============================================================================
-- Exposes the JOIN publications ↔ publication_sections INCLUDING section_id,
-- so PostgREST can apply `eq(section_id, ...)`, ordering and range()
-- (limit/offset) inside Postgres. Only the requested page of rows is returned.
--
-- Note: the view always filters status='published' — it is intended for
-- public (non-admin) reads only. Drafts are never part of the join output.
create view publications_by_section_view as
select
  p.*,
  ps.section_id as section_id
from publications p
join publication_sections ps on ps.publication_id = p.id
where p.status = 'published'
order by p.published_at desc;