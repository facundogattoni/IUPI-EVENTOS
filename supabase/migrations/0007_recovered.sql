-- =====================================================================
-- IUPI Event Manager — 0007 "ya recuperado (estimado)"
-- Monto que ya se recuperó de la inversión (ej: por la actividad del año
-- pasado sin registrar). Se usa en el ROI / payback.
-- =====================================================================

alter table public.business_settings
  add column if not exists already_recovered_ars numeric(14,2) not null default 0;

-- El "dólar de la compra" ya existe: capital_assets.usd_rate (migración 0006).
-- Solo se expone como campo editable en la app, sin cambios de base.
