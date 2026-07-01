/**
 * Paliers de référence par WOD et par sexe. Recalibration 28/06/2026 (anti-frustration) :
 * - champion = élite/record (INCHANGÉ) ; intermédiaire = MÉDIANE « loisir 3-6 mois » (P50, atteignable) ;
 * - occasionnel = grand débutant qui TERMINE la séance (~P12-15, jamais sous le palier).
 * Spec : docs/recalibration-paliers-2026-06.md. Valeurs en secondes (`time`) ou reps/tours/kg.
 * Cohérent avec les distributions de wods.data.ts (intermédiaire ≈ médiane du modèle).
 */
export interface WodLevels {
  champion: number;
  intermediate: number;
  occasional: number;
}

export const WOD_LEVELS: Record<string, { male: WodLevels; female: WodLevels }> = {
  hyrox_sprint: { male: { champion: 660, intermediate: 1080, occasional: 1500 }, female: { champion: 750, intermediate: 1200, occasional: 1680 } },
  fran: { male: { champion: 113, intermediate: 660, occasional: 1080 }, female: { champion: 135, intermediate: 780, occasional: 1260 } },
  grace: { male: { champion: 68, intermediate: 360, occasional: 600 }, female: { champion: 85, intermediate: 420, occasional: 660 } },
  jackie: { male: { champion: 300, intermediate: 570, occasional: 840 }, female: { champion: 340, intermediate: 650, occasional: 960 } },
  row_2k: { male: { champion: 336, intermediate: 450, occasional: 570 }, female: { champion: 381, intermediate: 510, occasional: 648 } },
  helen: { male: { champion: 390, intermediate: 750, occasional: 1080 }, female: { champion: 450, intermediate: 840, occasional: 1200 } },
  karen: { male: { champion: 300, intermediate: 690, occasional: 1020 }, female: { champion: 360, intermediate: 825, occasional: 1170 } },
  // Cindy = AMRAP : score en TOURS. Monotonie reps : champion > intermédiaire > occasionnel.
  cindy: { male: { champion: 27, intermediate: 12, occasional: 6 }, female: { champion: 23, intermediate: 10, occasional: 5 } },
  benchmark_zero: { male: { champion: 345, intermediate: 720, occasional: 1080 }, female: { champion: 390, intermediate: 828, occasional: 1170 } },
  run_5k: { male: { champion: 1020, intermediate: 1800, occasional: 2520 }, female: { champion: 1170, intermediate: 2040, occasional: 2820 } },
  run_3k: { male: { champion: 600, intermediate: 990, occasional: 1560 }, female: { champion: 690, intermediate: 1140, occasional: 1770 } },
  profil_express: { male: { champion: 205, intermediate: 400, occasional: 600 }, female: { champion: 232, intermediate: 470, occasional: 740 } },
  run_1k: { male: { champion: 131, intermediate: 330, occasional: 500 }, female: { champion: 148, intermediate: 390, occasional: 588 } },
  run_400: { male: { champion: 55, intermediate: 130, occasional: 200 }, female: { champion: 62, intermediate: 154, occasional: 232 } },
  max_pushups: { male: { champion: 60, intermediate: 20, occasional: 8 }, female: { champion: 35, intermediate: 10, occasional: 4 } },
  max_air_squats_2min: { male: { champion: 85, intermediate: 42, occasional: 25 }, female: { champion: 80, intermediate: 38, occasional: 22 } },
  max_strict_pullups: { male: { champion: 30, intermediate: 6, occasional: 2 }, female: { champion: 18, intermediate: 2, occasional: 0 } },
  squat_1rm: { male: { champion: 220, intermediate: 85, occasional: 45 }, female: { champion: 145, intermediate: 52, occasional: 30 } },
  burpees_7min: { male: { champion: 125, intermediate: 58, occasional: 35 }, female: { champion: 110, intermediate: 48, occasional: 28 } },
  // WODs « Ligue du mois » (5) — RECALIBRÉS 29/06 (sport-science). time → champion < inter < occ ;
  // reps → champion > inter > occ. inter = médiane du modèle de wods.data.ts ; champion = élite hybride
  // (≈P95-98) ; occasionnel = débutant qui termine (≈P10-15, jamais écrasé). Détail : docs/recalibration-baremes-ligue.md.
  league_sprint_ladder: { male: { champion: 630, intermediate: 810, occasional: 990 }, female: { champion: 670, intermediate: 870, occasional: 1080 } }, // s (échelle 1500 m + 6 récups d'1 min, chrono continu)
  league_engine_12: { male: { champion: 215, intermediate: 140, occasional: 75 }, female: { champion: 160, intermediate: 100, occasional: 52 } }, // reps (air squats + burpees ; course non comptée)
  league_grind_squats: { male: { champion: 540, intermediate: 320, occasional: 160 }, female: { champion: 415, intermediate: 235, occasional: 120 } }, // reps
  league_power_amrap: { male: { champion: 330, intermediate: 170, occasional: 95 }, female: { champion: 200, intermediate: 105, occasional: 58 } }, // reps
  league_hybrid_chipper: { male: { champion: 430, intermediate: 720, occasional: 1020 }, female: { champion: 470, intermediate: 790, occasional: 1080 } }, // s (cap 15 min)
  ergo_skill: { male: { champion: 360, intermediate: 750, occasional: 1080 }, female: { champion: 420, intermediate: 840, occasional: 1200 } },
  // Épreuves « Autre » : intermédiaire = finisher médian réel (loisir), occasionnel = débutant lent.
  hyrox_solo: { male: { champion: 3119, intermediate: 5700, occasional: 7800 }, female: { champion: 3265, intermediate: 6300, occasional: 8700 } },
  isabel: { male: { champion: 55, intermediate: 165, occasional: 290 }, female: { champion: 70, intermediate: 210, occasional: 360 } },
  murph: { male: { champion: 2000, intermediate: 3300, occasional: 4850 }, female: { champion: 2400, intermediate: 3600, occasional: 5300 } },
  track_10000m: { male: { champion: 1571, intermediate: 3300, occasional: 4900 }, female: { champion: 1734, intermediate: 3600, occasional: 5300 } },
  half_marathon: { male: { champion: 3440, intermediate: 7000, occasional: 9300 }, female: { champion: 3772, intermediate: 7800, occasional: 10400 } },
  marathon: { male: { champion: 7170, intermediate: 15600, occasional: 20400 }, female: { champion: 7796, intermediate: 16800, occasional: 22200 } },
};
