import { WODS_BY_ID } from "../src/wods/wods.data";
import { percentile } from "@hybrid-index/scoring-core";

/**
 * GOLDEN de CALIBRATION « réalité de salle » (audit prédiction des temps §2/§3b).
 *
 * Verrouille l'objectif anti-frustration de la recalibration des distributions : un résultat de
 * pratiquant ~1 an HONORABLE doit ressortir « au-dessus du milieu », pas « sous le 1er quintile ».
 * Avant recalibrage, un Fran à 9:50 tombait à P≈0,16 (« mauvais ») — un bug de calibrage. Après
 * (médiane 11:00 / σ 0,34), il doit passer à P≈0,57.
 *
 * Ne touche QUE la NOTATION via les distributions `bySex.model` (recalibrage assumé : l'ancienne
 * notation était fausse). Aucun lien avec l'estimation per-mouvement.
 */
describe("Calibration salle — cohérence scoring ↔ terrain", () => {
  const pct = (wodId: string, sex: "male" | "female", raw: number) =>
    percentile(raw, WODS_BY_ID.get(wodId)!.bySex[sex].model);

  it("Fran H 9:50 (590 s) ressort « bon / au-dessus du milieu » (P ∈ [0,50 ; 0,65])", () => {
    const p = pct("fran", "male", 590);
    expect(p).toBeGreaterThanOrEqual(0.5);
    expect(p).toBeLessThanOrEqual(0.65);
  });

  it("Fran H 11:00 (660 s) = médiane (pratiquant ~1 an) → P ≈ 0,50", () => {
    const p = pct("fran", "male", 660);
    expect(p).toBeGreaterThanOrEqual(0.46);
    expect(p).toBeLessThanOrEqual(0.54);
  });

  it("Fran H 6:30 (390 s) = très bon, rare en salle → P ≥ 0,80", () => {
    expect(pct("fran", "male", 390)).toBeGreaterThanOrEqual(0.8);
  });

  it("Fran H 1:53 (113 s) = élite intacte → P ≈ 0,999", () => {
    expect(pct("fran", "male", 113)).toBeGreaterThanOrEqual(0.99);
  });

  it("Grace H 6:00 (360 s) = médiane salle → P ≈ 0,50 ; 4:12 (252 s) clairement au-dessus", () => {
    const med = pct("grace", "male", 360);
    expect(med).toBeGreaterThanOrEqual(0.46);
    expect(med).toBeLessThanOrEqual(0.54);
    expect(pct("grace", "male", 252)).toBeGreaterThan(med);
  });

  it("la queue élite reste extraterrestre : proReference des 8 WODs recalibrés > P0,90", () => {
    for (const id of ["fran", "grace", "helen", "karen", "jackie", "benchmark_zero", "hyrox_sprint", "ergo_skill"]) {
      for (const sex of ["male", "female"] as const) {
        const ref = WODS_BY_ID.get(id)!.bySex[sex];
        expect(percentile(ref.proReference, ref.model)).toBeGreaterThan(0.9);
      }
    }
  });
});
