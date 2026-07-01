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
