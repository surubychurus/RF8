// Elimina un usuario (cuenta, perfil, turnos y membresías en cascada).
// Sólo dueños.
//
// POST { user_id }
import { error, handler, json } from "../_shared/http.ts";
import { adminClient, userClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  const caller = userClient(req);
  const { data: auth } = await caller.auth.getUser();
  if (!auth.user) return error("No autenticado", 401);

  const { data: isOwner } = await caller.rpc("is_owner");
  if (!isOwner) return error("Sin permisos", 403);

  const { user_id } = await req.json();
  if (!user_id) return error("Falta el usuario");
  if (user_id === auth.user.id) return error("No podés eliminar tu propia cuenta");

  const { error: deleteError } = await adminClient().auth.admin.deleteUser(String(user_id));
  if (deleteError) {
    console.error(deleteError);
    return error("No se pudo eliminar el usuario", 400);
  }
  return json({ ok: true });
}));
