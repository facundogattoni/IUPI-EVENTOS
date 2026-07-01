-- =====================================================================
-- IUPI Event Manager — esquema COMPLETO en un solo archivo.
--
-- Generado a partir de migrations/0001..0005 + seed.sql.
-- Pensado para pegar de una sola vez en el SQL Editor de Supabase.
-- (Para desarrollo con la CLI, usá las migraciones sueltas en migrations/).
--
-- Es idempotente: se puede correr varias veces sin romper nada.
-- =====================================================================


-- #####################################################################
-- ## 0001_init.sql
-- #####################################################################

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

-- #####################################################################
-- ## 0002_events.sql
-- #####################################################################

-- =====================================================================
-- IUPI Event Manager — 0002 eventos (cumpleaños)
-- El corazón de la app: eventos, trabajadores asignados y pagos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- events: cada cumpleaños
-- ---------------------------------------------------------------------
create table if not exists public.events (
  id              uuid primary key default gen_random_uuid(),

  -- Festejado / datos principales
  child_name      text        not null,
  child_age       smallint,
  event_date      date        not null,
  start_time      time,
  end_time        time,

  -- Cantidades
  kids_count      smallint,
  adults_count    smallint,

  -- Contacto del cliente
  client_name     text,
  client_phone    text,

  -- Logística
  drinks_time     time,                 -- hora en que llevan las bebidas
  food_notes      text,                 -- qué comida llevan (si informan)
  notes           text,                 -- observaciones generales

  -- Dinero (pesos argentinos)
  price           numeric(12,2) not null default 0,
  deposit         numeric(12,2) not null default 0,   -- seña acordada

  -- Organización
  status          public.event_status not null default 'presupuestado',
  coordinator_id  uuid references public.profiles(id) on delete set null,

  created_by      uuid references public.profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint events_time_order check (end_time is null or start_time is null or end_time >= start_time),
  constraint events_amounts_nonneg check (price >= 0 and deposit >= 0)
);

comment on table public.events is 'Cumpleaños administrados en el salón.';

create index if not exists events_date_idx on public.events(event_date);
create index if not exists events_status_idx on public.events(status);
create index if not exists events_coordinator_idx on public.events(coordinator_id);

drop trigger if exists events_set_updated_at on public.events;
create trigger events_set_updated_at
  before update on public.events
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------------------
-- event_staff: trabajadores asignados a un evento (N a N)
-- ---------------------------------------------------------------------
create table if not exists public.event_staff (
  event_id    uuid not null references public.events(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  role_note   text,           -- ej: "cocina", "animación", "recepción"
  created_at  timestamptz not null default now(),
  primary key (event_id, profile_id)
);

comment on table public.event_staff is 'Trabajadores asignados a cada cumpleaños.';

create index if not exists event_staff_profile_idx on public.event_staff(profile_id);

-- ---------------------------------------------------------------------
-- event_payments: pagos registrados de un evento (seña y saldos)
-- El saldo pendiente se calcula: price - sum(pagos).
-- ---------------------------------------------------------------------
create table if not exists public.event_payments (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  amount      numeric(12,2) not null check (amount > 0),
  paid_at     date not null default current_date,
  method      text,           -- efectivo, transferencia, etc.
  note        text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

comment on table public.event_payments is 'Pagos parciales de cada evento (seña + saldos).';

create index if not exists event_payments_event_idx on public.event_payments(event_id);

-- ---------------------------------------------------------------------
-- Vista de conveniencia: evento con total pagado y saldo pendiente.
-- ---------------------------------------------------------------------
create or replace view public.events_with_balance as
  select
    e.*,
    coalesce(p.total_paid, 0)              as total_paid,
    (e.price - coalesce(p.total_paid, 0))  as balance_due
  from public.events e
  left join (
    select event_id, sum(amount) as total_paid
    from public.event_payments
    group by event_id
  ) p on p.event_id = e.id;

-- #####################################################################
-- ## 0003_finance.sql
-- #####################################################################

-- =====================================================================
-- IUPI Event Manager — 0003 gestión del negocio
-- Proveedores, libro de ingresos/gastos e inventario.
-- =====================================================================

-- ---------------------------------------------------------------------
-- suppliers: proveedores
-- ---------------------------------------------------------------------
create table if not exists public.suppliers (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  category    text,           -- comida, bebidas, decoración, limpieza, ...
  phone       text,
  email       text,
  notes       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.suppliers is 'Proveedores del salón.';

drop trigger if exists suppliers_set_updated_at on public.suppliers;
create trigger suppliers_set_updated_at
  before update on public.suppliers
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------------------
-- transactions: libro de ingresos y gastos (alimenta el dashboard)
-- Un ingreso puede vincularse a un evento; un gasto/compra a un proveedor.
-- ---------------------------------------------------------------------
create table if not exists public.transactions (
  id          uuid primary key default gen_random_uuid(),
  type        public.transaction_type not null,
  category    text not null,            -- alquiler, sueldos, comida, servicios, ...
  amount      numeric(12,2) not null check (amount > 0),
  occurred_on date not null default current_date,
  description text,
  event_id    uuid references public.events(id) on delete set null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.transactions is 'Ingresos y gastos del negocio.';

create index if not exists transactions_date_idx on public.transactions(occurred_on);
create index if not exists transactions_type_idx on public.transactions(type);
create index if not exists transactions_event_idx on public.transactions(event_id);

drop trigger if exists transactions_set_updated_at on public.transactions;
create trigger transactions_set_updated_at
  before update on public.transactions
  for each row execute procedure public.set_updated_at();

-- Registrar un pago de evento como ingreso en el libro, automáticamente.
create or replace function public.log_payment_as_income()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.transactions (type, category, amount, occurred_on, description, event_id, created_by)
  values (
    'ingreso', 'Pago de evento', new.amount, new.paid_at,
    coalesce(new.note, 'Pago de cumpleaños'), new.event_id, new.created_by
  );
  return new;
end;
$$;

drop trigger if exists event_payment_to_income on public.event_payments;
create trigger event_payment_to_income
  after insert on public.event_payments
  for each row execute procedure public.log_payment_as_income();

-- ---------------------------------------------------------------------
-- inventory_items: insumos / vajilla con alerta de stock mínimo
-- ---------------------------------------------------------------------
create table if not exists public.inventory_items (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  category      text,             -- vajilla, limpieza, decoración, cocina, ...
  quantity      numeric(12,2) not null default 0,
  min_quantity  numeric(12,2) not null default 0,
  unit          text,             -- unidades, kg, litros, ...
  notes         text,
  updated_at    timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

comment on table public.inventory_items is 'Stock de insumos y vajilla; alerta cuando quantity <= min_quantity.';

drop trigger if exists inventory_set_updated_at on public.inventory_items;
create trigger inventory_set_updated_at
  before update on public.inventory_items
  for each row execute procedure public.set_updated_at();

-- #####################################################################
-- ## 0004_maintenance.sql
-- #####################################################################

-- =====================================================================
-- IUPI Event Manager — 0004 mantenimiento
-- Tareas de mantenimiento con prioridad, vencimiento y recurrencia.
-- =====================================================================

create table if not exists public.maintenance_tasks (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  category      text,             -- inflable, horno, matafuegos, aire, electricidad, plomería, ...
  description   text,
  status        public.maintenance_status  not null default 'pendiente',
  priority      public.maintenance_priority not null default 'media',
  due_date      date,             -- vencimiento / recordatorio
  cost          numeric(12,2),    -- costo si corresponde
  -- Recurrencia simple: cada N días (ej: matafuegos cada 365). null = una sola vez.
  recur_days    integer check (recur_days is null or recur_days > 0),
  assigned_to   uuid references public.profiles(id) on delete set null,
  resolved_at   date,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.maintenance_tasks is
  'Tareas de mantenimiento del salón (reparaciones, controles periódicos, compras de limpieza).';

create index if not exists maintenance_status_idx on public.maintenance_tasks(status);
create index if not exists maintenance_due_idx on public.maintenance_tasks(due_date);

drop trigger if exists maintenance_set_updated_at on public.maintenance_tasks;
create trigger maintenance_set_updated_at
  before update on public.maintenance_tasks
  for each row execute procedure public.set_updated_at();

-- Al marcar resuelta una tarea recurrente, generar automáticamente la próxima.
create or replace function public.spawn_recurring_maintenance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'resuelto' and (old.status is distinct from 'resuelto')
     and new.recur_days is not null then
    insert into public.maintenance_tasks
      (title, category, description, priority, due_date, recur_days, assigned_to, created_by)
    values (
      new.title, new.category, new.description, new.priority,
      coalesce(new.due_date, current_date) + (new.recur_days || ' days')::interval,
      new.recur_days, new.assigned_to, new.created_by
    );
  end if;
  return new;
end;
$$;

drop trigger if exists maintenance_recurrence on public.maintenance_tasks;
create trigger maintenance_recurrence
  after update on public.maintenance_tasks
  for each row execute procedure public.spawn_recurring_maintenance();

-- #####################################################################
-- ## 0005_rls.sql
-- #####################################################################

-- =====================================================================
-- IUPI Event Manager — 0005 Row Level Security
-- "El que necesita ver poco, ve poco". Las reglas viven en la base.
-- =====================================================================

-- La vista de saldos debe respetar RLS del que consulta, no del dueño.
alter view public.events_with_balance set (security_invoker = true);

-- ---------------------------------------------------------------------
-- Helpers SECURITY DEFINER para los chequeos cruzados entre events y
-- event_staff. Al ser DEFINER saltan el RLS de esas tablas y evitan la
-- recursión infinita que se produce si una política consulta la otra tabla
-- protegida (events -> event_staff -> events -> ...).
-- ---------------------------------------------------------------------
create or replace function public.is_event_coordinator(eid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = eid and e.coordinator_id = auth.uid()
  );
$$;

create or replace function public.is_event_staff(eid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.event_staff s
    where s.event_id = eid and s.profile_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using (auth.uid() is not null);          -- ver nombres del equipo (interno)

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------
-- events: admin ve todo; coordinador los que coordina; trabajador los asignados
-- ---------------------------------------------------------------------
alter table public.events enable row level security;

drop policy if exists events_select on public.events;
create policy events_select on public.events
  for select using (
    public.is_admin()
    or coordinator_id = auth.uid()
    or public.is_event_staff(id)
  );

drop policy if exists events_insert on public.events;
create policy events_insert on public.events
  for insert with check (
    public.is_admin() or public.my_role() = 'coordinator'
  );

drop policy if exists events_update on public.events;
create policy events_update on public.events
  for update using (public.is_admin() or coordinator_id = auth.uid())
  with check (public.is_admin() or coordinator_id = auth.uid());

drop policy if exists events_delete on public.events;
create policy events_delete on public.events
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------
-- event_staff
-- ---------------------------------------------------------------------
alter table public.event_staff enable row level security;

drop policy if exists event_staff_select on public.event_staff;
create policy event_staff_select on public.event_staff
  for select using (
    public.is_admin()
    or profile_id = auth.uid()
    or public.is_event_coordinator(event_id)
  );

drop policy if exists event_staff_write on public.event_staff;
create policy event_staff_write on public.event_staff
  for all using (
    public.is_admin() or public.is_event_coordinator(event_id)
  )
  with check (
    public.is_admin() or public.is_event_coordinator(event_id)
  );

-- ---------------------------------------------------------------------
-- event_payments: solo administradores (finanzas)
-- ---------------------------------------------------------------------
alter table public.event_payments enable row level security;

drop policy if exists event_payments_admin on public.event_payments;
create policy event_payments_admin on public.event_payments
  for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- transactions: solo administradores (finanzas)
-- ---------------------------------------------------------------------
alter table public.transactions enable row level security;

drop policy if exists transactions_admin on public.transactions;
create policy transactions_admin on public.transactions
  for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- suppliers: admin CRUD; coordinador puede ver
-- ---------------------------------------------------------------------
alter table public.suppliers enable row level security;

drop policy if exists suppliers_select on public.suppliers;
create policy suppliers_select on public.suppliers
  for select using (public.is_admin() or public.my_role() = 'coordinator');

drop policy if exists suppliers_write on public.suppliers;
create policy suppliers_write on public.suppliers
  for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- inventory_items: todos ven; admin y coordinador editan stock; admin da de alta/baja
-- ---------------------------------------------------------------------
alter table public.inventory_items enable row level security;

drop policy if exists inventory_select on public.inventory_items;
create policy inventory_select on public.inventory_items
  for select using (auth.uid() is not null);

drop policy if exists inventory_insert on public.inventory_items;
create policy inventory_insert on public.inventory_items
  for insert with check (public.is_admin());

drop policy if exists inventory_update on public.inventory_items;
create policy inventory_update on public.inventory_items
  for update using (public.is_admin() or public.my_role() = 'coordinator')
  with check (public.is_admin() or public.my_role() = 'coordinator');

drop policy if exists inventory_delete on public.inventory_items;
create policy inventory_delete on public.inventory_items
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------
-- maintenance_tasks: todos ven; admin/coordinador crean; asignado puede actualizar
-- ---------------------------------------------------------------------
alter table public.maintenance_tasks enable row level security;

drop policy if exists maintenance_select on public.maintenance_tasks;
create policy maintenance_select on public.maintenance_tasks
  for select using (auth.uid() is not null);

drop policy if exists maintenance_insert on public.maintenance_tasks;
create policy maintenance_insert on public.maintenance_tasks
  for insert with check (public.is_admin() or public.my_role() = 'coordinator');

drop policy if exists maintenance_update on public.maintenance_tasks;
create policy maintenance_update on public.maintenance_tasks
  for update using (
    public.is_admin() or public.my_role() = 'coordinator' or assigned_to = auth.uid()
  )
  with check (
    public.is_admin() or public.my_role() = 'coordinator' or assigned_to = auth.uid()
  );

drop policy if exists maintenance_delete on public.maintenance_tasks;
create policy maintenance_delete on public.maintenance_tasks
  for delete using (public.is_admin());

-- #####################################################################
-- ## seed.sql
-- #####################################################################

-- =====================================================================
-- IUPI Event Manager — seed
-- Datos iniciales. Correr DESPUÉS de las migraciones.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Administradores iniciales: Facundo, Camila, Emilia, Horacio.
--
-- Los usuarios se crean primero en Authentication → Users (panel de Supabase).
-- El trigger handle_new_user crea su fila en profiles con rol 'worker'.
-- Descomentá y ajustá los emails reales para promocionarlos a admin:
-- ---------------------------------------------------------------------

-- update public.profiles p set role = 'admin', full_name = 'Facundo'
--   from auth.users u where u.id = p.id and u.email = 'facundo@iupi.com';
-- update public.profiles p set role = 'admin', full_name = 'Camila'
--   from auth.users u where u.id = p.id and u.email = 'camila@iupi.com';
-- update public.profiles p set role = 'admin', full_name = 'Emilia'
--   from auth.users u where u.id = p.id and u.email = 'emilia@iupi.com';
-- update public.profiles p set role = 'admin', full_name = 'Horacio'
--   from auth.users u where u.id = p.id and u.email = 'horacio@iupi.com';

-- ---------------------------------------------------------------------
-- Inventario inicial de ejemplo (ajustar cantidades reales).
-- ---------------------------------------------------------------------
insert into public.inventory_items (name, category, quantity, min_quantity, unit) values
  ('Platos de plástico', 'vajilla', 200, 100, 'unidades'),
  ('Vasos', 'vajilla', 200, 100, 'unidades'),
  ('Servilletas', 'limpieza', 20, 10, 'paquetes'),
  ('Lavandina', 'limpieza', 5, 3, 'litros')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- Tareas de mantenimiento periódicas típicas de un salón.
-- ---------------------------------------------------------------------
insert into public.maintenance_tasks (title, category, priority, recur_days) values
  ('Control de matafuegos', 'matafuegos', 'alta', 365),
  ('Service del aire acondicionado', 'aire', 'media', 180),
  ('Revisión del inflable', 'inflable', 'alta', 90)
on conflict do nothing;
