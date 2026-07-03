import { describe, expect, it } from "vitest";
import { MIN_AGE_YEARS, isOldEnough, maxBirthDateFor } from "./age-gating";

describe("age-gating (D4 — minimum 15 ans, consentement numérique FR)", () => {
  const now = new Date("2026-06-19T12:00:00.000Z");

  it("le minimum par défaut est 15 ans", () => {
    expect(MIN_AGE_YEARS).toBe(15);
  });

  it("accepte un âge exactement égal à 15 ans (jour anniversaire)", () => {
    expect(isOldEnough(new Date("2011-06-19T00:00:00.000Z"), now)).toBe(true);
  });

  it("refuse un mineur de moins de 15 ans", () => {
    expect(isOldEnough(new Date("2012-01-01T00:00:00.000Z"), now)).toBe(false);
    expect(isOldEnough(new Date("2011-06-20T00:00:00.000Z"), now)).toBe(false); // 15 ans moins 1 jour
  });

  it("accepte largement les adultes", () => {
    expect(isOldEnough(new Date("1990-03-10T00:00:00.000Z"), now)).toBe(true);
  });

  it("maxBirthDateFor renvoie la date limite (now - minYears)", () => {
    expect(maxBirthDateFor(now).toISOString()).toBe("2011-06-19T12:00:00.000Z");
    expect(maxBirthDateFor(now, 18).toISOString()).toBe("2008-06-19T12:00:00.000Z");
  });
});
