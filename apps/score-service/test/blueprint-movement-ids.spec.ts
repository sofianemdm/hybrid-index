import { blueprintMovementIds, WOD_BLUEPRINTS } from "../src/wods/wod-blueprints.data";
import { MOVEMENTS_BY_ID } from "../src/wods/movements.data";

/**
 * IDs CANONIQUES des mouvements d'un WOD (blueprint). Source de vérité du guide des mouvements
 * mobile : il ne devine PLUS par le nom FR. On vérifie l'ordre, l'unicité, et quelques WODs clés.
 */
describe("blueprintMovementIds — IDs canoniques ordonnés & uniques", () => {
  it("fran → thruster, pull_up (ordre des blocs)", () => {
    expect(blueprintMovementIds("fran")).toEqual(["thruster", "pull_up"]);
  });

  it("benchmark_zero → burpee, push_up, air_squat", () => {
    expect(blueprintMovementIds("benchmark_zero")).toEqual(["burpee", "push_up", "air_squat"]);
  });

  // NB : ergo_skill utilise le rameur en CALORIES → movementId canonique `row_cal` (et non `row`,
  // qui est le rameur en mètres). C'est précisément l'intérêt des IDs canoniques : le guide ne doit
  // plus confondre les deux via le nom FR « Rameur ».
  it("ergo_skill → row_cal, wall_walk, toes_to_bar", () => {
    expect(blueprintMovementIds("ergo_skill")).toEqual(["row_cal", "wall_walk", "toes_to_bar"]);
  });

  it("WOD sans blueprint (course pure) → []", () => {
    expect(blueprintMovementIds("run_5k")).toEqual([]);
    expect(blueprintMovementIds("inconnu")).toEqual([]);
  });

  it("retourne une liste SANS doublon, dans l'ordre de 1re occurrence, pour tous les blueprints", () => {
    for (const wodId of Object.keys(WOD_BLUEPRINTS)) {
      const ids = blueprintMovementIds(wodId);
      // unicité
      expect(new Set(ids).size).toBe(ids.length);
      // chaque id existe dans le catalogue de mouvements
      for (const id of ids) expect(MOVEMENTS_BY_ID.has(id)).toBe(true);
      // 1re occurrence préservée : l'ordre filtré = l'ordre des blocs dédupliqué
      const seen = new Set<string>();
      const expected = WOD_BLUEPRINTS[wodId].blocks
        .map((b) => b.movementId)
        .filter((m) => (seen.has(m) ? false : (seen.add(m), true)));
      expect(ids).toEqual(expected);
    }
  });
});
