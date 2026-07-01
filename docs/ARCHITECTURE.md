# Arquitectura — IUPI Event Manager

Documento de decisiones. Objetivo: **base sólida y profesional, sin sobreingeniería**.

## Principios

1. **Mobile-first, pero responsive.** El uso principal es el celular; la app se adapta a pantallas
   grandes (dos columnas, más densidad) sin duplicar código.
2. **Feature-first.** Cada módulo del negocio vive en su carpeta (`features/<modulo>`) con sus
   modelos, repositorio, providers y UI. Se puede crecer módulo por módulo.
3. **La base de datos manda.** Las reglas de acceso viven en PostgreSQL (Row Level Security), no
   solo en la app. Aunque alguien tenga la anon key, no puede ver lo que no le corresponde.
4. **Dinero explícito.** Los importes se guardan en `numeric(12,2)` (pesos argentinos). Los saldos
   se calculan, no se duplican, para evitar inconsistencias.

## Capas de la app (Flutter)

```
UI (widgets/pantallas)
   │  observa
Providers (Riverpod)  ── estado + casos de uso
   │  usa
Repositorios          ── traducen entre modelos y Supabase
   │  llama
Supabase client       ── Postgres + Auth + Realtime
```

- **Modelos** inmutables (`copyWith`, `fromMap`, `toMap`). Sin dependencias de UI.
- **Repositorios** exponen métodos de dominio (`watchEvents`, `upsertEvent`, ...). Un solo lugar
  que conoce nombres de tablas/columnas.
- **Providers** de Riverpod para inyección y estado. Streams para datos en vivo (Realtime).
- **Router** (`go_router`) con un `ShellRoute` que dibuja la navegación inferior y un guard de auth.

## Modelo de datos (resumen)

- `profiles` — un registro por usuario de `auth.users`. Guarda `role` (admin / coordinator /
  worker), nombre, teléfono y si está activo.
- `events` — cada cumpleaños. Datos del festejado, fecha/horario, cantidades, contacto, logística
  (bebidas, comida), precio, seña, estado y coordinador asignado.
- `event_staff` — trabajadores asignados a un evento (N a N).
- `event_payments` — pagos registrados de un evento (seña, saldos parciales). El saldo pendiente
  se calcula: `price - sum(payments)`.
- `suppliers` — proveedores.
- `transactions` — libro de ingresos y gastos (categoría, monto, fecha, evento/proveedor opcional).
  Alimenta el dashboard.
- `inventory_items` — insumos/vajilla con stock actual y mínimo (alertas de faltante).
- `maintenance_tasks` — tareas de mantenimiento con categoría, prioridad, vencimiento, costo y
  recurrencia (recordatorios).

Enums de dominio: `user_role`, `event_status`, `transaction_type`, `maintenance_status`,
`maintenance_priority`. Definidos en la primera migración.

## Seguridad y roles (RLS)

| Recurso | Admin | Coordinador | Trabajador |
|---------|:-----:|:-----------:|:----------:|
| Eventos | Todos (CRUD) | Ve/edita los que coordina | Ve los que tiene asignados |
| Pagos / Finanzas | Sí | No | No |
| Inventario / Mantenimiento | CRUD | Ve, marca hecho | Ve |
| Proveedores | CRUD | Ve | — |
| Perfiles | CRUD | Ve el propio | Ve el propio |

Implementado con funciones `is_admin()` / `current_role()` y políticas por tabla en
`supabase/migrations/0005_rls.sql`. "El que necesita ver poco, ve poco".

## Integración con Google Calendar (diseño)

Objetivo: cada coordinador/trabajador ve sus cumpleaños en su Google Calendar y recibe
recordatorios, sin construir un servidor propio.

Enfoque elegido (más simple y $0): **Edge Function de Supabase** que, ante cambios en `events`
(insert/update/delete) o `event_staff`, sincroniza un evento en el calendario de cada persona
asignada vía Google Calendar API, usando OAuth por usuario (tokens guardados en `google_tokens`).
Los recordatorios los maneja Google. Alternativa evaluada y descartada por ahora: generar feeds
`.ics` por usuario (más simple aún, pero sin recordatorios push ni edición bidireccional).

Detalle e implementación quedan para la etapa E6 (ver `docs/ROADMAP.md`).
