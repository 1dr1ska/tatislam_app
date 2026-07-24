-- =============================================================================
-- Migration 0009: Storage bucket & policies
-- =============================================================================
-- A single public bucket "media" holds all admin-uploaded files. Video is
-- never uploaded here — it is always an external URL (see content_blocks).
--
-- Folder structure (enforced by convention in the app, not by the DB):
--
--   media/
--     covers/<publication_id>.<ext>              cover images
--     blocks/<publication_id>/images/<block_id>.<ext>   inline images
--     blocks/<publication_id>/audio/<block_id>.<ext>    uploaded audio
--
-- Grouping by publication_id keeps related files together and makes manual
-- cleanup straightforward if a publication is deleted.
-- =============================================================================

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

drop policy if exists "media_public_read" on storage.objects;
create policy "media_public_read" on storage.objects
  for select using (bucket_id = 'media');

drop policy if exists "media_admin_insert" on storage.objects;
create policy "media_admin_insert" on storage.objects
  for insert with check (bucket_id = 'media' and is_admin());

drop policy if exists "media_admin_update" on storage.objects;
create policy "media_admin_update" on storage.objects
  for update using (bucket_id = 'media' and is_admin());

drop policy if exists "media_admin_delete" on storage.objects;
create policy "media_admin_delete" on storage.objects
  for delete using (bucket_id = 'media' and is_admin());
