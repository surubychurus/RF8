-- Ajustes sugeridos por el linter de seguridad de Supabase.
alter function public.gym_now() set search_path = public;
alter function public.gym_today() set search_path = public;

-- Función de trigger: no debe poder llamarse por la API.
revoke execute on function public.guard_profile_update() from public, anon, authenticated;

-- Helpers de rol: sólo con sesión (se usan en las políticas RLS).
revoke execute on function public.is_staff() from public, anon;
revoke execute on function public.is_owner() from public, anon;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_owner() to authenticated;

-- Permite guardar "sin valor" (p. ej. volver al logo por defecto).
alter table public.app_settings alter column value drop not null;
