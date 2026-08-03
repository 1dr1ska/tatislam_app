-- =============================================================================
-- Seed Data
-- =============================================================================
-- A handful of starter sections so the Catalog/Admin screens aren't empty on
-- first run. Purely optional — admins can rename/hide/delete these freely.
-- =============================================================================

insert into sections (name, slug, sort_order) values
  ('Мәкаләләр', 'articles', 0),
  ('Видео', 'video', 1),
  ('Аудио', 'audio', 2)
on conflict (slug) do nothing;

-- =============================================================================
-- Sample Publications
-- =============================================================================

-- Sample article publication
insert into publications (
  id, 
  title, 
  cover_image_path, 
  published_at, 
  created_at, 
  updated_at,
  status,
  type,
  primary_section_id
) values (
  '11111111-1111-1111-1111-111111111111',
  'Сәлам, дөньия!',
  'covers/11111111-1111-1111-1111-111111111111.jpg',
  '2024-01-01 12:00:00+00',
  '2024-01-01 12:00:00+00',
  '2024-01-01 12:00:00+00',
  'published',
  'article',
  (select id from sections where slug = 'articles' limit 1)
) on conflict (id) do nothing;

-- Insert content blocks for the article publication
insert into content_blocks (
  publication_id,
  type,
  order_index,
  data
) values (
  '11111111-1111-1111-1111-111111111111',
  'text',
  0,
  '{"text": "Бу кушымта Татарлар Ислам Китапханәсе һәм Мәгариф берлекле проекты булып тора. Безнең телдә төзелгән контентларыгызны укыгыз!"}'
) on conflict do nothing;

-- Sample video publication
insert into publications (
  id, 
  title, 
  cover_image_path, 
  published_at, 
  created_at, 
  updated_at,
  status,
  type,
  primary_section_id
) values (
  '22222222-2222-2222-2222-222222222222',
  'Видео дәрес',
  'covers/22222222-2222-2222-2222-222222222222.jpg',
  '2024-01-02 12:00:00+00',
  '2024-01-02 12:00:00+00',
  '2024-01-02 12:00:00+00',
  'published',
  'article',
  (select id from sections where slug = 'video' limit 1)
) on conflict (id) do nothing;

-- Sample audio publication
insert into publications (
  id, 
  title, 
  cover_image_path, 
  published_at, 
  created_at, 
  updated_at,
  status,
  type,
  primary_section_id
) values (
  '33333333-3333-3333-3333-333333333333',
  'Аудио хикәя',
  'covers/33333333-3333-3333-3333-333333333333.jpg',
  '2024-01-03 12:00:00+00',
  '2024-01-03 12:00:00+00',
  '2024-01-03 12:00:00+00',
  'published',
  'article',
  (select id from sections where slug = 'audio' limit 1)
) on conflict (id) do nothing;

-- Sample draft publication
insert into publications (
  id, 
  title, 
  cover_image_path, 
  published_at, 
  created_at, 
  updated_at,
  status,
  type,
  primary_section_id
) values (
  '44444444-4444-4444-4444-444444444444',
  'Эшкәртелеш барынча',
  'covers/44444444-4444-4444-4444-444444444444.jpg',
  '2025-01-01 12:00:00+00',
  '2024-01-04 12:00:00+00',
  '2024-01-04 12:00:00+00',
  'draft',
  'article',
  (select id from sections where slug = 'articles' limit 1)
) on conflict (id) do nothing;

-- Insert content blocks for the draft publication
insert into content_blocks (
  publication_id,
  type,
  order_index,
  data
) values (
  '44444444-4444-4444-4444-444444444444',
  'text',
  0,
  '{"text": "Бу мәкалә эшкәртелеш барынча һәм әлеге вакытта өченче күренми."}'
) on conflict do nothing;

-- Sample archived publication
insert into publications (
  id, 
  title, 
  cover_image_path, 
  published_at, 
  created_at, 
  updated_at,
  status,
  type,
  primary_section_id
) values (
  '55555555-5555-5555-5555-555555555555',
  'Истәлекле мәкалә',
  'covers/55555555-5555-5555-5555-555555555555.jpg',
  '2023-01-01 12:00:00+00',
  '2023-01-01 12:00:00+00',
  '2023-01-01 12:00:00+00',
  'archived',
  'article',
  (select id from sections where slug = 'articles' limit 1)
) on conflict (id) do nothing;

-- Insert content blocks for the archived publication
insert into content_blocks (
  publication_id,
  type,
  order_index,
  data
) values (
  '55555555-5555-5555-5555-555555555555',
  'text',
  0,
  '{"text": "Бу мәкалә архивланган һәм әлеге вакытта өченче күренми."}'
) on conflict do nothing;