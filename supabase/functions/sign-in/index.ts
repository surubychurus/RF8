// Inicio de sesión con usuario + clave (Supabase Auth trabaja con email).
// Resuelve el email en el servidor para no exponerlo y devuelve la sesión.
//
// POST { username, password }
import { error, handler, json } from "../_shared/http.ts";
import { adminClient, anonClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  const { username, password } = await req.json();
  const cleanUsername = String(username ?? "").trim().toLowerCase();
  if (!cleanUsername || typeof password !== "string") {
    return error("Usuario o contraseña incorrectos", 401);
  }

  const { data: profile } = await adminClient()
    .from("profiles").select("email").eq("username", cleanUsername).maybeSingle();
  if (!profile) return error("Usuario o contraseña incorrectos", 401);

  const { data, error: authError } = await anonClient().auth.signInWithPassword({
    email: profile.email,
    password,
  });
  if (authError || !data.session) return error("Usuario o contraseña incorrectos", 401);

  return json({
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
  });
}));
