# IUPI — Event Manager

Aplicación de gestión interna para **IUPI**, salón de eventos infantiles (San Juan, Argentina).

Reemplaza WhatsApp, cuadernos y planillas de Excel con una herramienta profesional, simple y
rápida, pensada para usarse todos los días desde el celular (y también desde la computadora).

La app tiene **dos pilares**:

1. **Organización del salón** — el corazón de la app. Cada cumpleaños se administra de punta a
   punta: datos del evento, coordinador y trabajadores asignados, pagos (seña / saldo), estado,
   y un calendario cómodo con vistas **mensual, semanal y diaria**.
2. **Gestión del negocio** — dashboard con facturación, gastos, ganancia estimada, ocupación del
   salón y comparación con meses anteriores; más ingresos, gastos, compras, inventario,
   mantenimiento y proveedores.

---

## Stack

| Capa | Tecnología | Por qué |
|------|-----------|---------|
| App | **Flutter** | Un solo código para Android, iOS, web y escritorio |
| Estado | **Riverpod** | Simple, testeable, sin boilerplate de otros enfoques |
| Navegación | **go_router** | Rutas declarativas, deep-links, shell con navegación inferior |
| Backend | **Supabase** (PostgreSQL + Auth + Realtime) | Plan gratuito, SQL real, RLS por rol |
| Calendario | **table_calendar** | Vistas mes/semana/día muy cómodas |
| Gráficos | **fl_chart** | Dashboard liviano y nativo |

> **Costo objetivo: ~$0.** Supabase Free (500 MB de base, 50k usuarios activos/mes) y build de
> Flutter distribuido por APK / TestFlight / web estática alcanzan de sobra para el uso interno.

Ver decisiones de arquitectura en [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Estructura del repo

```
.
├── app/                    # Aplicación Flutter
│   ├── lib/
│   │   ├── core/           # Config, tema, router, utilidades, cliente Supabase
│   │   ├── features/       # Módulos: auth, events, dashboard, finance, maintenance, ...
│   │   └── main.dart
│   └── pubspec.yaml
├── supabase/
│   ├── migrations/         # Esquema de la base (SQL, versionado)
│   └── seed.sql            # Datos iniciales (roles, admins, categorías)
└── docs/                   # Arquitectura, setup, roadmap
```

---

## Puesta en marcha (resumen)

1. **Crear proyecto en Supabase** (plan Free) y correr las migraciones de `supabase/migrations/`.
   Detalle paso a paso en [`docs/SETUP.md`](docs/SETUP.md).
2. **Configurar la app Flutter** con la URL y la anon key del proyecto:

   ```bash
   cd app
   flutter pub get
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJ...
   ```

3. Crear los usuarios administradores (Facundo, Camila, Emilia, Horacio) — ver `docs/SETUP.md`.

---

## Estado / Roadmap

Ver [`docs/ROADMAP.md`](docs/ROADMAP.md). Resumen de etapas:

- [x] **E1 — Fundación:** repo, arquitectura, esquema de base + RLS, scaffold Flutter.
- [x] **E2 — Auth y roles:** login, perfiles, control de acceso por rol.
- [x] **E3 — Eventos y calendario:** CRUD de cumpleaños, calendario mes/semana/día, pagos y estado.
- [x] **E4 — Gestión del negocio:** dashboard, ingresos/gastos, proveedores.
- [x] **E5 — Mantenimiento e inventario:** tareas con recordatorios, stock.
- [ ] **E6 — Integración Google Calendar** (diseño incluido, implementación pendiente).
