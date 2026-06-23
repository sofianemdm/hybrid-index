import { weeklyRecapDelta } from "../src/modules/engagement/recap.logic";

describe("weeklyRecapDelta — gain d'Index de la semaine (no-drop)", () => {
  it("gain normal : courant − début de semaine", () => {
    expect(weeklyRecapDelta(78, 74)).toBe(4);
  });

  it("aucun historique avant lundi (start = now) ⇒ 0 (on ne peut pas dater le gain)", () => {
    expect(weeklyRecapDelta(74, 74)).toBe(0);
  });

  it("jamais négatif (plancher 0) même si start > now", () => {
    expect(weeklyRecapDelta(72, 75)).toBe(0);
  });

  it("indexNow null (pas encore d'Index) ⇒ 0", () => {
    expect(weeklyRecapDelta(null, null)).toBe(0);
    expect(weeklyRecapDelta(null, 70)).toBe(0);
  });
});
