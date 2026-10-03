import { createClient } from "npm:@supabase/supabase-js@2";
import { OtpConfig, OtpRow, OtpStore } from "./otp.ts";
import { whatsappSender } from "./whatsapp.ts";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
export const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

export function otpConfig(): OtpConfig {
  const token = Deno.env.get("WHATSAPP_TOKEN");
  const phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  const testNumbers = (Deno.env.get("OTP_TEST_NUMBERS") ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  return {
    pepper: Deno.env.get("OTP_PEPPER") ?? SERVICE_KEY,
    testNumbers,
    testCode: Deno.env.get("OTP_TEST_CODE") ?? "123456",
    sendWhatsApp: token && phoneNumberId
      ? whatsappSender({
        token,
        phoneNumberId,
        templateName: Deno.env.get("WHATSAPP_TEMPLATE_NAME") ?? "shetribe_login_code",
        language: Deno.env.get("WHATSAPP_TEMPLATE_LANG") ?? "en",
        apiVersion: Deno.env.get("WHATSAPP_API_VERSION") ?? "v23.0",
      })
      : undefined,
  };
}

export const dbStore: OtpStore = {
  async recent(phone, sinceIso) {
    const { data, error } = await admin.from("otp_codes").select("*")
      .eq("phone", phone).gte("created_at", sinceIso).order("created_at", { ascending: false });
    if (error) throw error;
    return (data ?? []) as OtpRow[];
  },
  async insert(row) {
    const { error } = await admin.from("otp_codes").insert(row);
    if (error) throw error;
  },
  async latestActive(phone, nowIso) {
    const { data, error } = await admin.from("otp_codes").select("*")
      .eq("phone", phone).eq("consumed", false).gt("expires_at", nowIso)
      .order("created_at", { ascending: false }).limit(1);
    if (error) throw error;
    return ((data ?? [])[0] as OtpRow) ?? null;
  },
  async bumpAttempts(id) {
    const { data } = await admin.from("otp_codes").select("attempts").eq("id", id).single();
    await admin.from("otp_codes").update({ attempts: (data?.attempts ?? 0) + 1 }).eq("id", id);
  },
  async consume(id) {
    await admin.from("otp_codes").update({ consumed: true }).eq("id", id);
  },
};
