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
  hyrox_sprint: { male: { champion: 660, intermediate: 960, occasional: 1260 }, female: { champion: 750, intermediate: 1080, occasional: 1440 } },
  fran: { male: { champion: 113, intermediate: 345, occasional: 540 }, female: { champion: 135, intermediate: 390, occasional: 660 } },
  grace: { male: { champion: 68, intermediate: 203, occasional: 360 }, female: { champion: 85, intermediate: 236, occasional: 420 } },
  jackie: { male: { champion: 300, intermediate: 480, occasional: 660 }, female: { champion: 340, intermediate: 555, occasional: 780 } },
  row_2k: { male: { champion: 336, intermediate: 450, occasional: 540 }, female: { champion: 381, intermediate: 510, occasional: 630 } },
  helen: { male: { champion: 390, intermediate: 590, occasional: 840 }, female: { champion: 450, intermediate: 674, occasional: 960 } },
  karen: { male: { champion: 300, intermediate: 555, occasional: 780 }, female: { champion: 360, intermediate: 660, occasional: 900 } },
  cindy: { male: { champion: 28, intermediate: 15, occasional: 8 }, female: { champion: 24, intermediate: 12, occasional: 6 } },
  benchmark_zero: { male: { champion: 345, intermediate: 570, occasional: 840 }, female: { champion: 390, intermediate: 645, occasional: 945 } },
  run_5k: { male: { champion: 1020, intermediate: 1620, occasional: 2400 }, female: { champion: 1170, intermediate: 1860, occasional: 2700 } },
  run_1k: { male: { champion: 131, intermediate: 300, occasional: 450 }, female: { champion: 148, intermediate: 360, occasional: 540 } },
  max_pushups: { male: { champion: 60, intermediate: 25, occasional: 10 }, female: { champion: 35, intermediate: 12, occasional: 4 } },
  max_air_squats_2min: { male: { champion: 85, intermediate: 50, occasional: 30 }, female: { champion: 80, intermediate: 45, occasional: 28 } },
  burpees_7min: { male: { champion: 125, intermediate: 70, occasional: 40 }, female: { champion: 110, intermediate: 60, occasional: 35 } },
  ergo_skill: { male: { champion: 360, intermediate: 600, occasional: 900 }, female: { champion: 420, intermediate: 690, occasional: 1020 } },
  // Épreuves « Autre » jouables (sport-science, 22 juin). champion = proReference (record/élite),
  // intermédiaire = médiane amateur, occasionnel ≈ amateur plus lent (≈ P30 du classement, soit un
  // temps PLUS élevé que la médiane — monotonie time : champion < intermédiaire < occasionnel).
  hyrox_solo: { male: { champion: 3119, intermediate: 5400, occasional: 6030 }, female: { champion: 3265, intermediate: 6000, occasional: 6700 } },
  isabel: { male: { champion: 55, intermediate: 150, occasional: 179 }, female: { champion: 70, intermediate: 190, occasional: 227 } },
  murph: { male: { champion: 2000, intermediate: 3300, occasional: 3860 }, female: { champion: 2400, intermediate: 3600, occasional: 4212 } },
  track_10000m: { male: { champion: 1571, intermediate: 3300, occasional: 3742 }, female: { champion: 1734, intermediate: 3600, occasional: 4082 } },
  half_marathon: { male: { champion: 3440, intermediate: 7200, occasional: 8080 }, female: { champion: 3772, intermediate: 8100, occasional: 9090 } },
  marathon: { male: { champion: 7235, intermediate: 16200, occasional: 18181 }, female: { champion: 7796, intermediate: 17400, occasional: 19527 } },
};
