-- ============================================================
--  progress: soportar VARIOS cursos (porcicultura, nutricion, ...)
--  Correr una sola vez en el SQL Editor de Supabase.
--  Es idempotente y no borra datos: las filas actuales quedan
--  marcadas como course='porcicultura'.
-- ============================================================

-- 1) columna de curso
alter table public.progress
  add column if not exists course text not null default 'porcicultura';

-- 2) permitir más módulos (otros cursos pueden tener < o > de 12)
alter table public.progress drop constraint if exists progress_module_check;
alter table public.progress
  add constraint progress_module_ck check (module between 1 and 60);

-- 3) unicidad por (usuario, curso, módulo) en vez de (usuario, módulo)
alter table public.progress drop constraint if exists progress_user_id_module_key;
drop index if exists progress_user_course_module;
create unique index progress_user_course_module
  on public.progress (user_id, course, module);

-- 4) índice de lectura del panel (admin trae todo)
create index if not exists progress_course_idx on public.progress (course);

-- La política RLS existente (user_id = auth.uid() OR is_admin()) sigue valiendo.

-- ============================================================
--  settings: columnas nuevas para video, anuncios y config por curso
-- ============================================================
alter table public.settings add column if not exists videos        jsonb;
alter table public.settings add column if not exists announcements  jsonb;
alter table public.settings add column if not exists nx_progress_on boolean default true;

-- ============================================================
--  error_log: monitoreo de errores del cliente (opcional pero útil)
-- ============================================================
create table if not exists public.error_log (
  id         bigint generated always as identity primary key,
  at         timestamptz default now(),
  user_id    uuid,
  role       text,
  msg        text,
  url        text,
  ua         text
);
alter table public.error_log enable row level security;
drop policy if exists error_log_insert on public.error_log;
create policy error_log_insert on public.error_log for insert with check (true);
drop policy if exists error_log_admin on public.error_log;
create policy error_log_admin on public.error_log for select using (public.is_admin());

-- ============================================================
--  STORAGE: bucket público "materiales" para PDFs/hojas/imágenes
--  (Supabase → Storage → New bucket → name: materiales → Public ✅
--   o correr esto en el SQL Editor)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('materiales','materiales', true)
on conflict (id) do update set public = true;

-- lectura pública; subir/borrar solo admins
drop policy if exists materiales_read on storage.objects;
create policy materiales_read on storage.objects
  for select using (bucket_id = 'materiales');
drop policy if exists materiales_write on storage.objects;
create policy materiales_write on storage.objects
  for insert with check (bucket_id = 'materiales' and public.is_admin());
drop policy if exists materiales_delete on storage.objects;
create policy materiales_delete on storage.objects
  for delete using (bucket_id = 'materiales' and public.is_admin());
