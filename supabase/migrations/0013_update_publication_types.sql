-- =============================================================================
-- Migration 0013: Update publication type constraint to support audio/video/article
-- =============================================================================
-- The previous migration (0012) only allowed 'article', 'admin', 'news'.
-- We need 'audio', 'video', 'article' for the new type filter tabs.

-- First, update existing 'news' types to 'article' (no 'news' type in the app)
update publications set type = 'article' where type = 'news';

-- Then alter the constraint
alter table publications 
drop constraint if exists publications_type_check;

alter table publications 
add constraint publications_type_check 
check (type in ('article', 'admin', 'audio', 'video'));