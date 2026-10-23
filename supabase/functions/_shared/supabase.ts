import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/** Cliente con privilegios de servicio (ignora RLS). Usar sólo en el servidor. */
export function adminClient(): SupabaseClient {
  return createClient(url, serviceKey, { auth: { persistSession: false } });
}

/** Cliente anónimo, p. ej. para iniciar sesión con contraseña. */
export function anonClient(): SupabaseClient {
  return createClient(url, anonKey, { auth: { persistSession: false } });
}

/** Cliente que actúa como el usuario que hizo la request (respeta RLS). */
export function userClient(req: Request): SupabaseClient {
  return createClient(url, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
}
