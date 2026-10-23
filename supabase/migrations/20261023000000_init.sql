-- RF8 Gimnasio — esquema inicial
-- Reglas de negocio (se validan en el servidor, no sólo en la app):
--   * 15 personas por turno (time_slots.capacity)
--   * 1 turno por día por socio
--   * N turnos por semana (lunes a domingo) según el plan (1, 2, 3 o 4)
--   * Planes mensuales de 2 tipos: rutina normal y seguimiento

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

-- Zona horaria del gimnasio. Todas las reglas de "hoy" y "ya empezó" la usan.
create or replace function public.gym_now()
returns timestamp
language sql stable
as $$ select (now() at time zone 'America/Argentina/Buenos_Aires') $$;

create or replace function public.gym_today()
returns date
language sql stable
as $$ select public.gym_now()::date $$;

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------

create type public.plan_kind as enum ('normal', 'seguimiento');
create type public.user_role as enum ('member', 'staff', 'admin');
create type public.booking_status as enum ('booked', 'cancelled', 'attended');

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

create table public.plans (
  id              uuid primary key default gen_random_uuid(),
  kind            public.plan_kind not null,
  days_per_week   smallint not null check (days_per_week between 1 and 4),
  name            text not null,
  description     text,
  -- PLACEHOLDER: precios a definir por el gimnasio (null = "a definir")
  monthly_price   numeric(12, 2),
  active          boolean not null default true,
  unique (kind, days_per_week)
);

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null unique check (username ~ '^[a-z0-9._]{3,20}$'),
  full_name   text not null,
  email       text not null,
  phone       text,
  role        public.user_role not null default 'member',
  created_at  timestamptz not null default now()
);

create table public.memberships (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  plan_id     uuid not null references public.plans (id),
  starts_on   date not null,
  ends_on     date not null,
  created_at  timestamptz not null default now(),
  check (ends_on >= starts_on)
);
create index memberships_user_idx on public.memberships (user_id, ends_on desc);

create table public.invitations (
  id           uuid primary key default gen_random_uuid(),
  email        text not null,
  full_name    text not null,
  plan_id      uuid references public.plans (id),
  token_hash   text not null unique,       -- sha256 del token (el token nunca se guarda)
  expires_at   timestamptz not null,
  accepted_at  timestamptz,
  created_by   uuid references public.profiles (id),
  created_at   timestamptz not null default now()
);

create table public.time_slots (
  id          smallint primary key,
  starts_at   time not null,
  ends_at     time not null,
  capacity    smallint not null default 15,
  -- ISO: 1 = lunes … 7 = domingo
  weekdays    smallint[] not null default '{1,2,3,4,5,6}',
  active      boolean not null default true,
  check (ends_at > starts_at)
);

create table public.bookings (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  slot_id          smallint not null references public.time_slots (id),
  date             date not null,
  status           public.booking_status not null default 'booked',
  -- Secreto para el QR dinámico (TOTP). Sólo lo ve el dueño del turno.
  qr_secret        text not null default encode(gen_random_bytes(32), 'hex'),
  created_at       timestamptz not null default now(),
  cancelled_at     timestamptz,
  checked_in_at    timestamptz,
  checked_in_by    uuid references public.profiles (id)
);
-- 1 turno activo por día por socio
create unique index bookings_one_per_day
  on public.bookings (user_id, date) where status <> 'cancelled';
create index bookings_slot_date_idx on public.bookings (slot_id, date) where status <> 'cancelled';

-- ---------------------------------------------------------------------------
-- Datos iniciales
-- ---------------------------------------------------------------------------

insert into public.plans (kind, days_per_week, name, description) values
  ('normal', 1, 'Rutina normal · 1 día', 'Rutina estándar, 1 día por semana'),
  ('normal', 2, 'Rutina normal · 2 días', 'Rutina estándar, 2 días por semana'),
  ('normal', 3, 'Rutina normal · 3 días', 'Rutina estándar, 3 días por semana'),
  ('normal', 4, 'Rutina normal · 4 días', 'Rutina estándar, 4 días por semana'),
  ('seguimiento', 1, 'Seguimiento · 1 día', 'Rutina con seguimiento personalizado, 1 día por semana'),
  ('seguimiento', 2, 'Seguimiento · 2 días', 'Rutina con seguimiento personalizado, 2 días por semana'),
  ('seguimiento', 3, 'Seguimiento · 3 días', 'Rutina con seguimiento personalizado, 3 días por semana'),
  ('seguimiento', 4, 'Seguimiento · 4 días', 'Rutina con seguimiento personalizado, 4 días por semana');

-- Turnos de 1h30, 15 personas.
-- Bloques del gimnasio: 08:00–12:30, 13:30–16:30, 17:00–21:00.
-- El bloque de la tarde-noche (4 h) no es múltiplo de 1h30: se dejan 2 turnos
-- (17:00–18:30 y 18:30–20:00). Ajustar acá si el gimnasio prefiere otra grilla.
insert into public.time_slots (id, starts_at, ends_at) values
  (1, '08:00', '09:30'),
  (2, '09:30', '11:00'),
  (3, '11:00', '12:30'),
  (4, '13:30', '15:00'),
  (5, '15:00', '16:30'),
  (6, '17:00', '18:30'),
  (7, '18:30', '20:00');

-- ---------------------------------------------------------------------------
-- Helpers de rol
-- ---------------------------------------------------------------------------

create or replace function public.is_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('staff', 'admin')
  )
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.plans        enable row level security;
alter table public.profiles     enable row level security;
alter table public.memberships  enable row level security;
alter table public.invitations  enable row level security;
alter table public.time_slots   enable row level security;
alter table public.bookings     enable row level security;

create policy plans_read on public.plans
  for select to authenticated using (true);

create policy slots_read on public.time_slots
  for select to authenticated using (true);

create policy profiles_read on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_staff());

create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
-- El socio sólo puede editar estos campos (nunca role/username/email)
revoke update on public.profiles from authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

create policy memberships_read on public.memberships
  for select to authenticated using (user_id = auth.uid() or public.is_staff());

create policy bookings_read on public.bookings
  for select to authenticated using (user_id = auth.uid() or public.is_staff());
-- Inserciones/cambios de bookings sólo a través de las funciones de abajo.

-- invitations: sin políticas => sólo service_role (edge functions)

-- ---------------------------------------------------------------------------
-- RPC: disponibilidad de turnos para una fecha
-- ---------------------------------------------------------------------------

create or replace function public.get_slot_availability(p_date date)
returns table (
  slot_id    smallint,
  starts_at  time,
  ends_at    time,
  capacity   smallint,
  booked     integer
)
language sql stable security definer set search_path = public
as $$
  select s.id, s.starts_at, s.ends_at, s.capacity,
         (select count(*)::int from public.bookings b
           where b.slot_id = s.id and b.date = p_date and b.status <> 'cancelled')
  from public.time_slots s
  where s.active
    and extract(isodow from p_date)::smallint = any (s.weekdays)
  order by s.starts_at
$$;

-- ---------------------------------------------------------------------------
-- RPC: plan activo del socio para una fecha
-- ---------------------------------------------------------------------------

create or replace function public.active_days_per_week(p_user uuid, p_date date)
returns smallint
language sql stable security definer set search_path = public
as $$
  select p.days_per_week
  from public.memberships m
  join public.plans p on p.id = m.plan_id
  where m.user_id = p_user and p_date between m.starts_on and m.ends_on
  order by m.ends_on desc
  limit 1
$$;

-- ---------------------------------------------------------------------------
-- RPC: reservar turno
-- ---------------------------------------------------------------------------

create or replace function public.book_slot(p_slot_id smallint, p_date date)
returns public.bookings
language plpgsql security definer set search_path = public
as $$
declare
  v_user      uuid := auth.uid();
  v_slot      public.time_slots;
  v_quota     smallint;
  v_week_used integer;
  v_taken     integer;
  v_week_from date := date_trunc('week', p_date)::date;   -- lunes
  v_row       public.bookings;
begin
  if v_user is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;

  -- Serializa reservas del mismo turno/fecha para respetar el cupo.
  perform pg_advisory_xact_lock(hashtext(p_slot_id::text || ':' || p_date::text));

  select * into v_slot from public.time_slots where id = p_slot_id and active;
  if not found then
    raise exception 'El turno no existe' using errcode = 'P0001';
  end if;

  if p_date < public.gym_today() or p_date > public.gym_today() + 7 then
    raise exception 'Sólo podés reservar desde hoy hasta 7 días adelante' using errcode = 'P0001';
  end if;

  if not (extract(isodow from p_date)::smallint = any (v_slot.weekdays)) then
    raise exception 'Ese turno no está disponible ese día' using errcode = 'P0001';
  end if;

  if p_date + v_slot.starts_at <= public.gym_now() then
    raise exception 'Ese turno ya empezó' using errcode = 'P0001';
  end if;

  v_quota := public.active_days_per_week(v_user, p_date);
  if v_quota is null then
    raise exception 'No tenés un plan activo para esa fecha' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.bookings
             where user_id = v_user and date = p_date and status <> 'cancelled') then
    raise exception 'Ya tenés un turno reservado ese día' using errcode = 'P0001';
  end if;

  select count(*) into v_week_used from public.bookings
   where user_id = v_user and status <> 'cancelled'
     and date between v_week_from and v_week_from + 6;
  if v_week_used >= v_quota then
    raise exception 'Ya usaste tus % turnos de esta semana', v_quota using errcode = 'P0001';
  end if;

  select count(*) into v_taken from public.bookings
   where slot_id = p_slot_id and date = p_date and status <> 'cancelled';
  if v_taken >= v_slot.capacity then
    raise exception 'El turno está completo' using errcode = 'P0001';
  end if;

  insert into public.bookings (user_id, slot_id, date)
  values (v_user, p_slot_id, p_date)
  returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: cancelar turno (hasta que empiece)
-- ---------------------------------------------------------------------------

create or replace function public.cancel_booking(p_booking_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_row  public.bookings;
  v_slot public.time_slots;
begin
  select * into v_row from public.bookings
   where id = p_booking_id and user_id = auth.uid() and status = 'booked'
   for update;
  if not found then
    raise exception 'Turno no encontrado' using errcode = 'P0001';
  end if;

  select * into v_slot from public.time_slots where id = v_row.slot_id;
  if v_row.date + v_slot.starts_at <= public.gym_now() then
    raise exception 'No se puede cancelar un turno que ya empezó' using errcode = 'P0001';
  end if;

  update public.bookings
     set status = 'cancelled', cancelled_at = now()
   where id = p_booking_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: validar QR de entrada (la usa la app de administración)
--
-- Formato del QR:  RF8|1|<booking_id>|<step>|<code>
--   step = floor(epoch_segundos / 30)
--   code = primeros 16 hex de HMAC-SHA256(key = qr_secret, msg = booking_id || ':' || step)
-- Se acepta step actual ±1 (≈ 90 s) para tolerar desfasaje de relojes.
-- ---------------------------------------------------------------------------

create or replace function public.check_in(p_payload text)
returns table (
  booking_id  uuid,
  full_name   text,
  slot_start  time,
  slot_end    time,
  checked_at  timestamptz
)
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_parts    text[] := string_to_array(p_payload, '|');
  v_id       uuid;
  v_step     bigint;
  v_now_step bigint := floor(extract(epoch from now()) / 30);
  v_row      public.bookings;
  v_slot     public.time_slots;
  v_expected text;
begin
  if not public.is_staff() then
    raise exception 'Sin permisos' using errcode = '42501';
  end if;

  if array_length(v_parts, 1) <> 5 or v_parts[1] <> 'RF8' or v_parts[2] <> '1' then
    raise exception 'QR inválido' using errcode = 'P0001';
  end if;

  begin
    v_id   := v_parts[3]::uuid;
    v_step := v_parts[4]::bigint;
  exception when others then
    raise exception 'QR inválido' using errcode = 'P0001';
  end;

  if abs(v_step - v_now_step) > 1 then
    raise exception 'QR vencido, pedí que lo actualice' using errcode = 'P0001';
  end if;

  select * into v_row from public.bookings where id = v_id for update;
  if not found then
    raise exception 'Turno no encontrado' using errcode = 'P0001';
  end if;

  v_expected := left(encode(hmac(v_id::text || ':' || v_step::text, v_row.qr_secret, 'sha256'), 'hex'), 16);
  if v_expected <> lower(v_parts[5]) then
    raise exception 'QR inválido' using errcode = 'P0001';
  end if;

  if v_row.status = 'cancelled' then
    raise exception 'El turno fue cancelado' using errcode = 'P0001';
  end if;
  if v_row.status = 'attended' then
    raise exception 'La asistencia ya fue registrada' using errcode = 'P0001';
  end if;
  if v_row.date <> public.gym_today() then
    raise exception 'El turno no es de hoy' using errcode = 'P0001';
  end if;

  select * into v_slot from public.time_slots where id = v_row.slot_id;
  -- Se puede ingresar desde 30 min antes hasta que termine el turno.
  if public.gym_now() < v_row.date + v_slot.starts_at - interval '30 minutes'
     or public.gym_now() > v_row.date + v_slot.ends_at then
    raise exception 'Fuera del horario del turno' using errcode = 'P0001';
  end if;

  update public.bookings
     set status = 'attended', checked_in_at = now(), checked_in_by = auth.uid()
   where id = v_id;

  return query
    select v_id, p.full_name, v_slot.starts_at, v_slot.ends_at, now()
    from public.profiles p where p.id = v_row.user_id;
end;
$$;

-- Permisos de ejecución
revoke execute on function public.book_slot(smallint, date) from public, anon;
revoke execute on function public.cancel_booking(uuid) from public, anon;
revoke execute on function public.check_in(text) from public, anon;
revoke execute on function public.get_slot_availability(date) from public, anon;
revoke execute on function public.active_days_per_week(uuid, date) from public, anon, authenticated;
grant execute on function public.book_slot(smallint, date) to authenticated;
grant execute on function public.cancel_booking(uuid) to authenticated;
grant execute on function public.check_in(text) to authenticated;
grant execute on function public.get_slot_availability(date) to authenticated;
