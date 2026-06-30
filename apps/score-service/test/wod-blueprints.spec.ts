import { WODS } from "../src/wods/wods.data";
import { WOD_BLUEPRINTS, blueprintMovementsExist } from "../src/wods/wod-blueprints.data";
import { MOVEMENTS_BY_ID } from "../src/wods/movements.data";

/**
 * TEST D'INTÉGRITÉ « plus jamais de repli population silencieux » (audit prédiction des temps §3a).
 *
 * Règle d'or : tout WOD loguable comportant ≥ 2 mouvements DISTINCTS OU ≥ 1 mouvement CHARGÉ DOIT
 * avoir un blueprint exploitable (mouvements connus). Sinon `predictResult` retomberait EN SILENCE
 * sur le modèle population (moyenne d'attributs → percentile → quantile), exactement le défaut que
 * la refonte « pro » par mouvement visait à supprimer.
 *
 * La LISTE BLANCHE explicite recense les seuls replis LÉGITIMES : course pure (Riegel), max-reps en
 * une série (mono-mouvement), 1RM en charge. Tout WOD hors liste blanche et sans blueprint = échec.
 */

/** Replis population LÉGITIMES : course pure / max-reps mono-mouvement / 1RM. */
const FALLBACK_WHITELIST = new Set<string>([
  // Course pure (normalisée via Riegel) — pas de décomposition multi-mouvements.
  "run_5k",
  "run_3k",
  "run_1k",
  "run_free_distance",
  "track_10000m",
  "half_marathon",
  "marathon",
  // Max-reps en UNE série (mono-mouvement) : la cadence à l'échec n'est pas un assemblage de blocs.
  "max_pushups",
  "max_air_squats",
  "max_air_squats_2min",
  "max_strict_pullups",
  "burpees_7min",
  // 1RM en charge absolue (load) : une seule levée maximale, pas un volume chronométré.
  "squat_1rm",
]);

describe("Intégrité blueprints — interdiction du repli population silencieux", () => {
  it("tout WOD ≥2 mouvements distincts OU chargé a un blueprint (sauf liste blanche course/max-reps/1RM)", () => {
    const offenders: string[] = [];
    for (const wod of WODS) {
      if (WOD_BLUEPRINTS[wod.id]) continue; // a déjà un blueprint → conforme
      if (FALLBACK_WHITELIST.has(wod.id)) continue; // repli légitime explicitement autorisé
      // Tout autre WOD sans blueprint est un repli SILENCIEUX interdit.
      offenders.push(wod.id);
    }
    expect(offenders).toEqual([]);
  });

  it("aucun WOD de la liste blanche n'est en réalité multi-mouvements masqué (garde-fou inverse)", () => {
    // La liste blanche ne doit contenir que des WODs réellement mono (course/max-reps/1RM). Si un
    // jour l'un d'eux gagne un blueprint, il sort de la liste blanche (sinon incohérence).
    for (const id of FALLBACK_WHITELIST) {
      expect(WOD_BLUEPRINTS[id]).toBeUndefined();
    }
  });

  it("chaque blueprint ne référence que des mouvements connus et résolubles", () => {
    for (const [wodId, bp] of Object.entries(WOD_BLUEPRINTS)) {
      expect(blueprintMovementsExist(bp)).toBe(true);
      for (const block of bp.blocks) {
        expect(MOVEMENTS_BY_ID.has(block.movementId)).toBe(true);
        expect(block.repsPerRound.length).toBeGreaterThan(0);
        for (const n of block.repsPerRound) expect(n).toBeGreaterThan(0);
      }
      // Cohérence charge : un loadKg porte bien les deux sexes, strictement positifs.
      for (const block of bp.blocks) {
        if (block.loadKg) {
          expect(block.loadKg.male).toBeGreaterThan(0);
          expect(block.loadKg.female).toBeGreaterThan(0);
        }
      }
      void wodId;
    }
  });

  it("les 8 WODs jusque-là en repli silencieux ont désormais un blueprint", () => {
    // Cf. audit §1.2 : Le Chaos, Murph, Isabel, HYROX solo + 4 Ligue retombaient sur la population.
    for (const id of [
      "league_hybrid_chipper",
      "murph",
      "isabel",
      "hyrox_solo",
      "league_sprint_ladder",
      "league_engine_12",
      "league_grind_squats",
      "league_power_amrap",
    ]) {
      expect(WOD_BLUEPRINTS[id]).toBeDefined();
    }
  });

  it("Le Moteur : la course imposée est `unscored` (compte au temps, pas au volume de reps)", () => {
    const run = WOD_BLUEPRINTS["league_engine_12"].blocks.find((b) => b.movementId === "run");
    expect(run?.unscored).toBe(true);
  });

  it("Murph cible bien la FORCE via le pull-up (mur réel des 100 tractions strictes)", () => {
    const pull = WOD_BLUEPRINTS["murph"].blocks.find((b) => b.movementId === "pull_up");
    expect(pull).toBeDefined();
    const m = MOVEMENTS_BY_ID.get("pull_up")!;
    expect(m.attributes.some((a) => a.attribute === "strength")).toBe(true);
  });
});
