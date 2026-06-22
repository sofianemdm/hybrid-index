/**
 * « Autre » : entraînements/épreuves RÉELS qui ne sont PAS des séances de référence notées de
 * l'app, présentés à titre informatif avec de VRAIS temps de pros (données PUBLIQUES de
 * compétition, attribuées et sourcées). Aucune note d'Index calculée dessus, aucun faux temps.
 */

export interface OtherRef {
  athlete: string;
  sex: "male" | "female";
  /** Affichage lisible du résultat réel (« 51:59 », « 2:00:35 »). */
  note: string;
  /** Contexte / source publique. */
  source: string;
}

export interface OtherWorkout {
  id: string;
  name: string;
  category: "hyrox" | "crossfit" | "course";
  /** Format en clair. */
  format: string;
  /** Ce que c'est + comment le réaliser. */
  description: string;
  records: OtherRef[];
}

export const OTHER_WORKOUTS: OtherWorkout[] = [
  {
    id: "hyrox_solo",
    name: "HYROX (solo)",
    category: "hyrox",
    format: "8 × 1 km course + 8 stations, chronométré",
    description:
      "L'épreuve HYROX solo (Pro) : 8 km de course fractionnés en 8 × 1 km, entrelacés avec 8 stations — "
      + "SkiErg 1000 m, poussée de traîneau 50 m, tirage de traîneau 50 m, burpee-sauts 80 m, rameur 1000 m, "
      + "port de sacs (farmers) 200 m, fentes lestées 100 m, et 100 wall balls. Le tout enchaîné, pour le temps.",
    records: [
      { athlete: "Alexander Roncevic", sex: "male", note: "51:59 · record du monde (Varsovie 2026)", source: "Rox Lyfe" },
      { athlete: "Hunter McIntyre", sex: "male", note: "53:22 (Stockholm 2023)", source: "Rox Lyfe" },
      { athlete: "Joanna Wietrzyk", sex: "female", note: "54:25 · record du monde (Varsovie 2026)", source: "Rox Lyfe" },
      { athlete: "Megan Jacoby", sex: "female", note: "59:58 · championne du monde 2024 (Nice)", source: "HYROX" },
    ],
  },
  {
    id: "isabel",
    name: "Isabel",
    category: "crossfit",
    format: "30 arrachés (snatch) · 61/43 kg · pour le temps",
    description:
      "Benchmark CrossFit : 30 arrachés (snatch) à 61 kg (hommes) / 43 kg (femmes), le plus vite possible. "
      + "Test de puissance et de technique d'haltérophilie sous fatigue.",
    records: [
      { athlete: "Eddie Hall", sex: "male", note: "0:51 · record (athlète strongman)", source: "BarBend" },
      { athlete: "Élite CrossFit", sex: "male", note: "≈ 0:53", source: "compétitions" },
    ],
  },
  {
    id: "murph",
    name: "Murph",
    category: "crossfit",
    format: "1,6 km course · 100 tractions · 200 pompes · 300 squats · 1,6 km course (gilet 9/6 kg)",
    description:
      "Hero WOD : 1,6 km de course, puis 100 tractions, 200 pompes, 300 air squats (souvent fractionnés librement), "
      + "puis 1,6 km de course — classiquement avec un gilet lesté (9 kg H / 6 kg F).",
    records: [
      { athlete: "Alec Blenis", sex: "male", note: "32:41 · record (avec gilet)", source: "alecblenis.com" },
      { athlete: "Rich Froning", sex: "male", note: "≈ 34:38 (avec gilet)", source: "public" },
    ],
  },
  {
    id: "track_10000m",
    name: "10 000 m (piste)",
    category: "course",
    format: "10 000 m sur piste",
    description: "Le 10 000 mètres sur piste : 25 tours, épreuve reine de fond.",
    records: [
      { athlete: "Joshua Cheptegei", sex: "male", note: "26:11.00 · record du monde", source: "World Athletics" },
      { athlete: "Beatrice Chebet", sex: "female", note: "28:54.14 · record du monde (2024)", source: "World Athletics" },
    ],
  },
  {
    id: "half_marathon",
    name: "Semi-marathon",
    category: "course",
    format: "21,0975 km · route",
    description: "Le semi-marathon : 21,1 km sur route, l'équilibre vitesse/endurance.",
    records: [
      { athlete: "Jacob Kiplimo", sex: "male", note: "57:20 · record du monde (Lisbonne 2026)", source: "World Athletics" },
      { athlete: "Letesenbet Gidey", sex: "female", note: "1:02:52 · record du monde (Valence 2021)", source: "World Athletics" },
    ],
  },
  {
    id: "marathon",
    name: "Marathon",
    category: "course",
    format: "42,195 km · route",
    description: "Le marathon : 42,195 km sur route, l'épreuve mythique de l'endurance.",
    records: [
      { athlete: "Kelvin Kiptum", sex: "male", note: "2:00:35 · record du monde (Chicago 2023)", source: "World Athletics" },
      { athlete: "Ruth Chepngetich", sex: "female", note: "2:09:56 · record du monde (Chicago 2024)", source: "World Athletics" },
    ],
  },
];
