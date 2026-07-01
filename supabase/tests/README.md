# Pruebas de esquema + RLS

`rls_smoke_test.sql` valida el esquema y las políticas de seguridad contra un PostgreSQL local
(sin depender de Supabase). Sirve para verificar las migraciones antes de aplicarlas al proyecto real.

## Requisitos

Un PostgreSQL 15/16 local. Supabase provee de fábrica el schema `auth` y ciertos grants; para
reproducirlos localmente hay que crear estos **stubs antes** de correr las migraciones:

```sql
-- 00_stubs.sql
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb default '{}'::jsonb
);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
do $$ begin create role anon;          exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
do $$ begin create role service_role;  exception when duplicate_object then null; end $$;
```

Y estos grants **después** de las migraciones (Supabase los aplica solo):

```sql
-- 99_grants.sql
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant execute on all functions in schema public to anon, authenticated, service_role;
```

## Correr

```bash
psql "$DB" -f 00_stubs.sql
psql "$DB" -f ../migrations/0001_init.sql
psql "$DB" -f ../migrations/0002_events.sql
psql "$DB" -f ../migrations/0003_finance.sql
psql "$DB" -f ../migrations/0004_maintenance.sql
psql "$DB" -f ../migrations/0005_rls.sql
psql "$DB" -f ../seed.sql
psql "$DB" -f 99_grants.sql
psql "$DB" -f rls_smoke_test.sql   # imprime las asserts numeradas
```

El RLS simula al usuario logueado con `set request.jwt.claim.sub = '<uuid>'` y `set role authenticated`,
igual que hace Supabase con el JWT.
