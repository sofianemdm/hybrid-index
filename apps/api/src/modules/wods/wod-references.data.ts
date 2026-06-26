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
    // Record du monde indoor 2000 m (catégorie lourde). « Concept2 » est la MARQUE / le logbook,
    // PAS un athlète → on nomme le vrai détenteur. Homme : Simon van Dorp 5:33.4 (a battu O. Zeidler
    // 5:34.7). Femme : détenteur non nommé faute de certitude vérifiée (formulation neutre).
    { tier: "record", sex: "male", athlete: "Simon van Dorp", result: 333, note: "5:33.4 · record du monde indoor (catégorie lourde)", source: "World Rowing" },
    { tier: "record", sex: "female", athlete: null, result: 381, note: "~6:21 · record du monde indoor (catégorie lourde)", source: "World Rowing" },
  ],
  run_5k: [
    { tier: "record", sex: "male", athlete: "Joshua Cheptegei", result: 755, note: "12:35 · record du monde (piste)", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Gudaf Tsegay", result: 840, note: "14:00 · record du monde (piste)", source: "World Athletics" },
  ],
  run_3k: [
    { tier: "record", sex: "male", athlete: "Daniel Komen", result: 441, note: "7:20.67 · record du monde", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Wang Junxia", result: 486, note: "8:06.11 · record du monde", source: "World Athletics" },
  ],
  run_1k: [
    { tier: "record", sex: "male", athlete: "Noah Ngeny", result: 132, note: "2:11.96 · record du monde", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Svetlana Masterkova", result: 149, note: "2:28.98 · record du monde", source: "World Athletics" },
  ],
  helen: [{ tier: "elite", sex: "male", athlete: null, result: 420, note: "~7:00 (haut niveau)", source: "estimation élite" }],
  karen: [{ tier: "elite", sex: "male", athlete: null, result: 300, note: "~5:00 (haut niveau)", source: "estimation élite" }],
  jackie: [{ tier: "elite", sex: "male", athlete: null, result: 300, note: "~5:00 (haut niveau)", source: "estimation élite" }],
  cindy: [{ tier: "elite", sex: "male", athlete: null, result: 30, note: "~30 tours (haut niveau)", source: "estimation élite" }],

  // Épreuves « Autre » — vrais records/élite publics.
  hyrox_solo: [
    { tier: "record", sex: "male", athlete: "Alexander Roncevic", result: 3119, note: "51:59 · record du monde", source: "Rox Lyfe" },
    { tier: "record", sex: "female", athlete: "Joanna Wietrzyk", result: 3265, note: "54:25 · record du monde", source: "Rox Lyfe" },
  ],
  isabel: [
    { tier: "record", sex: "male", athlete: "Eddie Hall", result: 51, note: "0:51 · record (strongman)", source: "BarBend" },
  ],
  murph: [
    { tier: "record", sex: "male", athlete: "Alec Blenis", result: 1961, note: "32:41 · record (avec gilet)", source: "alecblenis.com" },
  ],
  track_10000m: [
    { tier: "record", sex: "male", athlete: "Joshua Cheptegei", result: 1571, note: "26:11 · record du monde", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Beatrice Chebet", result: 1734, note: "28:54 · record du monde", source: "World Athletics" },
  ],
  half_marathon: [
    { tier: "record", sex: "male", athlete: "Jacob Kiplimo", result: 3440, note: "57:20 · record du monde", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Letesenbet Gidey", result: 3772, note: "1:02:52 · record du monde", source: "World Athletics" },
  ],
  marathon: [
    { tier: "record", sex: "male", athlete: "Sabastian Sawe", result: 7170, note: "1:59:30 · 1er marathon sub-2h, record du monde (Londres 2026)", source: "World Athletics" },
    { tier: "record", sex: "female", athlete: "Ruth Chepngetich", result: 7796, note: "2:09:56 · record du monde", source: "World Athletics" },
  ],
};
