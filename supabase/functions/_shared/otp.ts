// WhatsApp one-time-code logic, written without any Deno or Supabase imports
// so it can be tested anywhere (see ../../tests/otp.test.mjs).

export class OtpError extends Error {
  status: number;
  constructor(message: string, status = 400) {
    super(message);
    this.status = status;
  }
}

export interface OtpRow {
  id: string;
  phone: string;
  code_hash: string;
  expires_at: string;
  attempts: number;
  consumed: boolean;
  created_at: string;
}

export interface OtpStore {
  /** Codes created for this phone since the given ISO time, newest first. */
  recent(phone: string, sinceIso: string): Promise<OtpRow[]>;
  insert(row: { phone: string; code_hash: string; expires_at: string }): Promise<void>;
  /** Newest code that is not consumed and not expired. */
  latestActive(phone: string, nowIso: string): Promise<OtpRow | null>;
  bumpAttempts(id: string): Promise<void>;
  consume(id: string): Promise<void>;
}

export interface OtpConfig {
  pepper: string;
  /** Phone numbers (E.164) that always use `testCode` and never receive a WhatsApp message. */
  testNumbers: string[];
  testCode: string;
  /** Sends the real WhatsApp message. Leave undefined if WhatsApp is not set up yet. */
  sendWhatsApp?: (phone: string, code: string) => Promise<void>;
  now?: () => Date;
  ttlMs?: number;
  maxAttempts?: number;
  maxSendsPer10Min?: number;
  minGapMs?: number;
}

/** Turns what a person types into +<country><number>, or null if it can't be a phone number. */
export function normalizePhone(input: string): string | null {
  const raw = (input ?? "").trim();
  if (!raw) return null;
  const hasPlus = raw.startsWith("+");
  const digits = raw.replace(/\D/g, "");
  if (hasPlus) {
    return digits.length >= 8 && digits.length <= 15 ? "+" + digits : null;
  }
  if (digits.length === 10 && /^[6-9]/.test(digits)) return "+91" + digits;
  if (digits.length === 12 && digits.startsWith("91") && /^[6-9]/.test(digits[2])) return "+" + digits;
  if (digits.length === 11 && digits.startsWith("0") && /^[6-9]/.test(digits[1])) return "+91" + digits.slice(1);
  return null;
}

export async function hashCode(pepper: string, phone: string, code: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${phone}:${code}`));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function randomCode(): string {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return String(100000 + (buf[0] % 900000));
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Creates and sends a code. Returns the normalised phone. */
export async function requestOtp(
  store: OtpStore,
  cfg: OtpConfig,
  rawPhone: string,
): Promise<{ phone: string; test: boolean }> {
  const now = (cfg.now ?? (() => new Date()))();
  const ttl = cfg.ttlMs ?? 5 * 60_000;
  const maxSends = cfg.maxSendsPer10Min ?? 3;
  const minGap = cfg.minGapMs ?? 30_000;

  const phone = normalizePhone(rawPhone);
  if (!phone) throw new OtpError("Please enter a valid mobile number.");

  const recent = await store.recent(phone, new Date(now.getTime() - 10 * 60_000).toISOString());
  if (recent.length >= maxSends) {
    throw new OtpError("Too many codes requested. Please wait a few minutes and try again.", 429);
  }
  if (recent.length > 0 && now.getTime() - new Date(recent[0].created_at).getTime() < minGap) {
    throw new OtpError("Please wait a few seconds before asking for another code.", 429);
  }

  const isTest = cfg.testNumbers.includes(phone);
  if (!isTest && !cfg.sendWhatsApp) {
    throw new OtpError("WhatsApp sign-in is not set up yet. Please try again later.", 503);
  }

  const code = isTest ? cfg.testCode : randomCode();
  await store.insert({
    phone,
    code_hash: await hashCode(cfg.pepper, phone, code),
    expires_at: new Date(now.getTime() + ttl).toISOString(),
  });

  if (!isTest) {
    try {
      await cfg.sendWhatsApp!(phone, code);
    } catch (_e) {
      throw new OtpError("We could not send the WhatsApp message. Please try again.", 502);
    }
  }
  return { phone, test: isTest };
}

/** Checks a code. Returns the normalised phone when it is correct. */
export async function checkOtp(
  store: OtpStore,
  cfg: OtpConfig,
  rawPhone: string,
  rawCode: string,
): Promise<string> {
  const now = (cfg.now ?? (() => new Date()))();
  const maxAttempts = cfg.maxAttempts ?? 5;

  const phone = normalizePhone(rawPhone);
  const code = (rawCode ?? "").replace(/\s/g, "");
  if (!phone || !/^\d{4,10}$/.test(code)) throw new OtpError("That code is not right.");

  const row = await store.latestActive(phone, now.toISOString());
  if (!row) throw new OtpError("That code has expired. Please ask for a new one.");
  if (row.attempts >= maxAttempts) {
    throw new OtpError("Too many wrong tries. Please ask for a new code.", 429);
  }

  const expected = await hashCode(cfg.pepper, phone, code);
  if (!safeEqual(expected, row.code_hash)) {
    await store.bumpAttempts(row.id);
    throw new OtpError("That code is not right.");
  }

  await store.consume(row.id);
  return phone;
}
