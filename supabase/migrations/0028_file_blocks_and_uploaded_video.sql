-- =============================================================================
-- Migration 0028: file blocks and uploaded video
-- =============================================================================
-- 1. Новый тип блока `file` (pdf, docx и любые другие файлы):
--      file -> { "path": "files/<uuid>.<ext>", "name"?: ..., "mime"?: ..., "size"?: ... }
--
-- 2. У `video` появляется формат «загружено в Storage» — как у audio upload:
--      video -> { "source": "upload", "path": "videos/<uuid>.<ext>", ... }
--    Внешние видео (youtube/rutube/vk/direct) по-прежнему { "url", "provider" }.
-- =============================================================================

alter table content_blocks drop constraint if exists content_blocks_type_check;
alter table content_blocks
  add constraint content_blocks_type_check
  check (type in ('text', 'image', 'video', 'audio', 'file'));

alter table content_blocks drop constraint if exists content_blocks_data_shape;

alter table content_blocks
  add constraint content_blocks_data_shape check (
    case type
      when 'text' then (data ? 'text')
      when 'image' then (
        (data ? 'path') or
        (data ? 'paths' and jsonb_typeof(data->'paths') = 'array')
      )
      when 'video' then (
        (data ? 'url') or
        (data ->> 'source' = 'upload' and data ? 'path')
      )
      when 'audio' then (
        (data ->> 'source' = 'upload' and data ? 'path') or
        (data ->> 'source' = 'external' and data ? 'url')
      )
      when 'file' then (data ? 'path')
      else true
    end
  );