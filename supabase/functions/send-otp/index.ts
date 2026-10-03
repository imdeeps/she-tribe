// Sends a sign-in code to a WhatsApp number.
import { cors, dbStore, json, otpConfig } from "../_shared/env.ts";
import { OtpError, requestOtp } from "../_shared/otp.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { phone } = await req.json();
    const result = await requestOtp(dbStore, otpConfig(), String(phone ?? ""));
    return json({ ok: true, test: result.test });
  } catch (e) {
    if (e instanceof OtpError) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});
