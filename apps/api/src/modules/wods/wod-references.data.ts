/**
 * « Références Pro » : cibles à viser sur les WODs ayant un équivalent réel.
 * DONNÉES PUBLIQUES de performance (records non officiels / temps d'élite documentés),
 * attribuées à l'athlète quand c'est public et vérifiable. CE N'EST PAS de l'usurpation :
 * aucun compte n'est créé au nom des athlètes, ce sont des repères factuels affichés comme cibles.
 * Non affilié aux athlètes cités. Unités : secondes pour `time`, répétitions/tours pour `reps`.
 */

export type ReferenceTier = "record" | "elite";

export interface WodReference {
  tier: ReferenceTier;
  sex: "male" | "female";
  /** Nom de l'athlète si la perf est publique et attribuée ; sinon null (« Élite »). */
  athlete: string | null;
  /** Résultat brut, même unité que le scoreType du WOD. */
  result: number;
  /** Affichage lisible (« 1:47 », « 2:07 · CrossFit Games 2017 »). */
  note: string;
  /** Source publique (label court). */
  source?: string;
}

export const WOD_REFERENCES: Record<string, WodReference[]> = {
  fran: [
    { tier: "record", sex: "male", athlete: "Zac Hare", result: 107, note: "1:47", source: "WOD World Records" },
    { tier: "record", sex: "female", athlete: "Marissa Flowers", result: 105, note: "1:45", source: "WOD World Records" },
    { tier: "elite", sex: "male", athlete: "Mat Fraser", result: 127, note: "2:07 · CrossFit Games 2017", source: "CrossFit Games" },
  ],
  grace: [
    { tier: "record", sex: "male", athlete: "Nick Bloch", result: 59, note: "0:59", source: "BarBend" },
    { tier: "elite", sex: "male", athlete: "Rich Froning", result: 71, note: "1:11", source: "public" },
    { tier: "elite", sex: "female", athlete: null, result: 80, note: "~1:20 (haut niveau)", source: "estimation élite" },
  ],
  row_2k: [
    { tier: "record", sex: "male", athlete: "Record du monde (poids lourd)", result: 336, note: "5:36 · Concept2", source: "Concept2" },
    { tier: "record", sex: "female", athlete: "Record du monde", result: 381, note: "6:21 · Concept2", source: "Concept2" },
  ],
  run_5k: [
    { tier: "record", sex: "male", athlete: "Joshua Cheptegei", result: 755, note: "12:35 · record du monde (piste)", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Gudaf Tsegay", result: 840, note: "14:00 · record du monde (piste)", source: "World Athletics" },
  ],
  run_1k: [
    { tier: "record", sex: "male", athlete: "Noah Ngeny", result: 132, note: "2:11.96 · record du monde", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Svetlana Masterkova", result: 149, note: "2:28.98 · record du monde", source: "World Athletics" },
  ],
  helen: [{ tier: "elite", sex: "male", athlete: null, result: 420, note: "~7:00 (haut niveau)", source: "estimation élite" }],
  karen: [{ tier: "elite", sex: "male", athlete: null, result: 300, note: "~5:00 (haut niveau)", source: "estimation élite" }],
  jackie: [{ tier: "elite", sex: "male", athlete: null, result: 300, note: "~5:00 (haut niveau)", source: "estimation élite" }],
  cindy: [{ tier: "elite", sex: "male", athlete: null, result: 30, note: "~30 tours (haut niveau)", source: "estimation élite" }],
};
