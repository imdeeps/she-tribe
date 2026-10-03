// Run with:  node --experimental-strip-types --test supabase/tests/otp.test.ts   (Node 22+)
import test from "node:test";
import assert from "node:assert/strict";
import { checkOtp, hashCode, normalizePhone, OtpError, requestOtp } from "../functions/_shared/otp.ts";
import type { OtpConfig, OtpRow, OtpStore } from "../functions/_shared/otp.ts";

function memoryStore(clock: { now: Date }) {
  const rows: OtpRow[] = [];
  let id = 0;
  const store: OtpStore = {
    async recent(phone, sinceIso) {
      return rows.filter((r) => r.phone === phone && r.created_at >= sinceIso)
        .sort((a, b) => b.created_at.localeCompare(a.created_at));
    },
    async insert(row) {
      rows.push({ id: String(++id), attempts: 0, consumed: false, created_at: clock.now.toISOString(), ...row });
    },
    async latestActive(phone, nowIso) {
      return rows.filter((r) => r.phone === phone && !r.consumed && r.expires_at > nowIso)
        .sort((a, b) => b.created_at.localeCompare(a.created_at))[0] ?? null;
    },
    async bumpAttempts(i) { rows.find((r) => r.id === i)!.attempts++; },
    async consume(i) { rows.find((r) => r.id === i)!.consumed = true; },
  };
  return { store, rows };
}

const DUMMY = "+919999900000";

function setup(extra: Partial<OtpConfig> = {}) {
  const clock = { now: new Date("2026-10-03T10:00:00Z") };
  const { store, rows } = memoryStore(clock);
  const sent: Array<[string, string]> = [];
  const cfg: OtpConfig = {
    pepper: "test-pepper",
    testNumbers: [DUMMY],
    testCode: "123456",
    sendWhatsApp: async (phone, code) => { sent.push([phone, code]); },
    now: () => clock.now,
    ...extra,
  };
  return { clock, store, rows, sent, cfg };
}

test("phone numbers are normalised to E.164", () => {
  assert.equal(normalizePhone("98765 43210"), "+919876543210");
  assert.equal(normalizePhone("09876543210"), "+919876543210");
  assert.equal(normalizePhone("919876543210"), "+919876543210");
  assert.equal(normalizePhone("+91 98765-43210"), "+919876543210");
  assert.equal(normalizePhone("+44 7700 900123"), "+447700900123");
  assert.equal(normalizePhone("12345"), null);
  assert.equal(normalizePhone("5876543210"), null); // Indian mobiles start 6-9
  assert.equal(normalizePhone(""), null);
});

test("dummy number: no WhatsApp message is sent, and 123456 signs in", async () => {
  const { store, cfg, sent } = setup();
  const r = await requestOtp(store, cfg, "+91 99999 00000");
  assert.equal(r.test, true);
  assert.equal(sent.length, 0);
  assert.equal(await checkOtp(store, cfg, DUMMY, "123456"), DUMMY);
});

test("a code can be used only once", async () => {
  const { store, cfg } = setup();
  await requestOtp(store, cfg, DUMMY);
  await checkOtp(store, cfg, DUMMY, "123456");
  await assert.rejects(checkOtp(store, cfg, DUMMY, "123456"), /expired/);
});

test("wrong code is rejected, and 5 wrong tries lock that code", async () => {
  const { store, cfg } = setup();
  await requestOtp(store, cfg, DUMMY);
  for (let i = 0; i < 5; i++) await assert.rejects(checkOtp(store, cfg, DUMMY, "000000"), /not right/);
  await assert.rejects(checkOtp(store, cfg, DUMMY, "123456"), /Too many wrong tries/);
});

test("code expires after 5 minutes", async () => {
  const { store, cfg, clock } = setup();
  await requestOtp(store, cfg, DUMMY);
  clock.now = new Date(clock.now.getTime() + 5 * 60_000 + 1000);
  await assert.rejects(checkOtp(store, cfg, DUMMY, "123456"), /expired/);
});

test("real numbers get a random 6-digit code over WhatsApp, stored only as a hash", async () => {
  const { store, cfg, sent, rows } = setup();
  const r = await requestOtp(store, cfg, "9876543210");
  assert.equal(r.test, false);
  assert.equal(sent.length, 1);
  assert.equal(sent[0][0], "+919876543210");
  assert.match(sent[0][1], /^\d{6}$/);
  assert.ok(!JSON.stringify(rows).includes(sent[0][1]), "plain code must not be stored");
  assert.equal(rows[0].code_hash, await hashCode("test-pepper", "+919876543210", sent[0][1]));
  assert.equal(await checkOtp(store, cfg, "9876543210", sent[0][1]), "+919876543210");
});

test("the dummy code does NOT work for a real number", async () => {
  const { store, cfg } = setup();
  await requestOtp(store, cfg, "9876543210");
  await assert.rejects(checkOtp(store, cfg, "9876543210", "123456"), /not right/);
});

test("a code for one phone cannot be used for another", async () => {
  const { store, cfg, sent } = setup();
  await requestOtp(store, cfg, "9876543210");
  await assert.rejects(checkOtp(store, cfg, "9123456789", sent[0][1]), /expired/);
});

test("without WhatsApp configured, real numbers are refused but the dummy still works", async () => {
  const { store, cfg } = setup({ sendWhatsApp: undefined });
  await assert.rejects(requestOtp(store, cfg, "9876543210"), (e: unknown) =>
    e instanceof OtpError && e.status === 503);
  await requestOtp(store, cfg, DUMMY);
});

test("sending is rate-limited: 30s gap and 3 per 10 minutes", async () => {
  const { store, cfg, clock } = setup();
  await requestOtp(store, cfg, DUMMY);
  await assert.rejects(requestOtp(store, cfg, DUMMY), /wait a few seconds/);
  clock.now = new Date(clock.now.getTime() + 31_000);
  await requestOtp(store, cfg, DUMMY);
  clock.now = new Date(clock.now.getTime() + 31_000);
  await requestOtp(store, cfg, DUMMY);
  clock.now = new Date(clock.now.getTime() + 31_000);
  await assert.rejects(requestOtp(store, cfg, DUMMY), /Too many codes/);
  clock.now = new Date(clock.now.getTime() + 10 * 60_000);
  await requestOtp(store, cfg, DUMMY);
});

test("a failing WhatsApp send reports an error", async () => {
  const { store, cfg } = setup({ sendWhatsApp: async () => { throw new Error("boom"); } });
  await assert.rejects(requestOtp(store, cfg, "9876543210"), (e: unknown) =>
    e instanceof OtpError && e.status === 502);
});

test("an invalid number or malformed code is rejected early", async () => {
  const { store, cfg } = setup();
  await assert.rejects(requestOtp(store, cfg, "123"), /valid mobile/);
  await assert.rejects(checkOtp(store, cfg, DUMMY, "abc"), /not right/);
});
