import { RegisterRequest } from "../src/modules/auth/auth.dto";
import { UpdateMeRequest } from "../src/modules/me/me.dto";

/**
 * Contrats d'entrée (logique pure Zod, sans BD) :
 *  - T4 : `goal` optionnel à l'inscription → défaut neutre « all_round » (le front retire le choix
 *    hyrox/crossfit/condition).
 *  - T3 : `displayName` figé après création → absent du DTO de mise à jour, rejeté s'il est fourni.
 */
describe("RegisterRequest — goal optionnel (T4)", () => {
  const base = {
    email: "a@b.co",
    password: "motdepasse123",
    displayName: "Sofiane",
    dateOfBirth: "1995-05-10",
    sex: "male",
  };

  it("register SANS goal → all_round par défaut", () => {
    const parsed = RegisterRequest.parse(base);
    expect(parsed.goal).toBe("all_round");
    expect(parsed.equipmentPref).toBe("both"); // défaut existant inchangé
  });

  it("register AVEC goal explicite → goal conservé (usages existants non cassés)", () => {
    expect(RegisterRequest.parse({ ...base, goal: "hyrox" }).goal).toBe("hyrox");
    expect(RegisterRequest.parse({ ...base, goal: "crossfit_strength" }).goal).toBe("crossfit_strength");
  });

  it("register avec goal invalide → rejet", () => {
    expect(RegisterRequest.safeParse({ ...base, goal: "powerlifting" }).success).toBe(false);
  });
});

describe("UpdateMeRequest — pseudo non modifiable (T3)", () => {
  it("accepte objectif et/ou matériel", () => {
    expect(UpdateMeRequest.parse({ goal: "hyrox" }).goal).toBe("hyrox");
    expect(UpdateMeRequest.parse({ equipmentPref: "none" }).equipmentPref).toBe("none");
  });

  it("REJETTE une tentative de modification du pseudo (champ inconnu, .strict)", () => {
    const res = UpdateMeRequest.safeParse({ displayName: "NouveauPseudo" });
    expect(res.success).toBe(false);
  });

  it("REJETTE displayName même accompagné d'un champ valide (jamais appliqué)", () => {
    const res = UpdateMeRequest.safeParse({ displayName: "Triche", goal: "hyrox" });
    expect(res.success).toBe(false);
  });

  it("REJETTE un corps vide (aucun champ à mettre à jour)", () => {
    expect(UpdateMeRequest.safeParse({}).success).toBe(false);
  });

  it("le type parsé n'expose plus displayName", () => {
    const parsed = UpdateMeRequest.parse({ goal: "all_round" });
    expect("displayName" in parsed).toBe(false);
  });
});
