-- =============================================================================
-- Migration 0029: GRANT для service_role
-- =============================================================================
-- В этом проекте default-привилегии (ALTER DEFAULT PRIVILEGES) для роли
-- service_role не были установлены, поэтому серверный код, работающий через
-- service_role (Edge Function notify-new-publication, Python-импортёр, сброс
-- is_active для невалидных FCM-токенов), получал от PostgREST:
--   "permission denied for table publications … TO service_role"
--
-- Выдаём роли service_role полные DML-права на схему public. RLS при этом
-- для service_role по-прежнему обходится штатно (BYPASSRLS) — гранты лишь
-- делают таблицы доступными на уровне PostgreSQL, как это делает Supabase
-- по умолчанию. Клиенты (anon/authenticated) НЕ затрагиваются: права на
-- notification_devices / publication_notifications у них отсутствуют, и RLS
-- для них остаётся закрытой (см. миграцию 0028).
-- =============================================================================

grant select, insert, update, delete on publications to service_role;
grant select, insert, update, delete on content_blocks to service_role;
grant select, insert, update, delete on sections to service_role;
grant select, insert, update, delete on publication_sections to service_role;
grant select, insert, update, delete on notification_devices to service_role;
grant select, insert, update, delete on publication_notifications to service_role;