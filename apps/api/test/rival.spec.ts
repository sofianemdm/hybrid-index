import { buildRival } from "../src/modules/profile/rival.logic";
import { ratingFromInternal } from "@hybrid-index/scoring-core";

/** Valeur interne /1000 dont l'OVR /100 arrondi vaut `ovr`. Recherche simple par balayage. */
function internalForOvr(ovr: number): number {
  let v = 0;
  for (let i = 0; i <= 1000; i++) {
    if (Math.round(ratingFromInternal(i)) >= ovr) {
      v = i;
      break;
    }
  }
  return v;
}

describe("buildRival — rival amical (logique pure)", () => {
  it("leader (above = 0) ⇒ pas de rival", () => {
    expect(buildRival(500, 0, { value: 600, displayName: "X", rank: "gold" })).toBeNull();
  });

  it("aucun candidat ⇒ pas de rival", () => {
    expect(buildRival(500, 3, null)).toBeNull();
  });

  it("rival immédiatement au-dessus : OVR + position + écart corrects", () => {
    const me = internalForOvr(70);
    const rivalVal = internalForOvr(75);
    const r = buildRival(me, 4, { value: rivalVal, displayName: "Kevin", rank: "platinum" })!;
    expect(r.displayName).toBe("Kevin");
    expect(r.rank).toBe("platinum");
    expect(r.ovr).toBe(75);
    expect(r.position).toBe(4); // ma place = above + 1 = 5, le rival est à 4
    expect(r.gapPoints).toBe(5);
  });

  it("gapPoints plancher à 1 même si les OVR arrondis sont égaux (toujours motivant)", () => {
    const me = internalForOvr(73);
    // rival juste au-dessus en interne mais même OVR arrondi → écart annoncé = 1, jamais 0.
    const r = buildRival(me, 2, { value: me + 1, displayName: "Sam", rank: "gold" })!;
    expect(r.gapPoints).toBeGreaterThanOrEqual(1);
  });

  it("profil de rival incomplet ⇒ repli « — » / « rookie »", () => {
    const r = buildRival(internalForOvr(60), 1, { value: internalForOvr(62), displayName: null, rank: null })!;
    expect(r.displayName).toBe("—");
    expect(r.rank).toBe("rookie");
  });
});
