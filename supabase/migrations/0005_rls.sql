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
