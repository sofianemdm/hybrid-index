/**
 * Paliers de référence RÉELS par WOD et par sexe (sport-science, 20 juin) : champion (record/élite),
 * intermédiaire (~médiane d'un pratiquant régulier), occasionnel (~débutant). Valeurs en secondes
 * (WODs `time`) ou en reps (WODs `reps`). Affichés sur la fiche WOD (échelle « où je me situe »).
 */
export interface WodLevels {
  champion: number;
  intermediate: number;
  occasional: number;
}

export const WOD_LEVELS: Record<string, { male: WodLevels; female: WodLevels }> = {
  pft_hyrox: { male: { champion: 3300, intermediate: 5100, occasional: 6600 }, female: { champion: 3540, intermediate: 5700, occasional: 7200 } },
  fran: { male: { champion: 113, intermediate: 345, occasional: 540 }, female: { champion: 135, intermediate: 390, occasional: 660 } },
  grace: { male: { champion: 68, intermediate: 203, occasional: 360 }, female: { champion: 85, intermediate: 236, occasional: 420 } },
  jackie: { male: { champion: 300, intermediate: 540, occasional: 780 }, female: { champion: 340, intermediate: 630, occasional: 900 } },
  row_2k: { male: { champion: 336, intermediate: 450, occasional: 540 }, female: { champion: 381, intermediate: 510, occasional: 630 } },
  helen: { male: { champion: 390, intermediate: 590, occasional: 840 }, female: { champion: 450, intermediate: 674, occasional: 960 } },
  karen: { male: { champion: 240, intermediate: 570, occasional: 840 }, female: { champion: 300, intermediate: 630, occasional: 960 } },
  cindy: { male: { champion: 32, intermediate: 16, occasional: 8 }, female: { champion: 25, intermediate: 13, occasional: 6 } },
  benchmark_zero: { male: { champion: 540, intermediate: 810, occasional: 1200 }, female: { champion: 630, intermediate: 960, occasional: 1380 } },
  run_5k: { male: { champion: 755, intermediate: 1878, occasional: 3180 }, female: { champion: 840, intermediate: 2184, occasional: 3360 } },
  run_1k: { male: { champion: 131, intermediate: 300, occasional: 450 }, female: { champion: 148, intermediate: 360, occasional: 540 } },
  max_pushups: { male: { champion: 100, intermediate: 25, occasional: 10 }, female: { champion: 70, intermediate: 12, occasional: 4 } },
  max_air_squats_2min: { male: { champion: 100, intermediate: 50, occasional: 30 }, female: { champion: 95, intermediate: 45, occasional: 28 } },
  burpees_7min: { male: { champion: 140, intermediate: 70, occasional: 40 }, female: { champion: 120, intermediate: 60, occasional: 35 } },
  max_situps_2min: { male: { champion: 100, intermediate: 50, occasional: 30 }, female: { champion: 95, intermediate: 45, occasional: 28 } },
};
