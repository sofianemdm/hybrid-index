import type { AttributeKey } from "@hybrid-index/contracts";

/**
 * Agrégation d'un attribut (cf. sport-science §5, décisions D2/D3) :
 *   attribute_score(A) = max( subScore des efforts taguant A, âge ≤ 26 sem )
 * - **No-drop (D3)** : un effort moins bon ne baisse jamais l'attribut (on prend le max). Hors
 *   fenêtre, on CONSERVE la dernière valeur connue (jamais d'effacement) et on marque `isStale`.
 * - **Proxy (D2 généralisé)** : une mesure RÉELLE fait autorité sur une mesure ESTIMÉE ; une
 *   estimation ne peut jamais surclasser une mesure réelle. `isEstimated` = vrai ssi la valeur
 *   retenue provient d'une mesure estimée.
 */

export const FRESHNESS_WEEKS = 26;
/** Seuil « à rafraîchir » (8–12 sem. dans la spec ; on retient 10). */
export const STALE_WEEKS = 10;

/** Un effort noté et ses attributs tagués (estimé ou non, par attribut). */
export interface ScoredEffort {
  subScore: number;
  ageWeeks: number;
  tags: ReadonlyArray<{ attribute: AttributeKey; estimated: boolean }>;
}

export interface AttributeResult {
  attribute: AttributeKey;
  score: number;
  unlocked: boolean;
  isEstimated: boolean;
  isStale: boolean;
  bestAgeWeeks: number | null;
}

interface Contribution {
  subScore: number;
  ageWeeks: number;
  estimated: boolean;
}

export function attributeScore(
  attribute: AttributeKey,
  efforts: ReadonlyArray<ScoredEffort>,
): AttributeResult {
  const contributions: Contribution[] = [];
  for (const e of efforts) {
    const tag = e.tags.find((t) => t.attribute === attribute);
    if (tag) {
      contributions.push({ subScore: e.subScore, ageWeeks: e.ageWeeks, estimated: tag.estimated });
    }
  }

  if (contributions.length === 0) {
    return { attribute, score: 0, unlocked: false, isEstimated: false, isStale: false, bestAgeWeeks: null };
  }

  // D2 (décision D9) : une mesure RÉELLE fait autorité MÊME si elle est périmée — une estimation
  // (proxy) ne peut jamais la surclasser. On ne retombe sur les estimées que s'il n'existe AUCUNE
  // mesure réelle. D3 : à l'intérieur du pool retenu, on prend le max (no-drop) et, hors fenêtre,
  // on conserve la dernière valeur connue (jamais d'effacement).
  const real = contributions.filter((c) => !c.estimated);
  const isEstimated = real.length === 0;
  const pool = isEstimated ? contributions : real;

  const inWindow = pool.filter((c) => c.ageWeeks <= FRESHNESS_WEEKS);
  const chosen = inWindow.length > 0 ? inWindow : pool;
  const best = chosen.reduce((a, b) => (b.subScore > a.subScore ? b : a));

  return {
    attribute,
    score: best.subScore,
    unlocked: true,
    isEstimated,
    isStale: inWindow.length === 0 || best.ageWeeks >= STALE_WEEKS,
    bestAgeWeeks: best.ageWeeks,
  };
}

/** Calcule les 6 attributs du radar à partir d'une liste d'efforts. */
export function computeRadar(
  attributes: ReadonlyArray<AttributeKey>,
  efforts: ReadonlyArray<ScoredEffort>,
): AttributeResult[] {
  return attributes.map((a) => attributeScore(a, efforts));
}
