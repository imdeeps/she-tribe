// Checks the code. If it is right, signs the person in (creating their account the first time).
// Returns a one-time token the app exchanges for a normal Supabase session.
import { admin, cors, dbStore, json, otpConfig } from "../_shared/env.ts";
import { checkOtp, OtpError } from "../_shared/otp.ts";

function loginEmail(phone: string) {
  // Supabase sessions are issued per email, so each phone gets a private placeholder address.
  return `${phone.replace("+", "")}@phone.shetribe.invalid`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { phone: rawPhone, code } = await req.json();
    const phone = await checkOtp(dbStore, otpConfig(), String(rawPhone ?? ""), String(code ?? ""));
    const email = loginEmail(phone);

    const { data: existing } = await admin.from("phone_accounts").select("user_id")
      .eq("phone", phone).maybeSingle();

    if (!existing) {
      const { data: created, error } = await admin.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: { phone },
      });
      if (error || !created.user) throw error ?? new Error("could not create user");
      const { error: linkErr } = await admin.from("phone_accounts")
        .insert({ user_id: created.user.id, phone });
      if (linkErr) throw linkErr;
    }

    const { data: link, error: linkError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
    });
    if (linkError || !link?.properties?.hashed_token) throw linkError ?? new Error("no token");

    return json({ token_hash: link.properties.hashed_token });
  } catch (e) {
    if (e instanceof OtpError) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});
