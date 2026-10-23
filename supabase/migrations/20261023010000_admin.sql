-- RF8 — App de administración
-- Roles:
--   gym   → validar turnos y gestionar socios (crear, notificar, planes, WhatsApp)
--   owner → todo lo anterior + contenido (imágenes, logo, íconos, banner, enlaces),
--           precios, notificaciones globales, eliminar usuarios y gestionar el equipo

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------

alter type public.user_role rename value 'staff' to 'gym';
alter type public.user_role rename value 'admin' to 'owner';

alter table public.profiles add column active boolean not null default true;
alter table public.profiles add column notes text;   -- notas internas (sólo staff)

create or replace function public.is_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('gym', 'owner') and active
  )
$$;

create or replace function public.is_owner()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'owner' and active
  )
$$;

-- ---------------------------------------------------------------------------
-- Perfiles: edición por staff
-- ---------------------------------------------------------------------------


alter table public.invitations add column phone text;

-- El staff puede editar datos de contacto y notas de los socios.
create policy profiles_staff_update on public.profiles
  for update to authenticated using (public.is_staff()) with check (public.is_staff());
grant update (notes, active) on public.profiles to authenticated;

-- notes y active sólo los puede cambiar el staff (el socio también tiene permiso
-- de columna para full_name/phone, por eso se valida con un trigger).
create or replace function public.guard_profile_update()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_staff() and (new.notes is distinct from old.notes or new.active is distinct from old.active) then
    raise exception 'Sin permisos' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile_update();

-- Cambiar rol: sólo dueños.
create or replace function public.set_user_role(p_user uuid, p_role public.user_role)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'Sin permisos' using errcode = '42501';
  end if;
  if p_user = auth.uid() and p_role <> 'owner' then
    raise exception 'No podés quitarte tu propio rol de dueño' using errcode = 'P0001';
  end if;
  update public.profiles set role = p_role where id = p_user;
end;
$$;

-- ---------------------------------------------------------------------------
-- Planes y membresías
-- ---------------------------------------------------------------------------

create policy plans_owner_write on public.plans
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

create policy memberships_staff_write on public.memberships
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy invitations_staff_read on public.invitations
  for select to authenticated using (public.is_staff());
create policy invitations_staff_delete on public.invitations
  for delete to authenticated using (public.is_staff());

-- Un socio desactivado no puede reservar (book_slot usa esta función).
create or replace function public.active_days_per_week(p_user uuid, p_date date)
returns smallint
language sql stable security definer set search_path = public
as $$
  select p.days_per_week
  from public.memberships m
  join public.plans p on p.id = m.plan_id
  join public.profiles u on u.id = m.user_id
  where m.user_id = p_user and u.active and p_date between m.starts_on and m.ends_on
  order by m.ends_on desc
  limit 1
$$;

-- Validación manual (sin QR), p. ej. si el socio se quedó sin batería.
create or replace function public.check_in_booking(p_booking_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.bookings;
begin
  if not public.is_staff() then
    raise exception 'Sin permisos' using errcode = '42501';
  end if;
  select * into v_row from public.bookings where id = p_booking_id for update;
  if not found or v_row.status = 'cancelled' then
    raise exception 'Turno no encontrado' using errcode = 'P0001';
  end if;
  if v_row.status = 'attended' then
    raise exception 'La asistencia ya fue registrada' using errcode = 'P0001';
  end if;
  if v_row.date <> public.gym_today() then
    raise exception 'El turno no es de hoy' using errcode = 'P0001';
  end if;
  update public.bookings
     set status = 'attended', checked_in_at = now(), checked_in_by = auth.uid()
   where id = p_booking_id;
end;
$$;

revoke execute on function public.check_in_booking(uuid) from public, anon;
revoke execute on function public.set_user_role(uuid, public.user_role) from public, anon;
grant execute on function public.check_in_booking(uuid) to authenticated;
grant execute on function public.set_user_role(uuid, public.user_role) to authenticated;
grant execute on function public.is_owner() to authenticated;

-- ---------------------------------------------------------------------------
-- Configuración de la app (logo, íconos habilitados, etc.)
-- ---------------------------------------------------------------------------

create table public.app_settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.profiles (id) on delete set null
);
alter table public.app_settings enable row level security;

-- Se lee sin sesión (el logo aparece en la pantalla de login).
create policy settings_read on public.app_settings
  for select to anon, authenticated using (true);
create policy settings_owner_write on public.app_settings
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

insert into public.app_settings (key, value) values
  ('logo_url', 'null'),
  -- URLs de las imágenes de cada variante de ícono (null = la que viene en la app)
  ('app_icons', '{"Default": null, "Night": null, "Gold": null, "Neon": null, "Light": null, "Fire": null}'),
  -- Variantes que los socios pueden elegir
  ('enabled_icons', '["Default", "Night", "Gold", "Neon", "Light", "Fire"]');

-- ---------------------------------------------------------------------------
-- Banner superior (anuncios)
-- ---------------------------------------------------------------------------

create table public.banners (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  body        text,
  image_url   text,
  link_url    text,
  active      boolean not null default true,
  starts_at   timestamptz,
  ends_at     timestamptz,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);
alter table public.banners enable row level security;

create policy banners_read on public.banners
  for select to authenticated using (
    public.is_staff()
    or (active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now()))
  );
create policy banners_owner_write on public.banners
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

-- ---------------------------------------------------------------------------
-- Enlaces (Instagram, WhatsApp, web…)
-- ---------------------------------------------------------------------------

create table public.app_links (
  id          uuid primary key default gen_random_uuid(),
  label       text not null,
  url         text not null,
  icon        text not null default 'link',   -- instagram, whatsapp, web, mail, map, link
  active      boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);
alter table public.app_links enable row level security;

create policy links_read on public.app_links
  for select to authenticated using (active or public.is_staff());
create policy links_owner_write on public.app_links
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

insert into public.app_links (label, url, icon, sort_order) values
  ('Instagram', 'https://www.instagram.com/rf8.gimnasio', 'instagram', 0);

-- ---------------------------------------------------------------------------
-- Notificaciones (user_id null = global)
-- ---------------------------------------------------------------------------

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles (id) on delete cascade,
  title       text not null,
  body        text not null,
  link_url    text,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
alter table public.notifications enable row level security;

create policy notifications_read on public.notifications
  for select to authenticated using (user_id = auth.uid() or user_id is null or public.is_staff());
-- Personales: cualquier staff. Globales: sólo dueños.
create policy notifications_insert on public.notifications
  for insert to authenticated with check (
    created_by = auth.uid()
    and ((user_id is not null and public.is_staff()) or (user_id is null and public.is_owner()))
  );
create policy notifications_update on public.notifications
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
create policy notifications_delete on public.notifications
  for delete to authenticated using (
    public.is_owner() or (user_id is not null and created_by = auth.uid())
  );

create table public.notification_reads (
  notification_id  uuid not null references public.notifications (id) on delete cascade,
  user_id          uuid not null references public.profiles (id) on delete cascade,
  read_at          timestamptz not null default now(),
  primary key (notification_id, user_id)
);
alter table public.notification_reads enable row level security;

create policy reads_own on public.notification_reads
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Avisos en tiempo real a la app de socios.
alter publication supabase_realtime add table public.notifications;

-- ---------------------------------------------------------------------------
-- Imágenes (Storage)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 10485760, array['image/png', 'image/jpeg', 'image/webp', 'image/gif'])
on conflict (id) do nothing;

create policy media_owner_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'media' and public.is_owner());
create policy media_owner_update on storage.objects
  for update to authenticated using (bucket_id = 'media' and public.is_owner());
create policy media_owner_delete on storage.objects
  for delete to authenticated using (bucket_id = 'media' and public.is_owner());
create policy media_staff_list on storage.objects
  for select to authenticated using (bucket_id = 'media' and public.is_staff());
