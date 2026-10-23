-- RF8 está en Montevideo, Uruguay.
--   * Zona horaria del gimnasio: America/Montevideo
--   * Lunes a viernes: 08:00–12:30, 13:30–16:30, 17:00–21:00
--   * Sábados: sólo 08:00–12:30
create or replace function public.gym_now()
returns timestamp
language sql stable
set search_path = public
as $$ select (now() at time zone 'America/Montevideo') $$;

-- Turnos de la mañana: lunes a sábado.
update public.time_slots set weekdays = '{1,2,3,4,5,6}' where starts_at < '12:30';
-- Tarde y noche: lunes a viernes.
update public.time_slots set weekdays = '{1,2,3,4,5}' where starts_at >= '12:30';
alter table public.time_slots alter column weekdays set default '{1,2,3,4,5}';
