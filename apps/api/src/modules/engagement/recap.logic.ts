/**
 * Gain d'Index AFFICHÉ de la semaine = Index courant − Index de référence du début de semaine,
 * planché à 0. Le no-drop garantit que l'Index affiché ne baisse jamais ⇒ le delta est toujours
 * ≥ 0 ; le plancher protège juste les cas limites (pas d'historique antérieur). Pur et testé.
 */
export function weeklyRecapDelta(indexNowOvr: number | null, indexStartOvr: number | null): number {
  return Math.max(0, (indexNowOvr ?? 0) - (indexStartOvr ?? 0));
}
