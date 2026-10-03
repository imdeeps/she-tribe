// Lets a signed-in user delete their own account (required by the App Store).
// Payment records are kept for your accounts but are no longer linked to the person.
import { createClient } from "npm:@supabase/supabase-js@2";
import { admin, cors, json, SUPABASE_URL } from "../_shared/env.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data } = await userClient.auth.getUser();
    const user = data?.user;
    if (!user) return json({ error: "Please sign in again." }, 401);

    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) throw error;
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: "Could not delete the account. Please contact us." }, 500);
  }
});
