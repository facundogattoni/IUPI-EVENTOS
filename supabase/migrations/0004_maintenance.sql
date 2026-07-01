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
