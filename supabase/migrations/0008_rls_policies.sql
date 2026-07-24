-- =============================================================================
-- Migration 0008: Row Level Security policies
-- =============================================================================
-- Public (anon + authenticated) can only ever READ content.
-- Only users whose profiles.role = 'admin' (checked via is_admin()) may
-- write. This is enforced entirely in the database, so it holds regardless
-- of which client (app, admin panel, future web app) issues the request.
-- =============================================================================

alter table publications enable row level security;
alter table content_blocks enable row level security;
alter table sections enable row level security;
alter table publication_sections enable row level security;

-- ---------------------------------------------------------------------------
-- publications
-- ---------------------------------------------------------------------------
drop policy if exists "publications_select_all" on publications;
create policy "publications_select_all" on publications
  for select using (true);

drop policy if exists "publications_admin_write" on publications;
create policy "publications_admin_write" on publications
  for all using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- content_blocks
-- ---------------------------------------------------------------------------
drop policy if exists "content_blocks_select_all" on content_blocks;
create policy "content_blocks_select_all" on content_blocks
  for select using (true);

drop policy if exists "content_blocks_admin_write" on content_blocks;
create policy "content_blocks_admin_write" on content_blocks
  for all using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- sections
-- ---------------------------------------------------------------------------
-- Public only ever sees visible sections; admins see everything (needed for
-- the section management screen, where hidden sections must still appear).
drop policy if exists "sections_select_visible_or_admin" on sections;
create policy "sections_select_visible_or_admin" on sections
  for select using (is_visible = true or is_admin());

drop policy if exists "sections_admin_write" on sections;
create policy "sections_admin_write" on sections
  for all using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- publication_sections
-- ---------------------------------------------------------------------------
drop policy if exists "publication_sections_select_all" on publication_sections;
create policy "publication_sections_select_all" on publication_sections
  for select using (true);

drop policy if exists "publication_sections_admin_write" on publication_sections;
create policy "publication_sections_admin_write" on publication_sections
  for all using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- Baseline grants (RLS above still restricts every row-level operation)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select on publications, content_blocks, sections, publication_sections to anon, authenticated;
grant insert, update, delete on publications, content_blocks, sections, publication_sections to authenticated;
grant select, update on profiles to authenticated;
grant execute on function is_admin(uuid) to anon, authenticated;
