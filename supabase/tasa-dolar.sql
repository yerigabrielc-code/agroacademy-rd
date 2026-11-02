-- ============================================================
-- AGROACADEMY · LA TASA DEL DÓLAR PARA MOSTRAR LOS PRECIOS EN RD$
-- ------------------------------------------------------------
-- Una sola cosa: una columna nueva en settings (la fila id = 1)
-- con la tasa que escribe el instructor en el panel:
--   Solicitudes de acceso → Precios de los cursos → 💱 Tasa del dólar
--
-- Los precios se siguen guardando en dólares (course_catalog). La
-- página los muestra en pesos: US$ × tasa, redondeado a la centena.
--
-- ES SEGURO EJECUTARLO MÁS DE UNA VEZ («if not exists»).
-- NO TOCA ESTUDIANTES, ACCESOS, AVANCE NI PRECIOS.
-- ============================================================

alter table public.settings add column if not exists tasa_usd numeric default 60;

-- Comprobación: debe devolver una fila con tasa_usd = 60 (o la que ya guardó).
select id, tasa_usd from public.settings where id = 1;

-- Cómo deshacer (solo si hiciera falta; la página vuelve a usar 60):
--   alter table public.settings drop column if exists tasa_usd;
