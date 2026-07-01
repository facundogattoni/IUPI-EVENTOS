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
