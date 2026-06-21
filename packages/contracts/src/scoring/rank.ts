import { INDEX_MAX, INDEX_MIN, RANK_BANDS, type Rank, type RankBand } from "../enums";

/**
 * Renvoie la bande de rang correspondant à une note d'affichage /100 (OVR, display-v1).
 * Bornes [min, max) ; elite inclusif à 100. La valeur est clampée dans [INDEX_MIN, INDEX_MAX] = [40, 100].
 */
export function rankBandFromIndex(index: number): RankBand {
  const v = clampIndex(index);
  for (const band of RANK_BANDS) {
    const isElite = band.rank === "elite";
    if (v >= band.min && (isElite ? v <= band.max : v < band.max)) {
      return band;
    }
  }
  // Inatteignable après clamp, mais on garde un fallback sûr.
  return RANK_BANDS[RANK_BANDS.length - 1];
}

export function rankFromIndex(index: number): Rank {
  return rankBandFromIndex(index).rank;
}

/**
 * Progression vers le rang suivant : { current, next, pointsToNext, progress }.
 * Au dernier rang (elite), next = null et progress = 1.
 */
export function rankProgress(index: number): {
  current: Rank;
  next: Rank | null;
  pointsToNext: number | null;
  progress: number;
} {
  const v = clampIndex(index);
  const band = rankBandFromIndex(v);
  const idx = RANK_BANDS.findIndex((b) => b.rank === band.rank);
  const nextBand = RANK_BANDS[idx + 1] ?? null;
  if (!nextBand) {
    return { current: band.rank, next: null, pointsToNext: null, progress: 1 };
  }
  const span = band.max - band.min;
  const progress = span > 0 ? (v - band.min) / span : 0;
  return {
    current: band.rank,
    next: nextBand.rank,
    pointsToNext: Math.max(0, Math.ceil(nextBand.min - v)),
    progress: Math.min(1, Math.max(0, progress)),
  };
}

export function clampIndex(index: number): number {
  if (Number.isNaN(index)) return INDEX_MIN;
  return Math.min(INDEX_MAX, Math.max(INDEX_MIN, index));
}
