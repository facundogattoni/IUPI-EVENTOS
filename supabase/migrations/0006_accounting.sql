-- =====================================================================
-- IUPI Event Manager — 0006 contabilidad (USD, inversiones, config)
-- Base para: valor en dólares congelado, bienes de capital con amortización,
-- horas de trabajo por evento y configuración de rentabilidad.
-- =====================================================================

-- ---------------------------------------------------------------------
-- exchange_rates: cotización del dólar cargada manualmente (diaria/semanal)
-- ---------------------------------------------------------------------
create table if not exists public.exchange_rates (
  id          uuid primary key default gen_random_uuid(),
  rate_date   date not null unique,
  usd_ars     numeric(12,2) not null check (usd_ars > 0),   -- pesos por 1 USD
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

comment on table public.exchange_rates is
  'Cotización del dólar por fecha. Se usa para congelar el valor en USD de gastos e inversiones.';

create index if not exists exchange_rates_date_idx
  on public.exchange_rates(rate_date desc);

-- ---------------------------------------------------------------------
-- capital_assets: inversiones / bienes de capital (inflable, horno, aire...)
-- El valor en USD se congela al momento de la compra (cost_ars / usd_rate).
-- ---------------------------------------------------------------------
create table if not exists public.capital_assets (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  category           text,            -- inflable, horno, aire, juegos, mobiliario, ...
  purchase_date      date not null default current_date,
  cost_ars           numeric(14,2) not null check (cost_ars >= 0),
  usd_rate           numeric(12,2),   -- dólar al momento de la compra
  useful_life_months integer not null default 60 check (useful_life_months > 0),
  notes              text,
  is_active          boolean not null default true,
  created_by         uuid references public.profiles(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.capital_assets is
  'Inversiones que duran varios años; se amortizan en su vida útil.';

drop trigger if exists capital_assets_set_updated_at on public.capital_assets;
create trigger capital_assets_set_updated_at
  before update on public.capital_assets
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------------------
-- transactions: guardar el dólar del momento (congela el valor en USD)
-- ---------------------------------------------------------------------
alter table public.transactions
  add column if not exists usd_rate numeric(12,2);

-- ---------------------------------------------------------------------
-- events: horas de trabajo que demandó el cumpleaños (para $/hora)
-- ---------------------------------------------------------------------
alter table public.events
  add column if not exists labor_hours numeric(6,2);

-- ---------------------------------------------------------------------
-- business_settings: configuración de rentabilidad (una sola fila)
-- ---------------------------------------------------------------------
create table if not exists public.business_settings (
  id                      boolean primary key default true check (id),
  figurative_rent_usd     numeric(12,2) not null default 0,   -- alquiler figurativo (costo de oportunidad)
  fixed_costs_monthly     numeric(14,2) not null default 0,   -- costos fijos mensuales estimados
  variable_cost_per_event numeric(14,2) not null default 0,   -- costo variable por cumpleaños
  profit_goal_monthly     numeric(14,2) not null default 0,   -- meta de ganancia mensual
  updated_at              timestamptz not null default now()
);

insert into public.business_settings (id) values (true)
  on conflict (id) do nothing;

drop trigger if exists business_settings_set_updated_at on public.business_settings;
create trigger business_settings_set_updated_at
  before update on public.business_settings
  for each row execute procedure public.set_updated_at();

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.exchange_rates enable row level security;
drop policy if exists exchange_rates_select on public.exchange_rates;
create policy exchange_rates_select on public.exchange_rates
  for select using (auth.uid() is not null);
drop policy if exists exchange_rates_write on public.exchange_rates;
create policy exchange_rates_write on public.exchange_rates
  for all using (public.is_admin()) with check (public.is_admin());

alter table public.capital_assets enable row level security;
drop policy if exists capital_assets_admin on public.capital_assets;
create policy capital_assets_admin on public.capital_assets
  for all using (public.is_admin()) with check (public.is_admin());

alter table public.business_settings enable row level security;
drop policy if exists business_settings_admin on public.business_settings;
create policy business_settings_admin on public.business_settings
  for all using (public.is_admin()) with check (public.is_admin());
