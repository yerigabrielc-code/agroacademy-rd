-- ============================================================
-- QUE LA TABLA progress SEPA DE QUÉ CURSO ES CADA FILA
-- ------------------------------------------------------------
-- POR QUÉ HACE FALTA
--
-- La academia tiene seis cursos y la tabla `progress` guarda una
-- fila por (estudiante, módulo). Falta el dato de QUÉ CURSO, así
-- que el módulo 3 de Reproducción y el módulo 3 de Sanidad son la
-- misma fila: uno pisa al otro.
--
-- Por eso el código, cuando no encuentra la columna, descarta todo
-- lo que no sea Porcicultura (shell.js, pushExamProgress):
--
--     /* si no hay columna course y el curso es nutrición, no hay
--        dónde guardarlo hasta correr la migración */
--
-- Esta es esa migración.
--
-- QUÉ HACE, EN ORDEN
--   1. Añade la columna `course`, con 'porcicultura' por defecto.
--   2. Marca como 'porcicultura' lo que ya hay — que es lo que es:
--      hasta hoy solo ese curso llegaba a guardarse.
--   3. Cambia la clave única de (user_id, module) a
--      (user_id, course, module). Sin esto, dos cursos no pueden
--      tener a la vez su módulo 3 para la misma persona.
--   4. Un índice para las consultas del panel.
--   5. Comprueba y enseña el resultado.
--
-- QUÉ NO HACE
--   No borra ni una fila. No cambia ni una nota. Lo que ya está
--   guardado sigue exactamente igual, solo que ahora dice de qué
--   curso es.
--
-- SE PUEDE EJECUTAR DOS VECES SIN HACER DAÑO.
-- ============================================================


-- ------------------------------------------------------------
-- 1 · LA COLUMNA
-- ------------------------------------------------------------
alter table public.progress
  add column if not exists course text not null default 'porcicultura';


-- ------------------------------------------------------------
-- 2 · LO QUE YA HABÍA ES DE PORCICULTURA
-- ------------------------------------------------------------
-- El default solo cubre las filas nuevas. Esto cubre las viejas
-- por si alguna quedó en nulo en algún momento.
update public.progress
   set course = 'porcicultura'
 where course is null or course = '';


-- ------------------------------------------------------------
-- 3 · LA CLAVE ÚNICA, AHORA CON EL CURSO DENTRO
-- ------------------------------------------------------------
-- Este es el paso que de verdad arregla el problema. Se busca
-- cualquier restricción o índice único que esté sobre
-- (user_id, module) y se retira, para poner el de tres columnas.
do $$
declare
  r record;
begin
  -- restricciones únicas sobre exactamente (user_id, module)
  for r in
    select con.conname
      from pg_constraint con
      join pg_class rel on rel.oid = con.conrelid
      join pg_namespace ns on ns.oid = rel.relnamespace
     where ns.nspname = 'public'
       and rel.relname = 'progress'
       and con.contype in ('u','p')
       and (
         select array_agg(att.attname::text order by att.attname)
           from unnest(con.conkey) as k(attnum)
           join pg_attribute att
             on att.attrelid = con.conrelid and att.attnum = k.attnum
       ) = array['module','user_id']
  loop
    execute format('alter table public.progress drop constraint %I', r.conname);
    raise notice 'retirada la restriccion %', r.conname;
  end loop;

  -- índices únicos sueltos sobre lo mismo
  for r in
    select i.indexrelid::regclass::text as nombre
      from pg_index i
      join pg_class rel on rel.oid = i.indrelid
      join pg_namespace ns on ns.oid = rel.relnamespace
     where ns.nspname = 'public'
       and rel.relname = 'progress'
       and i.indisunique
       and not i.indisprimary
       and (
         select array_agg(att.attname::text order by att.attname)
           from unnest(i.indkey) as k(attnum)
           join pg_attribute att
             on att.attrelid = i.indrelid and att.attnum = k.attnum
       ) = array['module','user_id']
  loop
    execute format('drop index if exists %s', r.nombre);
    raise notice 'retirado el indice %', r.nombre;
  end loop;
end $$;

-- la clave que corresponde a una academia de seis cursos
create unique index if not exists progress_user_course_module_uk
  on public.progress (user_id, course, module);


-- ------------------------------------------------------------
-- 4 · ÍNDICE PARA EL PANEL
-- ------------------------------------------------------------
-- El instructor consulta «todo el avance de este curso»; sin esto
-- recorre la tabla entera cada vez que abre Progreso.
create index if not exists progress_course_idx
  on public.progress (course);


-- ------------------------------------------------------------
-- 5 · COMPROBACIÓN
-- ------------------------------------------------------------
-- Lo primero debe decir que la columna existe. Lo segundo, cuántas
-- filas hay por curso: hasta que los estudiantes vuelvan a entrar,
-- lo normal es ver solo porcicultura (y quizá nutricion).
select
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'progress'
      and column_name = 'course')                       as columna_course_existe,
  (select count(*) from pg_indexes
    where schemaname = 'public'
      and indexname = 'progress_user_course_module_uk') as clave_de_tres_existe;

select course,
       count(*)                                  as filas,
       count(distinct user_id)                   as estudiantes,
       count(*) filter (where passed)            as aprobados
  from public.progress
 group by course
 order by filas desc;
