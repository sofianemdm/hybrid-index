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
  targetAttributes: ReadonlyArray<WodAttributeTag>;
  bySex: Record<Sex, WodSexReference>;
}
