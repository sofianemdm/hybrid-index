import type { AttributeKey, ScoreType, Sex } from "@hybrid-index/contracts";
import type { DistributionModel } from "@hybrid-index/scoring-core";

/** Tag d'attribut d'un WOD : `estimated` = vrai pour un proxy (ex. pompes → Force). */
export interface WodAttributeTag {
  attribute: AttributeKey;
  estimated: boolean;
}

/** Référence par sexe : distribution + bornes physiologiques (anti-triche §5.5) + cible pro. */
export interface WodSexReference {
  model: DistributionModel;
  /** Bornes plausibles (secondes pour time, reps pour reps). Hors bornes ⇒ refusé. */
  hardMin: number;
  hardMax: number;
  /** Niveau pro/élite affiché au reveal (même unité que le résultat). */
  proReference: number;
}

export interface WodDefinition {
  id: string;
  name: string;
  scoreType: ScoreType;
  requiresEquipment: boolean;
  isBenchmark: boolean;
  /**
   * Tags d'attributs du WOD — AFFICHAGE / RADAR / MAPPING COACH uniquement.
   *
   * INC. 4 (dépréciation pour la prédiction) : `targetAttributes` n'est PLUS la source de la
   * PRÉDICTION de temps des benchmarks. Le moteur « pro » par mouvement (`wod-time-engine.ts`)
   * dérive la capacité de l'athlète des `movement.attributes` PONDÉRÉS du blueprint (la FORCE entre
   * même hors `targetAttributes`) + la pénalité de charge relative. `targetAttributes` ne sert
   * désormais qu'à :
   *  - colorer le radar / lister les attributs travaillés (display) ;
   *  - le mapping attribut→WOD du coach (`wods.service.ts` : recommandation de séances) ;
   *  - le REPLI population de `predictResult` pour les WODs SANS blueprint (course pure, max-reps,
   *    1RM) où aucune décomposition mouvement-par-mouvement n'est possible.
   * NE PAS réintroduire `targetAttributes` comme déterminant principal de la prédiction des
   * benchmarks décomposables (régression de l'ancien bug « force ignorée »).
   */
  targetAttributes: ReadonlyArray<WodAttributeTag>;
  bySex: Record<Sex, WodSexReference>;
}
