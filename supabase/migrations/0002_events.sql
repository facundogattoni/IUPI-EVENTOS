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
