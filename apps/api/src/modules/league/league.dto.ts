// Formes de réponse de l'API Ligue (lecture seule sauf enroll). Zod/contracts partagés à ajouter
// plus tard ; au lancement, types internes suffisants pour typer le contrôleur.
import type { AvatarView } from "../../common/avatar.serializer";

export interface LeagueWeekView {
  weekIndex: number;
  weekKey: string;
  wodId: string;
  wodName: string;
  opensAt: string;
  closesAt: string;
}

export interface LeagueSeasonView {
  monthKey: string;
  status: string;
  divisionTier: number;
  opensAt: string;
  closesAt: string;
  currentWeek: LeagueWeekView | null;
  enrolled: boolean;
}

export interface EnrollResponse {
  seasonId: string;
  enrolled: boolean;
  sex: string;
}

export interface LeagueStandingRow {
  position: number;
  userId: string;
  displayName: string;
  points: number;
  isMe: boolean;
  avatar: AvatarView | null; // mini-vignette (mobile) ; null si l'athlète n'a pas d'avatar
  clubName: string | null; // club « principal » affiché à droite du nom ; null si sans club
}

export interface LeagueStandingsView {
  monthKey: string | null;
  sex: string;
  total: number;
  entries: LeagueStandingRow[];
  me: { position: number; points: number; clubName: string | null } | null;
}

export interface LeagueMeView {
  enrolled: boolean;
  monthKey: string | null;
  points: number;
  position: number | null;
  weeksPlayed: number;
  clubName: string | null; // club « principal » du viewer, affiché sur sa carte « ma position »
}

/** Une ligne du podium (top 3) d'une saison CLOSE, pour le reveal de fin de saison. */
export interface LeaguePodiumRow {
  finalRank: number; // 1 | 2 | 3
  userId: string;
  displayName: string;
  totalPoints: number;
  avatar: AvatarView | null; // mini-vignette (mobile) ; null si pas d'avatar
}

/** Ligne du viewer dans la saison close (s'il a participé). */
export interface LeagueLastResultMe {
  finalRank: number;
  totalPoints: number;
  movement: string | null; // "promoted" | "relegated" | "stay" | null (tier=1)
}

/**
 * Résultat de la DERNIÈRE saison close, pour le « reveal » de fin de saison côté mobile.
 * `monthKey` = mois de la saison ; `podium` = top 3 du SEXE du viewer ; `me` = sa ligne (ou null).
 * Le contrôleur renvoie `null` (pas d'objet) s'il n'existe aucune saison close.
 */
export interface LeagueLastResultView {
  monthKey: string;
  sex: string;
  podium: LeaguePodiumRow[];
  me: LeagueLastResultMe | null;
}
