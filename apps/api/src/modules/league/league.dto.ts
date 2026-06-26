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
}

export interface LeagueStandingsView {
  monthKey: string | null;
  sex: string;
  total: number;
  entries: LeagueStandingRow[];
  me: { position: number; points: number } | null;
}

export interface LeagueMeView {
  enrolled: boolean;
  monthKey: string | null;
  points: number;
  position: number | null;
  weeksPlayed: number;
}
