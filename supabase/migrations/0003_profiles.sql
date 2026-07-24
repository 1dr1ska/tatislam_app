-- =============================================================================
-- Migration 0003: Profiles (auth / roles)
-- =============================================================================
-- Mirrors auth.users with an application-level profile that carries the role.
-- The `role` column is the single source of truth for admin permissions and
-- is checked by the is_admin() helper used throughout RLS policies.
-- =============================================================================

-- First, drop any existing conflicting functions and dependencies
-- This is necessary to avoid naming conflicts with existing database objects
DROP FUNCTION IF EXISTS is_admin(uuid) CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_role on profiles (role);

drop trigger if exists trg_profiles_updated_at on profiles;
create trigger trg_profiles_updated_at
  before update on profiles
  for each row
  execute function set_updated_at();

-- Automatically create a profile row whenever a new auth user signs up.
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email, 'user')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function handle_new_user();

-- Security-definer helper so RLS policies can check admin rights without
-- causing recursive RLS evaluation on the profiles table itself.
create or replace function is_admin(uid uuid default auth.uid())
returns boolean as $$
begin
  return exists (
    select 1 from profiles
    where id = uid and role = 'admin'
  );
end;
$$ language plpgsql security definer set search_path = public stable;

alter table profiles enable row level security;

drop policy if exists "profiles_select_own" on profiles;
create policy "profiles_select_own" on profiles
  for select using (auth.uid() = id or is_admin());

drop policy if exists "profiles_update_own" on profiles;
create policy "profiles_update_own" on profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);