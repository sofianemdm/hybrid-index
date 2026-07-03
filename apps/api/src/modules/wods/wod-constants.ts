import { ratingFromInternal } from "@hybrid-index/scoring-core";

/** Constantes et helpers PARTAGÉS du domaine WOD — extraits de l'ex-wods.service (752 lignes)
 *  au découpage du 03/07 : catalog/builder/logResult y accèdent sans dépendre l'un de l'autre,
 *  et challenge/endgame importent des CONSTANTES, plus un service. */

/** Sous-score interne /1000 → note d'affichage /100 (null si absent). */
export const ovrSub = (v: number | null): number | null => (v == null ? null : Math.round(ratingFromInternal(v)));

/** Les 4 séances PHARES (marquee benchmarks) — mises en avant, où tout le monde se mesure. */
export const FLAGSHIP_WOD_IDS = ["hyrox_sprint", "grace", "benchmark_zero", "ergo_skill"];
/** Épreuves « Autre » : jouables et classées, mais rangées à part de l'écran Séances. */
export const OTHER_WOD_IDS = ["hyrox_solo", "isabel", "murph", "track_10000m", "half_marathon", "marathon"];

/** WODs présents en base (FK des résultats) mais MASQUÉS du catalogue/des séances. `run_free_distance`
 *  reste le mécanisme interne de la course d'onboarding (distance libre + Riegel), pas une séance.
 *  `max_air_squats` (« une série ») : retiré des séances (le 2 min `max_air_squats_2min` reste). */
// Inclut les 5 WODs « Ligue du mois » (cf. LEAGUE_WOD_IDS) : ils ne s'affichent QUE comme « WOD de la
// semaine » via la Ligue, jamais dans le catalogue Séances ni le plan de complétion de l'Index.
export const HIDDEN_WOD_IDS = [
  "run_free_distance",
  "max_air_squats",
  "league_sprint_ladder",
  "league_engine_12",
  "league_grind_squats",
  "league_power_amrap",
  "league_hybrid_chipper",
];
