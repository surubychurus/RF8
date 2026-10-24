// Genera un código de invitación para que el socio cree su usuario en la app.
// Lo usa la app de administración (staff: gym o dueño). No envía mails: el
// código se copia o se comparte por WhatsApp desde la app.
//
// POST { full_name, phone?, email?, plan_id? }   → invitación nueva
// POST { invitation_id }                          → nuevo código para una pendiente
// ← { code, invitation_id, expires_at }
import { error, handler, json } from "../_shared/http.ts";
import { adminClient, userClient } from "../_shared/supabase.ts";
import { EMAIL_RE, inviteCode, sha256 } from "../_shared/tokens.ts";

const INVITE_TTL_DAYS = Number(Deno.env.get("INVITE_TTL_DAYS") ?? "7");

Deno.serve(handler(async (req) => {
  const caller = userClient(req);
  const { data: auth } = await caller.auth.getUser();
  if (!auth.user) return error("No autenticado", 401);

  const { data: isStaff } = await caller.rpc("is_staff");
  if (!isStaff) return error("Sin permisos", 403);

  const body = await req.json();
  const admin = adminClient();
  const code = inviteCode();
  const expiresAt = new Date(Date.now() + INVITE_TTL_DAYS * 86400_000).toISOString();

  // Nuevo código para una invitación pendiente (el anterior deja de servir).
  if (body.invitation_id) {
    const { data, error: updateError } = await admin
      .from("invitations")
      .update({ token_hash: await sha256(code), expires_at: expiresAt })
      .eq("id", body.invitation_id)
      .is("accepted_at", null)
      .select("id")
      .maybeSingle();
    if (updateError) throw updateError;
    if (!data) return error("La invitación no existe o ya fue usada", 404);
    return json({ code, invitation_id: data.id, expires_at: expiresAt });
  }

  const fullName = String(body.full_name ?? "").trim();
  if (fullName.length < 3) return error("Nombre inválido");

  const email = String(body.email ?? "").trim().toLowerCase() || null;
  if (email) {
    if (!EMAIL_RE.test(email)) return error("Email inválido");
    const { data: existing } = await admin.from("profiles").select("id").eq("email", email).maybeSingle();
    if (existing) return error("Ya existe un socio con ese email", 409);
  }

  const { data: invite, error: insertError } = await admin.from("invitations").insert({
    email,
    full_name: fullName,
    phone: body.phone ? String(body.phone).trim() : null,
    plan_id: body.plan_id ?? null,
    token_hash: await sha256(code),
    expires_at: expiresAt,
    created_by: auth.user.id,
  }).select("id").single();
  if (insertError) throw insertError;

  return json({ code, invitation_id: invite.id, expires_at: expiresAt });
}));
