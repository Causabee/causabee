import { describe, expect, it } from "vitest";
import { cycle } from "../src/cycle";
import { newEnd, replaces } from "../src/notifications";

const at = (s: string) => new Date(s + "T12:00:00Z");

describe("Pro's month follows the day it was bought", () => {
  it("runs from the 28th to the 28th", () => {
    expect(cycle("2026-10-28T08:22:00Z", at("2026-11-03"))).toEqual({ key: "2026-10-28", renewsOn: "2026-11-28" });
    expect(cycle("2026-10-28T08:22:00Z", at("2026-11-28"))).toEqual({ key: "2026-11-28", renewsOn: "2026-12-28" });
  });
  it("holds the 31st to a shorter month's last day", () => {
    expect(cycle("2026-01-31T10:00:00Z", at("2026-02-28"))).toEqual({ key: "2026-02-28", renewsOn: "2026-03-31" });
    expect(cycle("2026-01-31T10:00:00Z", at("2026-02-27"))).toEqual({ key: "2026-01-31", renewsOn: "2026-02-28" });
  });
  it("keeps the calendar month for an account made by hand", () => {
    expect(cycle(null, at("2026-10-28"))).toEqual({ key: "2026-10", renewsOn: "2026-11-01" });
  });
});

describe("what Apple's notifications do to the end of Pro", () => {
  const tx = { purchaseDate: 100, expiresDate: 200 };
  it("a renewal moves it later, never earlier", () => {
    expect(newEnd("DID_RENEW", undefined, true, tx, undefined)).toBe(200);
    expect(replaces("DID_RENEW", true)).toBe(false);
  });
  it("a refund ends it when it was refunded", () => {
    expect(newEnd("REFUND", undefined, true, { ...tx, revocationDate: 150 }, undefined)).toBe(150);
    expect(replaces("REFUND", true)).toBe(true);
  });
  it("a failed renewal leaves it running through the grace period", () => {
    expect(newEnd("DID_FAIL_TO_RENEW", "GRACE_PERIOD", true, tx, { gracePeriodExpiresDate: 260 })).toBe(260);
  });
  it("Plus renewing in Pro's place ends Pro when Plus began", () => {
    expect(newEnd("DID_RENEW", undefined, false, tx, undefined)).toBe(100);
    expect(replaces("DID_RENEW", false)).toBe(true);
  });
  it("a change of the renewal's plan alone changes nothing yet", () => {
    expect(newEnd("DID_CHANGE_RENEWAL_PREF", "DOWNGRADE", true, tx, undefined)).toBeNull();
  });
});
