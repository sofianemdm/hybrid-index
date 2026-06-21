import { describe, expect, it } from "vitest";
import { dmAgeAllowed, isMinor } from "./dm-age";

const now = new Date("2026-06-21T00:00:00Z");
const adult = new Date("1995-01-01"); // 31 ans
const adult2 = new Date("2000-01-01"); // 26 ans
const minor = new Date("2012-01-01"); // 14 ans
const minor2 = new Date("2010-06-01"); // 16 ans
const justUnder18 = new Date("2008-07-01"); // 17 ans (né après le seuil)
const just18 = new Date("2008-06-01"); // 18 ans pile (né avant/le seuil)

describe("isMinor", () => {
  it("classe correctement mineurs et adultes", () => {
    expect(isMinor(minor, now)).toBe(true);
    expect(isMinor(adult, now)).toBe(false);
    expect(isMinor(justUnder18, now)).toBe(true);
    expect(isMinor(just18, now)).toBe(false);
  });
});

describe("dmAgeAllowed — séparation stricte par âge", () => {
  it("autorise adulte ↔ adulte", () => {
    expect(dmAgeAllowed(adult, adult2, now)).toBe(true);
  });
  it("autorise mineur ↔ mineur", () => {
    expect(dmAgeAllowed(minor, minor2, now)).toBe(true);
  });
  it("INTERDIT mineur ↔ adulte (dans les deux sens)", () => {
    expect(dmAgeAllowed(minor, adult, now)).toBe(false);
    expect(dmAgeAllowed(adult, minor, now)).toBe(false);
  });
});
