-- =============================================================================
-- Migration 0027: Telegram message id on publications
-- =============================================================================
-- Позволяет Telegram-импортёру быть идемпотентным: каждая импортированная
-- публикация запоминает исходный telegram message id, поэтому повторный
-- запуск не создаёт дубликатов.
--
--   telegram_message_id — исходный id сообщения канала (для альбома — id
--                         первого сообщения группы);
--   source_url         — ссылка на исходную публикацию в Telegram
--                         (https://t.me/<channel>/<message_id>), если у
--                         канала есть username.
--
-- Оба поля необязательны, чтобы существующие строки не затрагивались.
-- =============================================================================

alter table publications add column if not exists telegram_message_id bigint;
alter table publications add column if not exists source_url text;

-- Partial unique index: один telegram message id импортируется только один раз.
-- Существующие строки (NULL) не затрагиваются.
create unique index if not exists idx_publications_telegram_message_id
  on publications (telegram_message_id)
  where telegram_message_id is not null;