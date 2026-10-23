// Devuelve los datos de una invitación válida (para mostrar en la app).
// Pública: se llama antes de que exista el usuario.
//
// POST { token }
import { error, handler, json } from "../_shared/http.ts";
import { adminClient } from "../_shared/supabase.ts";
import { sha256 } from "../_shared/tokens.ts";

Deno.serve(handler(async (req) => {
  const { token } = await req.json();
  if (!token) return error("Falta el token");

  const { data: invite } = await adminClient()
    .from("invitations")
    .select("email, full_name, expires_at, accepted_at")
    .eq("token_hash", await sha256(String(token).trim()))
    .maybeSingle();

  if (!invite) return error("Invitación inválida", 404);
  if (invite.accepted_at) return error("Esta invitación ya fue usada", 410);
  if (new Date(invite.expires_at) < new Date()) return error("La invitación venció", 410);

  return json({
    email: invite.email,
    full_name: invite.full_name,
    expires_at: invite.expires_at,
  });
}));
