-- ============================================================
--  AgroAcademy RD · migración "progress-course"
--  Correr UNA vez en:  Supabase → SQL Editor → New query → pegar → Run
--  Es idempotente (se puede correr de nuevo sin daño) y NO borra datos.
--  Las filas de progreso actuales quedan marcadas como course = 'porcicultura'.
-- ============================================================

begin;

-- 1) progress: columna de curso -------------------------------------------------
alter table public.progress
  add column if not exists course text not null default 'porcicultura';

-- 2) permitir más módulos (otros cursos pueden tener < o > de 12) ---------------
alter table public.progress drop constraint if exists progress_module_check;
alter table public.progress drop constraint if exists progress_module_ck;
alter table public.progress
  add constraint progress_module_ck check (module between 1 and 60);

-- 3) unicidad por (usuario, curso, módulo) en vez de (usuario, módulo) ----------
alter table public.progress drop constraint if exists progress_user_id_module_key;
drop index if exists public.progress_user_id_module_key;
drop index if exists public.progress_user_course_module;
create unique index progress_user_course_module
  on public.progress (user_id, course, module);

create index if not exists progress_course_idx on public.progress (course);

-- 4) settings: columnas nuevas ------------------------------------------------------
alter table public.settings add column if not exists videos        jsonb;
alter table public.settings add column if not exists announcements  jsonb;
alter table public.settings add column if not exists nx_progress_on boolean default true;

-- 5) error_log: monitoreo de errores del cliente ---------------------------------
create table if not exists public.error_log (
  id      bigint generated always as identity primary key,
  at      timestamptz default now(),
  user_id uuid,
  role    text,
  msg     text,
  url     text,
  ua      text
);
alter table public.error_log enable row level security;
drop policy if exists error_log_insert on public.error_log;
create policy error_log_insert on public.error_log for insert with check (true);
drop policy if exists error_log_admin on public.error_log;
create policy error_log_admin on public.error_log for select using (public.is_admin());

commit;

-- 6) STORAGE: bucket público "materiales" --------------------------------------
--  (esto NO va dentro de la transacción de arriba)
insert into storage.buckets (id, name, public)
values ('materiales', 'materiales', true)
on conflict (id) do update set public = true;

drop policy if exists materiales_read   on storage.objects;
drop policy if exists materiales_write  on storage.objects;
drop policy if exists materiales_delete on storage.objects;
create policy materiales_read on storage.objects
  for select using (bucket_id = 'materiales');
create policy materiales_write on storage.objects
  for insert with check (bucket_id = 'materiales' and public.is_admin());
create policy materiales_delete on storage.objects
  for delete using (bucket_id = 'materiales' and public.is_admin());

-- ============================================================
--  Verificación (debe devolver una fila con todo en 'ok')
-- ============================================================
select
  (select count(*) from information_schema.columns
     where table_schema='public' and table_name='progress' and column_name='course') = 1        as progress_course_ok,
  (select count(*) from pg_indexes
     where schemaname='public' and indexname='progress_user_course_module') = 1                  as unique_ok,
  (select count(*) from information_schema.columns
     where table_schema='public' and table_name='settings' and column_name in ('videos','announcements')) = 2 as settings_ok,
  to_regclass('public.error_log') is not null                                                    as error_log_ok,
  (select count(*) from storage.buckets where id='materiales') = 1                               as bucket_ok;
