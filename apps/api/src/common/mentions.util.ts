/**
 * LOT 5 — Mentions @pseudo dans les posts et commentaires.
 *
 * Parsing volontairement simple et robuste : on capture les tokens `@pseudo` où `pseudo` est une
 * suite de caractères de « nom » (lettres Unicode, chiffres, `_`, `.`, `-`) immédiatement après un
 * `@` qui n'est pas collé à un autre caractère de nom (évite de matcher une adresse e-mail comme
 * `a@b`). La résolution pseudo→userId se fait à la volée contre `Profile.displayName`, insensible à
 * la casse ET aux accents. PAS de table Mention (résolution à la volée, suffisante et sans dette).
 *
 * Limite assumée : les pseudos contenant une espace (displayName autorise 2..24 caractères quelconques)
 * ne sont pas capturés par `@…` — convention universelle des @mentions. Documenté côté contrat mobile.
 */

/** Une occurrence brute `@pseudo` repérée dans le texte (avant résolution). */
export interface RawMention {
  /** Pseudo tel qu'écrit (sans le `@`). */
  raw: string;
  /** Offset du `@` dans le texte source (UTF-16) — pour rendre le `@` cliquable côté client. */
  offset: number;
  /** Longueur du token complet `@pseudo` (inclut le `@`). */
  length: number;
}

/** Mention résolue : le pseudo a été relié à un utilisateur réel. */
export interface ResolvedMention {
  /** displayName canonique (tel qu'en base), pour l'affichage cliquable. */
  pseudo: string;
  userId: string;
  /** Offset du `@` dans le texte source. */
  offset: number;
  /** Longueur du token `@pseudo` tel qu'écrit (peut différer de `pseudo` si casse/accents). */
  length: number;
}

// `@` non précédé d'un caractère de nom (anti-email) suivi d'1..24 caractères de nom.
// `u` flag : \p{L}/\p{N} couvrent les lettres/chiffres Unicode (accents inclus).
const MENTION_REGEX = /(?<![\p{L}\p{N}_])@([\p{L}\p{N}_.-]{1,24})/gu;

/** Normalise pour matcher un pseudo : minuscules + suppression des accents/diacritiques. */
function normalize(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

/**
 * Repère toutes les occurrences `@pseudo` du texte (dé-doublonnées par pseudo normalisé : on garde
 * la PREMIÈRE occurrence de chaque pseudo distinct, pour ne notifier qu'une fois). Retourne [] si
 * le texte est vide.
 */
export function parseMentions(text: string | null | undefined): RawMention[] {
  if (!text) return [];
  const seen = new Set<string>();
  const out: RawMention[] = [];
  for (const m of text.matchAll(MENTION_REGEX)) {
    const raw = m[1];
    const key = normalize(raw);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ raw, offset: m.index ?? 0, length: raw.length + 1 });
  }
  return out;
}

/** Index normalisé displayName→userId à partir des profils chargés (résolution insensible casse/accents). */
export function buildDisplayNameIndex(
  profiles: Array<{ userId: string; displayName: string }>,
): Map<string, { userId: string; displayName: string }> {
  const idx = new Map<string, { userId: string; displayName: string }>();
  for (const p of profiles) {
    const key = normalize(p.displayName);
    if (!idx.has(key)) idx.set(key, { userId: p.userId, displayName: p.displayName });
  }
  return idx;
}

/** Clé normalisée d'un pseudo (exposée pour requêter les profils candidats). */
export function normalizeMention(raw: string): string {
  return normalize(raw);
}

/** Relie les mentions brutes à des utilisateurs via l'index displayName→userId (insensible casse/accents). */
export function resolveMentions(
  raw: RawMention[],
  index: Map<string, { userId: string; displayName: string }>,
): ResolvedMention[] {
  const out: ResolvedMention[] = [];
  for (const r of raw) {
    const hit = index.get(normalize(r.raw));
    if (hit) out.push({ pseudo: hit.displayName, userId: hit.userId, offset: r.offset, length: r.length });
  }
  return out;
}
