-- =============================================================================
-- Migration 0025: Fix publications_by_section_view (add section_id)
-- =============================================================================
-- The original 0024 view did not expose section_id, so the app's
-- `.eq('section_id', ...)` filter failed with "column section_id does not
-- exist". Recreate the view with section_id included. Because the column set
-- changes, Postgres requires DROP + CREATE (CREATE OR REPLACE cannot alter
-- the output columns of a view).
drop view if exists publications_by_section_view;

create view publications_by_section_view as
select
  p.*,
  ps.section_id as section_id
from publications p
join publication_sections ps on ps.publication_id = p.id
where p.status = 'published'
order by p.published_at desc;