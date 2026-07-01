# Roadmap — IUPI Event Manager

Etapas pensadas para tener **una primera versión funcional lo antes posible**, con base para crecer.
Cada etapa se entrega con commit propio.

## E1 — Fundación ✅
- Estructura del repo, `.gitignore`, README y docs.
- Decisiones de arquitectura (`ARCHITECTURE.md`).
- Esquema completo de base de datos (migraciones SQL) + RLS por rol + seed.
- Scaffold de la app Flutter: config, tema, router, cliente Supabase.

## E2 — Auth y roles ✅
- Login con Supabase Auth (email + contraseña).
- Carga del perfil y su rol; guard de rutas.
- Navegación principal (shell) según rol.

## E3 — Eventos y calendario ✅ (corazón de la app)
- Modelo y repositorio de eventos.
- Calendario con vistas **mensual / semanal / diaria**.
- Alta/edición de cumpleaños con todos los datos (festejado, cantidades, contacto,
  logística de bebidas/comida, precio, seña, saldo, estado, coordinador, trabajadores).
- Detalle del evento con pagos y saldo pendiente calculado.

## E4 — Gestión del negocio ✅
- Dashboard: facturación mensual, gastos, ganancia estimada, cantidad de cumpleaños,
  ocupación del salón y comparación con el mes anterior.
- Libro de ingresos y gastos (transacciones) con categorías.
- Proveedores.

## E5 — Mantenimiento e inventario ✅
- Tareas de mantenimiento (inflable, horno, matafuegos, aire, electricidad, plomería, roturas,
  limpieza, vajilla faltante) con prioridad, vencimiento y recordatorios.
- Inventario con stock actual/mínimo y alertas de faltante.

## E6 — Integración Google Calendar ⏳ (diseñado, pendiente de implementar)
- OAuth por usuario, tabla `google_tokens`.
- Edge Function que sincroniza cada evento en el calendario de las personas asignadas.
- Recordatorios automáticos (los provee Google).

## Ideas futuras (valor real, sin urgencia)
- **Notificaciones push** de recordatorios propios (saldo por cobrar, seña vencida, mantenimiento).
- **Mensaje de WhatsApp** pre-armado al cliente (confirmación / recordatorio de seña) con `wa.me`.
- **Reportes exportables** (PDF/planilla) de facturación mensual.
- **Presupuestos / reservas** antes de confirmar el evento.
- **Checklist por evento** (armado del salón, tareas del día).
