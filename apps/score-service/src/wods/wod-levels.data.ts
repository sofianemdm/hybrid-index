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
  // row_2k : inter 7min H / 8min F = rameur régulier compétent (ancien 7min30/8min30 = loisir).
  row_2k: { male: { champion: 336, intermediate: 420, occasional: 540 }, female: { champion: 381, intermediate: 480, occasional: 630 } },
  helen: { male: { champion: 390, intermediate: 590, occasional: 840 }, female: { champion: 450, intermediate: 674, occasional: 960 } },
  karen: { male: { champion: 300, intermediate: 555, occasional: 780 }, female: { champion: 360, intermediate: 660, occasional: 900 } },
  // Cindy = AMRAP : score en TOURS (1 tour = 5 tractions + 10 pompes + 15 air squats), PAS en reps.
  // champion = proReference (élite), intermédiaire = médiane régulier, occasionnel = débutant. Monotonie reps : champion > intermédiaire > occasionnel.
  cindy: { male: { champion: 27, intermediate: 15, occasional: 8 }, female: { champion: 23, intermediate: 12, occasional: 6 } },
  benchmark_zero: { male: { champion: 345, intermediate: 570, occasional: 840 }, female: { champion: 390, intermediate: 645, occasional: 945 } },
  // run_5k : inter 23min H / 27min F = coureur amateur entraîné (ancien 27/31 = joggeur loisir).
  run_5k: { male: { champion: 1020, intermediate: 1380, occasional: 2400 }, female: { champion: 1170, intermediate: 1620, occasional: 2700 } },
  // run_3k : inter 13min30 H / 16min F = coureur amateur entraîné (ancien 16min30/19min30 = loisir).
  run_3k: { male: { champion: 600, intermediate: 810, occasional: 1470 }, female: { champion: 690, intermediate: 960, occasional: 1650 } },
  profil_express: { male: { champion: 205, intermediate: 342, occasional: 536 }, female: { champion: 232, intermediate: 401, occasional: 668 } },
  // run_1k : inter 4min15 H / 4min48 F = coureur amateur entraîné (ancien 5min/6min = loisir).
  run_1k: { male: { champion: 131, intermediate: 255, occasional: 450 }, female: { champion: 148, intermediate: 288, occasional: 540 } },
  max_pushups: { male: { champion: 60, intermediate: 25, occasional: 10 }, female: { champion: 35, intermediate: 12, occasional: 4 } },
  max_air_squats_2min: { male: { champion: 85, intermediate: 50, occasional: 30 }, female: { champion: 80, intermediate: 45, occasional: 28 } },
  max_strict_pullups: { male: { champion: 30, intermediate: 9, occasional: 2 }, female: { champion: 18, intermediate: 3, occasional: 0 } },
  squat_1rm: { male: { champion: 220, intermediate: 100, occasional: 50 }, female: { champion: 145, intermediate: 60, occasional: 32 } },
  burpees_7min: { male: { champion: 125, intermediate: 70, occasional: 40 }, female: { champion: 110, intermediate: 60, occasional: 35 } },
  // WODs « Ligue du mois » (5). time → champion < inter < occ ; reps/tours → champion > inter > occ.
  league_sprint_ladder: { male: { champion: 290, intermediate: 420, occasional: 600 }, female: { champion: 335, intermediate: 480, occasional: 690 } }, // s
  league_engine_12: { male: { champion: 210, intermediate: 140, occasional: 90 }, female: { champion: 130, intermediate: 100, occasional: 70 } }, // reps (course non comptée)
  league_grind_squats: { male: { champion: 520, intermediate: 400, occasional: 250 }, female: { champion: 330, intermediate: 290, occasional: 175 } }, // reps
  league_power_amrap: { male: { champion: 360, intermediate: 215, occasional: 130 }, female: { champion: 195, intermediate: 127, occasional: 80 } }, // reps
  league_hybrid_chipper: { male: { champion: 400, intermediate: 660, occasional: 870 }, female: { champion: 460, intermediate: 720, occasional: 900 } }, // s
  ergo_skill: { male: { champion: 360, intermediate: 600, occasional: 900 }, female: { champion: 420, intermediate: 690, occasional: 1020 } },
  // Épreuves « Autre » jouables. Paliers = NIVEAUX DE PRATIQUANT (cibles à viser), pas le finisher
  // médian de la foule. champion = proReference (record/élite) ; intermédiaire = amateur ENTRAÎNÉ
  // et compétent ; occasionnel = débutant qui termine lentement (monotonie time : champion <
  // intermédiaire < occasionnel). Découplé du scoring (wods.data.ts garde le médian réel).
  // hyrox_solo : inter 1h15 H / 1h25 F (amateur solide ; ancien 1h30/1h40 = finisher médian).
  hyrox_solo: { male: { champion: 3119, intermediate: 4500, occasional: 7050 }, female: { champion: 3265, intermediate: 5100, occasional: 7850 } },
  // isabel (30 clean&jerk 60/40 kg) : inter ~2min30 H / 3min10 F = amateur barbell compétent.
  isabel: { male: { champion: 55, intermediate: 150, occasional: 232 }, female: { champion: 70, intermediate: 190, occasional: 294 } },
  // murph : inter ~55min H / 60min F = amateur CrossFit entraîné (gilet optionnel).
  murph: { male: { champion: 2000, intermediate: 3300, occasional: 4850 }, female: { champion: 2400, intermediate: 3600, occasional: 5300 } },
  // track_10000m : inter 43min H / 48min F = coureur sur piste entraîné (ancien 55min/60min = loisir).
  track_10000m: { male: { champion: 1571, intermediate: 2580, occasional: 4500 }, female: { champion: 1734, intermediate: 2880, occasional: 4900 } },
  // Semi. Paliers = NIVEAUX DE PRATIQUANT (cibles à viser), pas le finisher médian de la foule.
  // champion = WR réel ; intermédiaire = amateur ENTRAÎNÉ et compétent (1h35 H / 1h45 F) ;
  // occasionnel = débutant qui termine lentement (2h30 H / 2h50 F). (Le SCORING reste calé sur le
  // finisher médian réel via wods.data.ts ; ici c'est de l'affichage découplé.) Ancienne note :
  // ancien intermédiaire = finisher médian (1h57 H / 2h10 F), déplacé vers le scoring uniquement.
  half_marathon: { male: { champion: 3440, intermediate: 5700, occasional: 9000 }, female: { champion: 3772, intermediate: 6300, occasional: 10200 } },
  // Marathon. Paliers = NIVEAUX DE PRATIQUANT (cibles à viser), pas le finisher médian de la foule.
  // champion = WR réel (Sawe 1:59:30 sub-2h / Chepngetich 2:09:56) ; intermédiaire = amateur ENTRAÎNÉ et
  // compétent (3h15 H / 3h40 F) ; occasionnel = débutant qui termine lentement (5h30 H / 6h00 F).
  // Découplé du scoring : le finisher médian réel (~4h20 H / 4h40 F) reste calé dans wods.data.ts
  // pour qu'un coureur moyen score ~50/100. Ancien intermédiaire affiché = ce médian (trop lent
  // comme « cible » selon le PO : l'écart champion↔intermédiaire paraissait énorme).
  marathon: { male: { champion: 7170, intermediate: 11700, occasional: 19800 }, female: { champion: 7796, intermediate: 13200, occasional: 21600 } },
};
