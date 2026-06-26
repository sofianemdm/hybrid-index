import type { Avatar } from "@prisma/client";

/**
 * Forme JSON publique de l'avatar d'un utilisateur — SOURCE UNIQUE.
 *
 * Réutilisée à l'identique par le profil public (`GET /v1/profiles/:id`), `GET /v1/me/avatar`,
 * et désormais chaque ligne de classement (leaderboard + Ligue). Le mobile décode toujours le même
 * objet. `diceOptions` est stocké en base comme chaîne JSON et exposé ici comme objet décodé.
 */
export interface AvatarView {
  skinTone: number;
  hairStyle: number;
  hairColor: number;
  beardStyle: number | null;
  accessory: number;
  background: number;
  /** Photo de profil (data URL base64) ou null. */
  photoData: string | null;
  /** Avatar DiceBear : style (ex. "adventurer") ou null. */
  diceStyle: string | null;
  /** Avatar DiceBear : seed (détermine le visage) ou null. */
  diceSeed: string | null;
  /** Options DiceBear décodées (peau, coupe, barbe…) ou null. */
  diceOptions: Record<string, string> | null;
}

/** Mappe un enregistrement Prisma `Avatar` (ou son absence) vers la forme JSON publique. */
export function serializeAvatar(avatar: Avatar | null | undefined): AvatarView | null {
  if (!avatar) return null;
  return {
    skinTone: avatar.skinTone,
    hairStyle: avatar.hairStyle,
    hairColor: avatar.hairColor,
    beardStyle: avatar.beardStyle,
    accessory: avatar.accessory,
    background: avatar.background,
    photoData: avatar.photoData,
    diceStyle: avatar.diceStyle,
    diceSeed: avatar.diceSeed,
    diceOptions: avatar.diceOptions ? (JSON.parse(avatar.diceOptions) as Record<string, string>) : null,
  };
}

/**
 * Construit une map `userId -> AvatarView` à partir d'une SEULE requête batch
 * (`prisma.avatar.findMany({ where: { userId: { in: [...] } } })`). Évite tout N+1 sur les listes
 * (classement). Les utilisateurs sans avatar sont simplement absents de la map → repli `null`.
 */
export function avatarMapByUserId(avatars: Avatar[]): Map<string, AvatarView> {
  const map = new Map<string, AvatarView>();
  for (const a of avatars) {
    const view = serializeAvatar(a);
    if (view) map.set(a.userId, view);
  }
  return map;
}
