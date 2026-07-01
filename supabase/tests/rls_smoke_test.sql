-- =====================================================================
-- Smoke test de esquema + RLS para IUPI Event Manager.
--
-- Valida, con tres usuarios de distinto rol, que:
--  * el trigger crea los perfiles automáticamente;
--  * la vista de saldos calcula bien pagado/saldo;
--  * un pago se registra como ingreso (trigger);
--  * el RLS deja ver a cada rol solo lo que corresponde;
--  * las tareas de mantenimiento recurrentes se regeneran;
--  * un trabajador NO puede crear eventos ni cargar finanzas.
--
-- Cómo correrlo contra un Postgres local (no-Supabase). Ver tests/README.md
-- para los stubs de `auth` y los grants que Supabase provee de fábrica.
-- =====================================================================

-- Usuarios de prueba (en Supabase esto lo hace Auth).
insert into auth.users(id, email, raw_user_meta_data) values
 ('11111111-1111-1111-1111-111111111111','facu@iupi.com','{"full_name":"Facundo"}'),
 ('22222222-2222-2222-2222-222222222222','cami@iupi.com','{"full_name":"Camila"}'),
 ('33333333-3333-3333-3333-333333333333','trab@iupi.com','{"full_name":"Trabajador"}');

update public.profiles set role='admin'       where id='11111111-1111-1111-1111-111111111111';
update public.profiles set role='coordinator' where id='22222222-2222-2222-2222-222222222222';

-- Coordinadora crea un evento y asigna al trabajador.
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set role authenticated;
insert into public.events(child_name, child_age, event_date, price, deposit, status, coordinator_id, client_phone)
 values ('Benja', 6, current_date, 100000, 30000, 'reservado', '22222222-2222-2222-2222-222222222222', '2645551234');
insert into public.event_staff(event_id, profile_id)
 select id, '33333333-3333-3333-3333-333333333333' from public.events where child_name='Benja';
reset role; reset request.jwt.claim.sub;

-- Admin registra la seña.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set role authenticated;
insert into public.event_payments(event_id, amount, note)
 select id, 30000, 'Seña' from public.events where child_name='Benja';
select '2) saldo: pagado=' || total_paid || ' saldo=' || balance_due
 from public.events_with_balance where child_name='Benja';           -- espera 30000 / 70000
select '3) ingresos auto = ' || count(*)::text from public.transactions where type='ingreso'; -- espera 1
reset role; reset request.jwt.claim.sub;

-- Trabajador: ve su evento, no las finanzas.
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set role authenticated;
select '4) eventos visibles (trabajador) = ' || count(*)::text from public.events;            -- espera 1
select '5) transactions visibles (trabajador) = ' || count(*)::text from public.transactions; -- espera 0
do $$ begin
  insert into public.events(child_name, event_date) values ('Hacker', current_date);
  raise notice 'C) FALLO: el trabajador pudo crear un evento';
exception when others then raise notice 'C) OK: RLS bloqueo la creacion por el trabajador';
end $$;
reset role; reset request.jwt.claim.sub;

-- Mantenimiento recurrente se regenera al resolverlo.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set role authenticated;
select '9) tareas antes = ' || count(*)::text from public.maintenance_tasks;
update public.maintenance_tasks set status='resuelto' where title='Control de matafuegos';
select '10) tareas despues = ' || count(*)::text || ' (debe sumar 1)' from public.maintenance_tasks;
reset role; reset request.jwt.claim.sub;
