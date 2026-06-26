import { ATTRIBUTE_KEYS, type AttributeKey } from "@hybrid-index/contracts";

/**
 * Bibliothèque de séances ciblées (source sport-science, 20 juin). 54 séances ciblées (9 par
 * attribut en primaire) équilibrées avec/sans matériel (l'app doit fonctionner 100 % sans matériel),
 * + 1 séance SIGNATURE hebdomadaire « Le Forgeron » (sport-science, 26 juin) destinée à devenir
 * « la séance de la semaine » (intensive, 100 % sans matériel, ~15 min). Soit 55 séances.
 */
export interface Session {
  id: string;
  name: string;
  primaryAttribute: AttributeKey;
  secondaryAttributes: AttributeKey[];
  requiresEquipment: boolean;
  durationMin: number;
  intensity: "low" | "medium" | "high";
  description: string;
}

export const SESSIONS: Session[] = [
  // ───── SÉANCE DE LA SEMAINE (signature, sans matériel, ~15 min) ─────
  // « Le Forgeron » : remplace l'ancien Profil Express comme séance hebdo mise en avant. Hybride
  // intensive 100 % poids du corps. Primaire = hybrid ; touche aussi engine / endurance musc. /
  // power / vitesse. NON scalable (aucune charge). Se note `time` (chrono), via le moteur d'estimation.
  { id: "weekly-forgeron", name: "Le Forgeron", primaryAttribute: "hybrid", secondaryAttributes: ["engine", "muscular_endurance", "power"], requiresEquipment: false, durationMin: 15, intensity: "high", description: "LA séance de la semaine, 100 % sans matériel, pour le temps (cap 15 min). 3 TOURS à enchaîner : 200 m course (ou 40 jumping jacks sur place), 15 burpees, 25 air squats, 20 mountain climbers (10/jambe), 15 sit-ups. Découpe en petites séries, garde une cadence régulière sur les burpees, ne pars pas trop vite. Score = temps total (ou reps si tu atteins le cap). Tout le corps, moteur à fond." },
  // ENGINE
  { id: "engine-zone2-run-40", name: "Sortie Zone 2 — 40 min", primaryAttribute: "engine", secondaryAttributes: ["speed"], requiresEquipment: false, durationMin: 40, intensity: "low", description: "Course continue à allure facile (tu peux parler), 40 min sans arrêt. Fréquence cardiaque basse et stable. Construit le moteur aérobie de base." },
  { id: "engine-run-5x800", name: "Intervalles 5×800 m", primaryAttribute: "engine", secondaryAttributes: ["speed"], requiresEquipment: false, durationMin: 35, intensity: "high", description: "Après échauffement, 5×800 m à allure 5 km, 2 min de marche/trot entre chaque. Développe seuil et VMA. Reste régulier sur les temps." },
  { id: "engine-row-30min", name: "Rameur continu 30 min", primaryAttribute: "engine", secondaryAttributes: ["hybrid"], requiresEquipment: true, durationMin: 30, intensity: "medium", description: "30 min de rameur à allure régulière, cadence 22-24 c/min, ~70-75 % d'effort. Vise une distance stable. Moteur sans impact articulaire." },
  { id: "engine-bike-erg-intervals", name: "BikeErg 8×2 min", primaryAttribute: "engine", secondaryAttributes: ["power"], requiresEquipment: true, durationMin: 32, intensity: "high", description: "8×2 min sur vélo à effort dur soutenu, 90 s de récup active. Pousse le seuil aérobie. Puissance constante par bloc." },
  { id: "engine-burpee-emom-20", name: "EMOM 20 min — Burpees", primaryAttribute: "engine", secondaryAttributes: ["muscular_endurance", "hybrid"], requiresEquipment: false, durationMin: 20, intensity: "high", description: "EMOM 20 min : 8-10 burpees au début de chaque minute, repos sur le temps restant. Cardio et résistance combinés." },
  { id: "engine-shuttle-run-pyramide", name: "Pyramide de navettes", primaryAttribute: "engine", secondaryAttributes: ["speed"], requiresEquipment: false, durationMin: 25, intensity: "high", description: "Navettes 20 m : 200/400/600/400/200 m cumulés, 60-90 s de repos entre paliers. Moteur avec changements de direction, façon HYROX." },
  { id: "engine-stairs-30", name: "Montée d'escaliers 30 min", primaryAttribute: "engine", secondaryAttributes: ["muscular_endurance"], requiresEquipment: false, durationMin: 30, intensity: "medium", description: "30 min de montée d'escaliers à rythme soutenu, descente en récup marchée. Cardio + endurance des jambes." },
  { id: "engine-running-tempo-25", name: "Tempo run 25 min", primaryAttribute: "engine", secondaryAttributes: ["speed"], requiresEquipment: false, durationMin: 35, intensity: "medium", description: "Échauffe 10 min puis 25 min à allure « confortablement difficile » (10 km). Améliore le seuil lactique." },
  { id: "engine-ski-erg-5x500", name: "SkiErg 5×500 m", primaryAttribute: "engine", secondaryAttributes: ["muscular_endurance", "hybrid"], requiresEquipment: true, durationMin: 28, intensity: "high", description: "5×500 m sur SkiErg à allure dure régulière, 2 min de repos. Engage le haut du corps et le cardio. Même split par rép." },
  // SPEED
  { id: "speed-sprints-10x100", name: "10×100 m sprint", primaryAttribute: "speed", secondaryAttributes: ["power"], requiresEquipment: false, durationMin: 30, intensity: "high", description: "Après échauffement complet, 10×100 m à ~90-95 % avec retour marché (récup ~90 s). Vitesse pure. Stoppe si la technique se dégrade." },
  { id: "speed-flying-30s", name: "Sprints lancés 30 m", primaryAttribute: "speed", secondaryAttributes: ["power"], requiresEquipment: false, durationMin: 25, intensity: "high", description: "8×30 m lancés (20 m de mise en vitesse), récup complète 2 min. Vélocité maximale. Qualité avant quantité." },
  { id: "speed-hill-sprints", name: "Sprints en côte 8×", primaryAttribute: "speed", secondaryAttributes: ["power", "strength"], requiresEquipment: false, durationMin: 28, intensity: "high", description: "8 sprints de 15-20 s en côte modérée à fond, descente marchée (2 min). Vitesse + puissance des jambes, moins de risque qu'à plat." },
  { id: "speed-ladder-agility", name: "Échelle d'agilité & pieds vifs", primaryAttribute: "speed", secondaryAttributes: ["hybrid"], requiresEquipment: false, durationMin: 20, intensity: "medium", description: "Motricité au sol : pas chassés, appuis rapides, sauts latéraux, 6 ateliers 20 s/40 s, 3 tours. Fréquence d'appui et coordination." },
  { id: "speed-row-sprints-250", name: "Rameur 8×250 m", primaryAttribute: "speed", secondaryAttributes: ["power", "engine"], requiresEquipment: true, durationMin: 25, intensity: "high", description: "8×250 m sur rameur quasi maximal, 90 s de repos complet. Puissance-vitesse en aérobie courte. Vise le split le plus bas et tiens-le." },
  { id: "speed-tabata-highknees", name: "Tabata montées de genoux", primaryAttribute: "speed", secondaryAttributes: ["engine"], requiresEquipment: false, durationMin: 14, intensity: "high", description: "Tabata 8×(20/10) de montées de genoux explosives, 2 min de repos, second bloc. Cadence maximale. Vitesse de jambes." },
  { id: "speed-bike-sprints", name: "Sprints vélo 10×15 s", primaryAttribute: "speed", secondaryAttributes: ["power"], requiresEquipment: true, durationMin: 24, intensity: "high", description: "10 sprints de 15 s sur vélo/Assault Bike à fond, 75 s de récup facile. Vélocité et puissance anaérobie sans impact." },
  { id: "speed-shuttle-5-10-5", name: "Test agilité 5-10-5", primaryAttribute: "speed", secondaryAttributes: ["power", "hybrid"], requiresEquipment: false, durationMin: 22, intensity: "high", description: "Drill 5-10-5 (pro-agility), 8 répétitions, récup complète. Accélération et changement de direction." },
  { id: "speed-jump-rope-speed", name: "Corde à sauter vitesse", primaryAttribute: "speed", secondaryAttributes: ["engine", "muscular_endurance"], requiresEquipment: true, durationMin: 18, intensity: "medium", description: "10 rounds 30 s de corde le plus vite possible (ou double-unders) / 30 s repos. Vitesse d'appui, coordination. Reste léger sur les chevilles." },
  // STRENGTH
  { id: "strength-back-squat-5x5", name: "Back Squat 5×5", primaryAttribute: "strength", secondaryAttributes: ["power"], requiresEquipment: true, durationMin: 22, intensity: "high", description: "5×5 back squat lourd (~80 %), 3 min de repos. Dos gainé, profondeur constante. Base de la force des jambes." },
  { id: "strength-deadlift-5x3", name: "Soulevé de terre 5×3", primaryAttribute: "strength", secondaryAttributes: ["power"], requiresEquipment: true, durationMin: 22, intensity: "high", description: "5×3 soulevé de terre lourd (~85 %), 3 min de repos. Pose la barre à chaque rep, dos neutre. Force de la chaîne postérieure." },
  { id: "strength-press-5x5", name: "Développé militaire 5×5", primaryAttribute: "strength", secondaryAttributes: ["muscular_endurance"], requiresEquipment: true, durationMin: 20, intensity: "high", description: "5×5 développé militaire debout exigeant, 2-3 min de repos. Gaine abdos/fessiers, pas de cambrure excessive." },
  { id: "strength-bench-5x5", name: "Développé couché 5×5", primaryAttribute: "strength", secondaryAttributes: ["power"], requiresEquipment: true, durationMin: 22, intensity: "high", description: "5×5 développé couché (~80 %), 3 min de repos. Descente contrôlée, omoplates serrées. Poussée horizontale." },
  { id: "strength-pistol-progression", name: "Progression pistol squat", primaryAttribute: "strength", secondaryAttributes: ["power", "hybrid"], requiresEquipment: false, durationMin: 18, intensity: "medium", description: "Squat sur une jambe en assistance (appui ou boîte) : 5×5 par jambe, 2 min de repos. Force unilatérale. Descends en contrôle total." },
  { id: "strength-pushup-progression", name: "Pompes lestées / déclinées", primaryAttribute: "strength", secondaryAttributes: ["muscular_endurance"], requiresEquipment: false, durationMin: 18, intensity: "medium", description: "Pompes difficiles (pieds surélevés, tempo lent, archer) : 6×5-8 près de l'échec, 2 min de repos. Poussée au poids du corps. Corps gainé." },
  { id: "strength-pullup-weighted", name: "Tractions lestées 6×4", primaryAttribute: "strength", secondaryAttributes: ["power"], requiresEquipment: true, durationMin: 22, intensity: "high", description: "6×4 tractions strictes (lestées si possible), 2-3 min de repos. Amplitude complète. Tirage vertical. Régresse en assistées si besoin." },
  { id: "strength-bulgarian-split", name: "Fentes bulgares lourdes", primaryAttribute: "strength", secondaryAttributes: ["muscular_endurance", "hybrid"], requiresEquipment: true, durationMin: 18, intensity: "medium", description: "Fentes bulgares avec haltères : 4×6 par jambe, 2 min de repos. Force unilatérale et stabilité. Genou avant aligné, buste droit." },
  { id: "strength-isometric-wall-core", name: "Isométrie force — gainage", primaryAttribute: "strength", secondaryAttributes: ["muscular_endurance"], requiresEquipment: false, durationMin: 20, intensity: "medium", description: "Chaise contre mur, planche, hollow hold : 5 tours de 30-45 s par position, 60 s de repos. Gainage et tonicité. Respire calmement." },
  // POWER
  { id: "power-box-jumps-5x5", name: "Box jumps 6×5", primaryAttribute: "power", secondaryAttributes: ["speed"], requiresEquipment: true, durationMin: 28, intensity: "high", description: "6×5 sauts sur boîte hauts et explosifs, descente contrôlée (step-down), 90 s de repos. Puissance des jambes. Repos complet pour rester explosif." },
  { id: "power-broad-jumps", name: "Sauts en longueur 6×4", primaryAttribute: "power", secondaryAttributes: ["speed"], requiresEquipment: false, durationMin: 25, intensity: "high", description: "6×4 sauts en longueur depuis l'arrêt, réception amortie, 90 s de repos. Puissance horizontale. Réception genoux fléchis." },
  { id: "power-kb-swings-emom", name: "EMOM kettlebell swings", primaryAttribute: "power", secondaryAttributes: ["engine", "hybrid"], requiresEquipment: true, durationMin: 20, intensity: "high", description: "EMOM 16 min : 15 swings explosifs/min. La hanche propulse, bras relâchés. Puissance de hanche et cardio. Adapte le poids." },
  { id: "power-clean-pull-5x3", name: "Power clean 5×3", primaryAttribute: "power", secondaryAttributes: ["strength", "speed"], requiresEquipment: true, durationMin: 22, intensity: "high", description: "5×3 power cleans modérés-lourds, technique nette, 2-3 min de repos. Triple extension explosive. Vitesse de barre. Stoppe si la technique casse." },
  { id: "power-medball-throws", name: "Lancers de med-ball", primaryAttribute: "power", secondaryAttributes: ["hybrid"], requiresEquipment: true, durationMin: 24, intensity: "high", description: "Lancers explosifs (overhead, rotation, slams) : 6 ateliers de 6 lancers, 90 s de repos. Puissance full-body. Engage hanche et tronc." },
  { id: "power-plyo-squat-jumps", name: "Squat jumps pliométriques", primaryAttribute: "power", secondaryAttributes: ["speed", "muscular_endurance"], requiresEquipment: false, durationMin: 22, intensity: "high", description: "6×6 squat jumps explosifs, réception amortie, 90 s de repos. Puissance des jambes au poids du corps. Repos pour garder la hauteur." },
  { id: "power-thruster-emom", name: "EMOM thrusters", primaryAttribute: "power", secondaryAttributes: ["muscular_endurance", "hybrid"], requiresEquipment: true, durationMin: 18, intensity: "high", description: "EMOM 14 min : 8 thrusters (squat + développé) légers/min. Mouvement fluide et explosif. Puissance + résistance. Charge légère, exécution rapide." },
  { id: "power-burpee-broad-jump", name: "Burpee broad jumps", primaryAttribute: "power", secondaryAttributes: ["engine", "hybrid"], requiresEquipment: false, durationMin: 20, intensity: "high", description: "5 rounds : 8 burpees + 5 sauts en longueur explosifs, 75 s de repos. Puissance et cardio mêlés, style HYROX. Réception amortie." },
  { id: "power-tuck-jumps", name: "Tuck jumps & sauts groupés", primaryAttribute: "power", secondaryAttributes: ["speed"], requiresEquipment: false, durationMin: 18, intensity: "high", description: "5×5 tuck jumps (genoux à la poitrine) à fond, réception douce, 90 s de repos. Explosivité verticale. Qualité d'impulsion." },
  // MUSCULAR_ENDURANCE
  { id: "musend-pushups-amrap", name: "AMRAP pompes — 10 min", primaryAttribute: "muscular_endurance", secondaryAttributes: ["strength"], requiresEquipment: false, durationMin: 12, intensity: "medium", description: "AMRAP 10 min : 10 pompes + 10 air squats en boucle, rythme régulier. Ne pars pas trop vite. Endurance haut du corps et jambes." },
  { id: "musend-bodyweight-circuit", name: "Circuit poids du corps 4 tours", primaryAttribute: "muscular_endurance", secondaryAttributes: ["engine", "hybrid"], requiresEquipment: false, durationMin: 30, intensity: "medium", description: "4 tours : 20 air squats, 15 pompes, 20 fentes, 30 s de gainage, 60 s de repos. Résistance générale. Exécution propre jusqu'au bout." },
  { id: "musend-situps-emom", name: "EMOM abdos 15 min", primaryAttribute: "muscular_endurance", secondaryAttributes: ["hybrid"], requiresEquipment: false, durationMin: 15, intensity: "medium", description: "EMOM 15 min : min A 20 sit-ups, min B 30 s de planche. Endurance du tronc. Mouvement contrôlé, pas d'à-coups sur la nuque." },
  { id: "musend-walking-lunges", name: "Fentes marchées longue distance", primaryAttribute: "muscular_endurance", secondaryAttributes: ["strength"], requiresEquipment: false, durationMin: 22, intensity: "medium", description: "5×20 fentes marchées (10/jambe), 60-75 s de repos. Brûlure contrôlée cuisses/fessiers. Genou arrière qui frôle le sol. (HYROX lunges)." },
  { id: "musend-wallballs-amrap", name: "AMRAP wall balls", primaryAttribute: "muscular_endurance", secondaryAttributes: ["power", "engine"], requiresEquipment: true, durationMin: 16, intensity: "high", description: "AMRAP 12 min de wall balls à rythme soutenu. Endurance jambes + épaules, mouvement signature HYROX. Séries de 10-15 sans poser." },
  { id: "musend-row-intervals-long", name: "Rameur 6×500 m endurance", primaryAttribute: "muscular_endurance", secondaryAttributes: ["engine", "hybrid"], requiresEquipment: true, durationMin: 30, intensity: "medium", description: "6×500 m soutenu mais tenable, 60 s de repos seulement. Repos court pour cibler la résistance. Dos gainé, tirage complet." },
  { id: "musend-kb-complex", name: "Complexe kettlebell", primaryAttribute: "muscular_endurance", secondaryAttributes: ["strength", "hybrid"], requiresEquipment: true, durationMin: 28, intensity: "medium", description: "4 tours sans poser : 8 swings, 6 goblet squats, 6 presses/bras, 90 s de repos. Endurance full-body. Charge modérée, technique propre." },
  { id: "musend-plank-complex", name: "Circuit gainage dynamique", primaryAttribute: "muscular_endurance", secondaryAttributes: ["hybrid"], requiresEquipment: false, durationMin: 18, intensity: "low", description: "4 tours : planche 40 s, latérale 30 s/côté, mountain climbers 30 s, superman 30 s, 45 s de repos. Endurance du tronc. Respiration régulière." },
  { id: "musend-step-ups-loaded", name: "Step-ups chargés", primaryAttribute: "muscular_endurance", secondaryAttributes: ["strength", "engine"], requiresEquipment: true, durationMin: 26, intensity: "medium", description: "5×20 step-ups sur boîte avec haltères/sac (10/jambe), 75 s de repos. Endurance des jambes sous charge (proche du sandbag lunge HYROX)." },
  // HYBRID
  { id: "hybrid-hyrox-sim-half", name: "Simulation demi-HYROX", primaryAttribute: "hybrid", secondaryAttributes: ["engine", "muscular_endurance"], requiresEquipment: true, durationMin: 45, intensity: "high", description: "4 tours : 500 m course + 1 station (rameur, wall balls, traîneau ou fentes), en continu. Format HYROX run+station. Allure gérée pour 4 tours." },
  { id: "hybrid-run-row-couplet", name: "Couplet course / rameur", primaryAttribute: "hybrid", secondaryAttributes: ["engine", "speed"], requiresEquipment: true, durationMin: 32, intensity: "high", description: "4 rounds : 800 m course puis 1000 m rameur, transition rapide, 90 s de repos. Passage cardio→cardio façon HYROX. Rythme soutenable." },
  { id: "hybrid-bodyweight-metcon", name: "Metcon poids du corps « Cindy-like »", primaryAttribute: "hybrid", secondaryAttributes: ["muscular_endurance", "engine"], requiresEquipment: false, durationMin: 20, intensity: "high", description: "AMRAP 20 min : 5 tractions (ou rows australiennes), 10 pompes, 15 air squats. Métcon hybride 100 % poids du corps. Fractionne tôt." },
  { id: "hybrid-run-burpee-ladder", name: "Course + burpees en échelle", primaryAttribute: "hybrid", secondaryAttributes: ["engine", "power"], requiresEquipment: false, durationMin: 25, intensity: "high", description: "5 rounds : 400 m course + 12-10-8-6-4 burpees (décroissant). Cardio + résistance, sans matériel. Allure tenue, technique des burpees." },
  { id: "hybrid-dt-style", name: "Complexe haltères « DT-like »", primaryAttribute: "hybrid", secondaryAttributes: ["strength", "power"], requiresEquipment: true, durationMin: 28, intensity: "high", description: "5 tours : 12 soulevés de terre, 9 hang power cleans, 6 push press (haltères/barre légère), 2 min de repos. Force-endurance hybride. Charge modérée." },
  { id: "hybrid-sled-run-intervals", name: "Traîneau + course intervalles", primaryAttribute: "hybrid", secondaryAttributes: ["strength", "engine"], requiresEquipment: true, durationMin: 30, intensity: "high", description: "6 rounds : 25 m poussée traîneau + 25 m traction, puis 200 m course, 90 s de repos. Sled push/pull HYROX. Pousse bas, jambes motrices, dos gainé." },
  { id: "hybrid-emom-mixed-30", name: "EMOM mixte 30 min", primaryAttribute: "hybrid", secondaryAttributes: ["engine", "muscular_endurance", "power"], requiresEquipment: true, durationMin: 30, intensity: "medium", description: "EMOM 30 min en rotation : min 1 rameur 15 cal, min 2 swings ×15, min 3 burpees ×10. Hybride continu contrôlé. ~10 s de repos/min." },
  { id: "hybrid-chipper-bodyweight", name: "Chipper poids du corps", primaryAttribute: "hybrid", secondaryAttributes: ["muscular_endurance", "engine"], requiresEquipment: false, durationMin: 24, intensity: "high", description: "Pour temps : 50 air squats, 40 mountain climbers, 30 pompes, 20 burpees, 10 tuck jumps. Chipper sans matériel. Découpe en petites séries." },
  { id: "hybrid-tabata-fullbody", name: "Tabata full-body 4 blocs", primaryAttribute: "hybrid", secondaryAttributes: ["engine", "power", "muscular_endurance"], requiresEquipment: false, durationMin: 20, intensity: "high", description: "4 blocs Tabata (8×20/10) : burpees, jumping lunges, mountain climbers, squat jumps, 1 min entre blocs. Cardio-résistance intense. Volume constant." },
];

// ─────────────────────────────────────────────────────────────────────────────
// Poids par attribut (barème reproductible, cf. docs/seances-attributs-spec.md §3)
// ─────────────────────────────────────────────────────────────────────────────

/** Barème de dérivation des poids depuis les tags (spec §3). */
const ATTRIBUTE_FLOOR = 0.1; // plancher : aucun attribut n'est jamais à zéro
const PRIMARY_WEIGHT = 1.0;
const SECONDARY_WEIGHTS = [0.6, 0.45, 0.35] as const; // [0]→0.60, [1]→0.45, [2]→0.35 (au-delà : ignoré)

/** Seuil d'affichage : on ne liste que primaire + secondaires (≥ 0.35), le plancher 0.10 reste exclu. */
export const ATTRIBUTE_LIST_THRESHOLD = SECONDARY_WEIGHTS[SECONDARY_WEIGHTS.length - 1]; // 0.35

/**
 * Poids calibrés à la main pour la séance signature (spec §3, exception au barème automatique).
 * `weekly-forgeron` n'utilise PAS la dérivation depuis ses tags.
 */
const FORGERON_WEIGHTS: Record<AttributeKey, number> = {
  hybrid: 1.0,
  engine: 0.9,
  muscular_endurance: 0.8,
  power: 0.4,
  speed: 0.3,
  strength: 0.15,
};

/**
 * Poids de chaque attribut (les 6 clés) pour une séance, dérivés de ses tags (spec §3) :
 * primaire = 1.00 ; secondaires = 0.60 / 0.45 / 0.35 (dans l'ordre, au-delà ignoré) ;
 * tout autre attribut = 0.10 (plancher). EXCEPTION `weekly-forgeron` : poids calibrés main.
 */
export function attributeWeights(session: Session): Record<AttributeKey, number> {
  if (session.id === "weekly-forgeron") {
    return { ...FORGERON_WEIGHTS };
  }
  const weights = {} as Record<AttributeKey, number>;
  for (const key of ATTRIBUTE_KEYS) {
    weights[key] = ATTRIBUTE_FLOOR;
  }
  weights[session.primaryAttribute] = PRIMARY_WEIGHT;
  session.secondaryAttributes.slice(0, SECONDARY_WEIGHTS.length).forEach((attr, i) => {
    weights[attr] = SECONDARY_WEIGHTS[i];
  });
  return weights;
}

/** Ordre d'intensité pour le départage (high > medium > low). */
const INTENSITY_RANK: Record<Session["intensity"], number> = { high: 3, medium: 2, low: 1 };

/**
 * Séances qui touchent `attribute` (poids ≥ 0.35 : primaire + secondaires ; le plancher 0.10 est
 * exclu de la liste, cf. spec §2 variante recommandée), chacune annotée de son `weight` pour cet
 * attribut. Si `noGear`, exclut les séances nécessitant du matériel. Tri déterministe (spec §2.3) :
 * weight desc → intensité desc (high>medium>low) → durationMin asc → name alpha.
 */
export function sessionsForAttribute(
  attribute: AttributeKey,
  noGear: boolean,
): Array<Session & { weight: number }> {
  return SESSIONS.map((s) => ({ ...s, weight: attributeWeights(s)[attribute] }))
    .filter((s) => s.weight >= ATTRIBUTE_LIST_THRESHOLD)
    .filter((s) => !noGear || !s.requiresEquipment)
    .sort(
      (a, b) =>
        b.weight - a.weight ||
        INTENSITY_RANK[b.intensity] - INTENSITY_RANK[a.intensity] ||
        a.durationMin - b.durationMin ||
        a.name.localeCompare(b.name),
    );
}

/** Séance signature « de la semaine » (cf. seance-de-la-semaine.md). Peut être undefined. */
export function weeklySession(): Session | undefined {
  return SESSIONS.find((s) => s.id === "weekly-forgeron");
}
