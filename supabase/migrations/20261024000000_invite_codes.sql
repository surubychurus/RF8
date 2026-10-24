-- Invitaciones por código generado en la app de administración (sin mail).
-- El email pasa a ser opcional: si no se carga, lo completa el socio al crear su usuario.
alter table public.invitations alter column email drop not null;
