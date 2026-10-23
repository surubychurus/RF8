// Envía la invitación por correo (Resend) para que el socio cree su usuario.
// La llama la app de administración con el JWT de un usuario staff/admin.
//
// POST { email, full_name, phone?, plan_id? }
import { error, handler, json } from "../_shared/http.ts";
import { adminClient, userClient } from "../_shared/supabase.ts";
import { randomToken, sha256 } from "../_shared/tokens.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
// Debe ser un remitente del dominio verificado de RF8 en Resend.
const RESEND_FROM = Deno.env.get("RESEND_FROM") ?? "RF8 Gimnasio <no-reply@rf8.com.ar>";
// Link que abre la app (App Links / Universal Links). Ver README.
const INVITE_URL_BASE = Deno.env.get("INVITE_URL_BASE") ?? "https://app.rf8.com.ar/invite";
const INVITE_TTL_HOURS = Number(Deno.env.get("INVITE_TTL_HOURS") ?? "72");

Deno.serve(handler(async (req) => {
  const caller = userClient(req);
  const { data: auth } = await caller.auth.getUser();
  if (!auth.user) return error("No autenticado", 401);

  const { data: isStaff } = await caller.rpc("is_staff");
  if (!isStaff) return error("Sin permisos", 403);

  const { email, full_name, phone, plan_id } = await req.json();
  const cleanEmail = String(email ?? "").trim().toLowerCase();
  const cleanName = String(full_name ?? "").trim();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(cleanEmail)) return error("Email inválido");
  if (cleanName.length < 3) return error("Nombre inválido");

  const admin = adminClient();
  const { data: existing } = await admin
    .from("profiles").select("id").eq("email", cleanEmail).maybeSingle();
  if (existing) return error("Ya existe un socio con ese email", 409);

  const token = randomToken();
  const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3600_000);
  const { data: invite, error: insertError } = await admin.from("invitations").insert({
    email: cleanEmail,
    full_name: cleanName,
    phone: phone ? String(phone).trim() : null,
    plan_id: plan_id ?? null,
    token_hash: await sha256(token),
    expires_at: expiresAt.toISOString(),
    created_by: auth.user.id,
  }).select("id").single();
  if (insertError) throw insertError;

  const link = `${INVITE_URL_BASE}?token=${encodeURIComponent(token)}`;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM,
      to: [cleanEmail],
      subject: "Bienvenido a RF8 — creá tu usuario",
      html: inviteHtml(cleanName, link, token, INVITE_TTL_HOURS),
      text:
        `Hola ${cleanName}!\n\nCreá tu usuario de RF8 desde este link:\n${link}\n\n` +
        `Si el link no abre la app, ingresá este código en "Tengo una invitación":\n${token}\n\n` +
        `El link vence en ${INVITE_TTL_HOURS} horas.`,
    }),
  });
  if (!res.ok) {
    console.error("Resend error", res.status, await res.text());
    await admin.from("invitations").delete().eq("id", invite.id);
    return error("No se pudo enviar el correo", 502);
  }

  return json({ ok: true, expires_at: expiresAt.toISOString() });
}));

function escape(s: string): string {
  return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

function inviteHtml(name: string, link: string, token: string, ttl: number): string {
  // PLACEHOLDER de marca: reemplazar el bloque "RF8" por el logo (URL pública).
  return `<!doctype html>
<html><body style="margin:0;background:#0B0B0C;font-family:Arial,Helvetica,sans-serif;color:#F5F5F5">
  <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px">
    <table width="100%" style="max-width:480px;background:#16161A;border-radius:16px;padding:32px">
      <tr><td align="center" style="font-size:40px;font-weight:900;letter-spacing:4px;color:#E10600">RF8</td></tr>
      <tr><td style="padding-top:24px;font-size:18px">Hola ${escape(name)} 👋</td></tr>
      <tr><td style="padding-top:12px;font-size:15px;line-height:1.5;color:#BDBDC2">
        Te damos la bienvenida a <b>RF8 Gimnasio</b>. Tocá el botón para crear tu usuario y contraseña
        desde la app.
      </td></tr>
      <tr><td align="center" style="padding:28px 0">
        <a href="${link}" style="background:#E10600;color:#fff;text-decoration:none;padding:14px 28px;border-radius:12px;font-weight:bold;display:inline-block">
          Crear mi usuario
        </a>
      </td></tr>
      <tr><td style="font-size:13px;color:#8A8A90;line-height:1.5">
        ¿El botón no abre la app? Abrí RF8, tocá <b>"Tengo una invitación"</b> y pegá este código:<br>
        <code style="display:block;margin-top:8px;padding:10px;background:#0B0B0C;border-radius:8px;color:#F5F5F5;word-break:break-all">${token}</code>
      </td></tr>
      <tr><td style="padding-top:20px;font-size:12px;color:#6A6A70">El link vence en ${ttl} horas.</td></tr>
    </table>
  </td></tr></table>
</body></html>`;
}
