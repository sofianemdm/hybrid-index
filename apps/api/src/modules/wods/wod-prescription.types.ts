/**
 * Prescription concrète d'une séance de référence : « ce que c'est » et « ce que tu dois faire »,
 * avec poids RX (standard) et version plus légère par sexe. Profondeur « Essentiel ».
 * Source d'autorité : agent sport-science. Contenu fixe (pas de migration DB).
 */

export type WeightUnit = "kg";

/** Charge d'un mouvement chargé : RX (standard) + version allégée (type L1), par sexe. */
export interface WodWeight {
  /** Mouvement concerné (ex. « Thruster », « Épaulé-jeté »). */
  movement: string;
  /** Poids RX (standard) homme / femme. */
  rxMale: number;
  rxFemale: number;
  /** Poids allégé (plus accessible, type L1) homme / femme. */
  scaledMale: number;
  scaledFemale: number;
  unit: WeightUnit;
  /** Précision optionnelle (ex. « barre », « kettlebell », « par main »). */
  note?: string;
}

/** Une ligne de l'énoncé : un mouvement avec son schéma de reps/distance. */
export interface WodBlock {
  /** Reps ou distance pour cette ligne (ex. « 21-15-9 », « 30 », « 400 m », « 50 cal »). */
  reps: string;
  /** Nom du mouvement (ex. « Thrusters », « Tractions », « Course »). */
  movement: string;
  /** Détail optionnel inline (ex. « hauteur cible 3 m », « strictes »). */
  detail?: string;
}

export interface WodPrescription {
  /** 1–2 phrases : ce qu'est la séance et l'objectif. */
  summary: string;
  /** Format en clair (ex. « 21-15-9, pour le temps », « AMRAP 12 min », « 5 tours pour le temps »). */
  format: string;
  /** Plafond de temps en secondes, si applicable. */
  timeCapSec?: number;
  /** Liste ordonnée des mouvements de la séance. */
  blocks: WodBlock[];
  /** Charges (vide si séance au poids du corps / course). */
  weights: WodWeight[];
  /** Ce que l'utilisateur enregistre (ex. « Tu enregistres ton temps total. »). */
  scoringNote: string;
}
