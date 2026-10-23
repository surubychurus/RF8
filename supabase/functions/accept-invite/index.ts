// Crea el usuario a partir de una invitación: el socio elige usuario y clave.
// Pública: se llama antes de que exista el usuario.
//
// POST { token, username, password }
import { error, handler, json } from "../_shared/http.ts";
import { adminClient } from "../_shared/supabase.ts";
import { MIN_PASSWORD, sha256, USERNAME_RE } from "../_shared/tokens.ts";

Deno.serve(handler(async (req) => {
  const { token, username, password } = await req.json();
  const cleanUsername = String(username ?? "").trim().toLowerCase();
  if (!token) return error("Falta el token");
  if (!USERNAME_RE.test(cleanUsername)) {
    return error("El usuario debe tener 3 a 20 caracteres: letras, números, punto o guion bajo");
  }
  if (typeof password !== "string" || password.length < MIN_PASSWORD) {
    return error(`La contraseña debe tener al menos ${MIN_PASSWORD} caracteres`);
  }

  const admin = adminClient();
  const tokenHash = await sha256(String(token).trim());

  // Marca la invitación como usada de forma atómica para evitar doble uso.
  const { data: invite } = await admin
    .from("invitations")
    .update({ accepted_at: new Date().toISOString() })
    .eq("token_hash", tokenHash)
    .is("accepted_at", null)
    .gt("expires_at", new Date().toISOString())
    .select("id, email, full_name, plan_id")
    .maybeSingle();
  if (!invite) return error("Invitación inválida, usada o vencida", 410);

  const release = () =>
    admin.from("invitations").update({ accepted_at: null }).eq("id", invite.id);

  const { data: taken } = await admin
    .from("profiles").select("id").eq("username", cleanUsername).maybeSingle();
  if (taken) {
    await release();
    return error("Ese usuario ya existe, probá con otro", 409);
  }

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: invite.email,
    password,
    email_confirm: true, // el email ya fue verificado al recibir el link
    user_metadata: { username: cleanUsername, full_name: invite.full_name },
  });
  if (createError || !created.user) {
    await release();
    console.error(createError);
    return error("No se pudo crear el usuario", 409);
  }

  const userId = created.user.id;
  const { error: profileError } = await admin.from("profiles").insert({
    id: userId,
    username: cleanUsername,
    full_name: invite.full_name,
    email: invite.email,
  });
  if (profileError) {
    await admin.auth.admin.deleteUser(userId);
    await release();
    throw profileError;
  }

  if (invite.plan_id) {
    const start = new Date();
    const end = new Date(start);
    end.setMonth(end.getMonth() + 1);
    end.setDate(end.getDate() - 1);
    await admin.from("memberships").insert({
      user_id: userId,
      plan_id: invite.plan_id,
      starts_on: start.toISOString().slice(0, 10),
      ends_on: end.toISOString().slice(0, 10),
    });
  }

  return json({ ok: true, username: cleanUsername });
}));
