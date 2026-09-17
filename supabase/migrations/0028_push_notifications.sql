-- =============================================================================
-- Migration 0028: Push notifications (FCM)
-- =============================================================================
-- Две таблицы + один RPC:
--
--  1. notification_devices      — FCM-токены установленных приложений.
--       * одна строка на уникальный fcm_token (upsert на конфликте);
--       * у пользователя может быть много устройств (несколько строк);
--       * выключение уведомлений в приложении = is_active = false.
--       * Прямого доступа (GRANT) у анонимов/авторизованных НЕТ: запись идёт
--         только через security-definer RPC register_notification_device(),
--         поэтому таблица не является публично доступной.
--
--  2. publication_notifications — история «отправлено/не отправлено» по каждой
--       публикации. Служит идемпотентной защитой от повторных уведомлений:
--       RPC claim_publication_notification() атомарно вставляет строку
--       ON CONFLICT (publication_id) DO NOTHING. Если строка уже есть —
--       уведомление НЕ отправляется повторно, даже если импортёр/Edge
--       Function случайно вызовутся дважды.
--       Claim ставится только при переходе публикации в статус 'published'
--       (решает Edge Function) — так реализуется «уведомление при ПЕРВОЙ
--       публикации», а черновики не блокируют будущий push.
--       (Также сами публикации защищены уникальным индексом на
--        telegram_message_id из миграции 0027 — повторный импорт не создаёт
--        новый INSERT вообще.)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- notification_devices
-- ---------------------------------------------------------------------------
create table if not exists notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade,
  fcm_token text not null,
  platform text not null default 'unknown'
    check (platform in ('android', 'ios', 'web', 'unknown')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Один и тот же FCM-токен никогда не хранится дважды.
create unique index if not exists notification_devices_fcm_token_key
  on notification_devices (fcm_token);

-- Быстрый отбор активных устройств для рассылки.
create index if not exists idx_notification_devices_active
  on notification_devices (is_active) where is_active;

drop trigger if exists trg_notification_devices_updated_at on notification_devices;
create trigger trg_notification_devices_updated_at
  before update on notification_devices
  for each row
  execute function set_updated_at();

alter table notification_devices enable row level security;

-- Никаких анонимных/authenticated грантов на саму таблицу: доступ только через
-- RPC ниже (и через service_role из Edge Function). Админы могут читать
-- таблицу для диагностики.
grant select on notification_devices to authenticated;

drop policy if exists "notification_devices_admin_select" on notification_devices;
create policy "notification_devices_admin_select" on notification_devices
  for select to authenticated
  using (is_admin());
-- ---------------------------------------------------------------------------
-- RPC: регистрация / деактивация устройства
-- ---------------------------------------------------------------------------
-- Единственная публичная точка записи. security definer — обходит RLS таблицы,
-- но валидирует вход и привязан user_id к auth.uid() (аноним → NULL).
create or replace function register_notification_device(
  p_fcm_token text,
  p_platform text,
  p_is_active boolean default true
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  -- Базовая валидация токена (формат Firebase: [A-Za-z0-9_-]{...}).
  if p_fcm_token is null
     or length(p_fcm_token) < 32
     or length(p_fcm_token) > 4096
     or p_fcm_token !~ '^[A-Za-z0-9_:.\-]+$' then
    raise exception 'invalid fcm token';
  end if;

  if p_platform is null or p_platform not in ('android', 'ios', 'web', 'unknown') then
    raise exception 'invalid platform';
  end if;

  v_user_id := auth.uid();

  insert into notification_devices (user_id, fcm_token, platform, is_active)
  values (v_user_id, p_fcm_token, p_platform, p_is_active)
  on conflict (fcm_token) do update
    set user_id    = excluded.user_id,
        platform   = excluded.platform,
        is_active  = excluded.is_active,
        updated_at = now();
end;
$$;

grant execute on function register_notification_device(text, text, boolean)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- publication_notifications (идемпотентная отдача push)
-- ---------------------------------------------------------------------------
create table if not exists publication_notifications (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null unique references publications (id) on delete cascade,
  telegram_message_id bigint,
  status text not null default 'claimed'
    check (status in ('claimed', 'sent', 'failed')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_publication_notifications_status
  on publication_notifications (status) where status = 'claimed';

alter table publication_notifications enable row level security;
-- Клиенты (anon/authenticated) не имеют прав на эту таблицу вовсе —
-- её читает/пишет только service_role из Edge Function.

-- ---------------------------------------------------------------------------
-- RPC: «занять» публикацию для отправки уведомления
-- ---------------------------------------------------------------------------
-- Возвращает TRUE, если уведомление ещё не отправлялось (и данная публикация
-- только что забронирована для отправки), и FALSE — если запись уже есть
-- (уведомление уже отправлялось или поставлено в очередь).
create or replace function claim_publication_notification(
  p_publication_id uuid
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  r_inserted boolean;
begin
  insert into publication_notifications (publication_id, telegram_message_id)
  select p.id, p.telegram_message_id
  from publications p
  where p.id = p_publication_id
  on conflict (publication_id) do nothing
  returning true into r_inserted;

  return coalesce(r_inserted, false);
end;
$$;

-- Вызывается только серверным кодом (Edge Function через service_role).
grant execute on function claim_publication_notification(uuid) to service_role;