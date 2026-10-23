// Emails a member their ticket confirmation after an admin approves a ticket payment.
// Needs the RESEND_API_KEY secret. Only an admin can call it, and each payment is emailed once.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const FROM = Deno.env.get("TICKET_EMAIL_FROM") ?? "She Tribe <tickets@shetribe.in>";
const REPLY_TO = Deno.env.get("TICKET_REPLY_TO") ?? "";
const CONTACT = Deno.env.get("TICKET_CONTACT") ?? "+91 79041 87294";
const APP_URL = Deno.env.get("APP_URL") ?? "https://app.shetribe.in";

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function ticketCode(id: string) {
  return "ST-" + id.replace(/-/g, "").slice(0, 8).toUpperCase();
}

function when(iso: string | null) {
  if (!iso) return "Date to be announced";
  return new Date(iso).toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: u } = await userClient.auth.getUser();
    if (!u?.user) return json({ error: "Please sign in again." }, 401);

    const { data: isAdmin } = await admin.rpc("is_admin", { uid: u.user.id });
    if (isAdmin !== true) return json({ error: "Not allowed." }, 403);

    const key = Deno.env.get("RESEND_API_KEY");
    if (!key) return json({ error: "Email is not set up yet (RESEND_API_KEY is missing)." }, 500);

    const { payment_id } = await req.json();
    const { data: pay } = await admin.from("payments").select("*").eq("id", payment_id).single();
    if (!pay || pay.kind !== "ticket" || pay.status !== "approved" || !pay.registration_id) {
      return json({ error: "That payment is not an approved ticket." }, 400);
    }
    if (pay.confirmation_sent_at) return json({ ok: true, already: true });

    const { data: reg } = await admin.from("registrations").select("*").eq("id", pay.registration_id).single();
    if (!reg) return json({ error: "Registration not found." }, 400);
    const { data: ev } = await admin.from("events").select("*").eq("id", reg.event_id).single();
    const { data: tier } = await admin.from("ticket_tiers").select("name").eq("id", reg.tier_id).single();
    const { data: prof } = await admin.from("profiles").select("full_name").eq("id", reg.user_id).maybeSingle();
    const { data: au } = await admin.auth.admin.getUserById(reg.user_id);
    const to = au?.user?.email;
    if (!to || to.endsWith(".invalid")) return json({ error: "This member has no email address." }, 400);

    const name = (prof?.full_name ?? "").trim() || "there";
    const code = ticketCode(reg.id);
    const rows: [string, string][] = [
      ["Event", ev?.title ?? ""],
      ["Date and time", when(ev?.starts_at ?? null)],
      ...(ev?.venue ? [["Venue", ev.venue] as [string, string]] : []),
      ["Ticket", tier?.name ?? ""],
      ["Ticket number", code],
      ["Amount paid", `₹${pay.amount_inr}`],
    ];
    const table = rows.map(([k, v]) =>
      `<tr><td style="padding:8px 0;color:#7a5a6a;font-size:13px;text-transform:uppercase;letter-spacing:1px;width:130px;vertical-align:top">${esc(k)}</td><td style="padding:8px 0;font-size:16px;font-weight:600;color:#2a1421">${esc(v)}</td></tr>`
    ).join("");

    const html = `<div style="background:#fdf1e0;padding:24px;font-family:Arial,Helvetica,sans-serif">
<div style="max-width:520px;margin:auto;background:#fff8ee;border:1px solid #f3d9c2;border-radius:20px;overflow:hidden">
<div style="background:#3a1230;padding:22px 26px"><div style="color:#ff7a66;font-size:13px;font-weight:700;letter-spacing:3px">SHE TRIBE</div>
<div style="color:#fdf1e0;font-size:24px;font-weight:700;margin-top:6px">You’re in!</div></div>
<div style="padding:26px;color:#2a1421">
<p style="font-size:16px;margin:0 0 14px">Hi ${esc(name)}, your payment is confirmed and your seat is booked.</p>
<table style="width:100%;border-collapse:collapse">${table}</table>
<p style="font-size:15px;line-height:1.5;margin:18px 0">Open your ticket any time in the app and show the QR code at the entrance.</p>
<p style="margin:0 0 20px"><a href="${esc(APP_URL)}" style="display:inline-block;background:#c81e63;color:#fff;text-decoration:none;font-weight:700;padding:14px 26px;border-radius:999px">View my ticket</a></p>
<p style="font-size:13px;color:#7a5a6a;margin:0">Questions? Call or WhatsApp ${esc(CONTACT)}.</p>
</div></div></div>`;

    const text = `Hi ${name}, your payment is confirmed and your seat is booked.\n\n` +
      rows.map(([k, v]) => `${k}: ${v}`).join("\n") +
      `\n\nOpen your ticket in the app: ${APP_URL}\nQuestions? Call or WhatsApp ${CONTACT}.`;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: FROM,
        to: [to],
        subject: `You’re in! Your ticket for ${ev?.title ?? "She Tribe"}`,
        html,
        text,
        ...(REPLY_TO ? { reply_to: REPLY_TO } : {}),
      }),
    });
    if (!res.ok) {
      console.error("Resend error", res.status, await res.text());
      return json({ error: "The email service refused the message. Check the Resend key and domain." }, 502);
    }
    await admin.from("payments").update({ confirmation_sent_at: new Date().toISOString() }).eq("id", pay.id);
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: "Could not send the confirmation email." }, 500);
  }
});
