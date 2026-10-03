-- ============================================================
-- AGROACADEMY · EL PERMISO DE CADA CURSO, EN LA NUBE
-- ------------------------------------------------------------
-- CORRECCIÓN respecto a la versión anterior de este archivo:
--
-- La versión anterior daba por hecho que ya existían las columnas
-- acceso_nutricion, acceso_reproduccion y acceso_sanidad, porque
-- el código de la plataforma las escribe. Al ejecutarlo dio:
--
--     ERROR: column "acceso_reproduccion" does not exist
--
-- Y tenía razón la base de datos: el código las escribe, pero
-- nunca se crearon. Es decir, el permiso de esos cursos TAMPOCO
-- estaba viajando al alumno — se quedaba en el navegador del
-- instructor, igual que el del curso base.
--
-- Este archivo crea LAS CINCO, exista la que exista. Crear una
-- que ya está no hace nada: «add column if not exists» es seguro.
-- ============================================================
--
-- QUÉ RESUELVE
-- ------------------------------------------------------------
-- El permiso de cada curso tiene que viajar desde su navegador
-- hasta el del alumno. Hoy no viaja: vive en el localStorage del
-- instructor, y ese no llega a ningún sitio.
--
-- Consecuencias reales que se midieron:
--   · Usted marca «habilitado» y el alumno no se entera.
--   · El curso base se apoyaba en lo único que sí viaja —el
--     estado de la cuenta— y por eso CUALQUIER alumno activo
--     veía DOS cursos habilitados: el gratuito y el de US$ 75.
--
-- ------------------------------------------------------------
-- LEA ESTO ANTES DE EJECUTAR
-- ------------------------------------------------------------
-- Ejecute el archivo COMPLETO, de una vez. Los bloques 1 y 2 van
-- juntos: el 1 crea las columnas vacías y el 2 conserva a quien
-- hoy tiene el curso base.
--
-- NO HACE FALTA que usted rellene a mano quién tiene nutrición,
-- reproducción, sanidad o engorde. La primera vez que entre al
-- panel después de ejecutar esto, la plataforma sube sola a la
-- nube los permisos que usted ya tiene concedidos en su
-- navegador. Se hace una sola vez y queda avisado en pantalla.
--
-- No se borra ningún dato. No se toca el avance de nadie: vive en
-- la tabla `progress` y este archivo ni la menciona. Quitar un
-- acceso nunca borra lo aprendido.
-- ============================================================


-- ------------------------------------------------------------
-- BLOQUE 1 · LAS COLUMNAS
-- ------------------------------------------------------------
-- Cinco de permiso (una por curso de pago) y una de visibilidad.
-- Las reglas de cada curso van aparte, en settings.
--
--   acceso_<curso> → ¿puede ENTRAR a este curso?
--   vista          → ¿existe esta PIEZA en su pantalla?
-- ------------------------------------------------------------
alter table public.profiles add column if not exists acceso_porcicultura boolean not null default false;
alter table public.profiles add column if not exists acceso_nutricion    boolean not null default false;
alter table public.profiles add column if not exists acceso_reproduccion boolean not null default false;
alter table public.profiles add column if not exists acceso_sanidad      boolean not null default false;
alter table public.profiles add column if not exists acceso_engorde      boolean not null default false;

-- El objeto vacío significa «lo ve todo». Solo un false explícito
-- oculta una pieza, así que un estudiante nuevo nunca nace a
-- ciegas y la pantalla de control arranca sin nada apagado.
alter table public.profiles add column if not exists vista jsonb not null default '{}'::jsonb;

-- Las reglas de cada curso: candado, nota mínima, intentos y si
-- entrega certificado. Van en settings porque son del curso, no
-- del alumno.
alter table public.settings add column if not exists reglas jsonb not null default '{}'::jsonb;


-- ------------------------------------------------------------
-- BLOQUE 2 · CONSERVAR EL CURSO BASE A QUIEN YA LO TIENE
-- ------------------------------------------------------------
-- Hasta hoy, el curso base se concedía solo por tener la cuenta
-- activa. Esto conserva exactamente a esa gente, ni uno más.
--
-- ES LO SEGURO, y es lo que debe ejecutar si no está seguro.
--
-- Los otros cuatro cursos NO se tocan aquí: sus permisos los sube
-- la propia plataforma desde su navegador la primera vez que
-- entre al panel.
-- ------------------------------------------------------------
update public.profiles
   set acceso_porcicultura = true
 where coalesce(status, 'activo') in ('activo', 'completado');


-- ------------------------------------------------------------
-- BLOQUE 2-BIS · LA ALTERNATIVA: EMPEZAR DE CERO
-- ------------------------------------------------------------
-- SOLO si prefiere que NADIE tenga el curso base hasta dárselo a
-- mano. Deja a sus alumnos con el curso gratuito y nada más.
--
-- Es reversible: el avance no se pierde y devolver el acceso les
-- deja donde estaban.
--
-- Si ejecuta esto, NO ejecute el bloque 2.
-- ------------------------------------------------------------
-- update public.profiles set acceso_porcicultura = false;


-- ------------------------------------------------------------
-- BLOQUE 3 · COMPROBACIÓN
-- ------------------------------------------------------------
-- Después de ejecutar, esto le dice cuántos alumnos tienen cada
-- curso. Las columnas ya existen todas, así que no puede fallar.
--
-- Es normal que los cuatro de la derecha salgan en 0 la primera
-- vez: se llenan solos cuando usted entre al panel.
-- ------------------------------------------------------------
select
  count(*)                                        as alumnos,
  count(*) filter (where acceso_porcicultura)     as curso_base,
  count(*) filter (where acceso_nutricion)        as nutricion,
  count(*) filter (where acceso_reproduccion)     as reproduccion,
  count(*) filter (where acceso_sanidad)          as sanidad,
  count(*) filter (where acceso_engorde)          as engorde
from public.profiles
where coalesce(status, 'activo') <> 'borrado';


-- ============================================================
-- CÓMO DESHACER
-- ------------------------------------------------------------
-- Quitar las columnas devuelve el comportamiento de antes: la
-- plataforma vuelve a conceder el curso base por cuenta activa y
-- los permisos vuelven a quedarse en cada navegador.
--
--   alter table public.profiles drop column if exists acceso_porcicultura;
--   alter table public.profiles drop column if exists acceso_engorde;
--   alter table public.profiles drop column if exists vista;
--   alter table public.settings drop column if exists reglas;
--
-- No borre acceso_nutricion, acceso_reproduccion ni acceso_sanidad
-- si ya las estaba usando: son las que el código lleva escribiendo
-- desde antes.
--
-- El avance de los alumnos no se ve afectado en ningún caso.
-- ============================================================
