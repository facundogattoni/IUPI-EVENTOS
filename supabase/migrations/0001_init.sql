-- =====================================================================
-- IUPI Event Manager — 0001 init
-- Extensiones, enums de dominio, perfiles de usuario y utilidades comunes.
-- =====================================================================

create extension if not exists "pgcrypto";      -- gen_random_uuid()

-- Trigger genérico para mantener updated_at (propio, sin depender de extensiones).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Enums de dominio
-- ---------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('admin', 'coordinator', 'worker');
exception when duplicate_object then null; end $$;

do $$ begin
  -- Estados del ciclo de vida de un cumpleaños.
  create type public.event_status as enum (
    'presupuestado',  -- se pasó precio, sin confirmar
    'reservado',      -- confirmado con seña
    'confirmado',     -- todo listo para la fecha
    'completado',     -- ya se realizó
    'cancelado'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.transaction_type as enum ('ingreso', 'gasto');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.maintenance_status as enum ('pendiente', 'en_progreso', 'resuelto');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.maintenance_priority as enum ('baja', 'media', 'alta');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- profiles: un registro por usuario de auth.users
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text        not null default '',
  role        public.user_role not null default 'worker',
  phone       text,
  color       text,               -- color para pintar sus eventos en el calendario
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is 'Datos y rol de cada usuario de la app.';

-- Mantener updated_at automáticamente.
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------------------
-- Alta automática de profile al crearse un usuario en Auth.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------
-- Helpers de rol (usados por las políticas RLS más adelante).
-- ---------------------------------------------------------------------
create or replace function public.my_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.my_role() = 'admin', false);
$$;
