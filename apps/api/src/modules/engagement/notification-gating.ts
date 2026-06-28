/**
 * Helpers PURS et testables du gating des notifications (aucune dépendance DB/Nest).
 * On y centralise les trois garde-fous AAA : quietHours (heures de silence), dailyCap
 * (plafond d'envois par jour) et cooldown (délai minimum entre deux envois d'un même type).
 *
 * Toutes les fonctions sont déterministes : on passe `now` explicitement (testabilité).
 */

/** Fenêtre d'heures de silence, format "HH:MM" 24h (peut enjamber minuit, ex. 22:00 → 07:00). */
export interface QuietHours {
  start: string;
  end: string;
}

/** Parse "HH:MM" → minutes depuis minuit. Renvoie null si invalide (on n'applique alors rien). */
function parseHm(value: string | undefined | null): number | null {
  if (!value) return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (!Number.isInteger(h) || !Number.isInteger(min) || h < 0 || h > 23 || min < 0 || min > 59) {
    return null;
  }
  return h * 60 + min;
}

/**
 * `now` est-il DANS la fenêtre de silence ? Gère le passage de minuit.
 * - Fenêtre normale (start < end) : silence si start <= t < end.
 * - Fenêtre enjambant minuit (start > end, ex. 22:00→07:00) : silence si t >= start OU t < end.
 * - start == end : fenêtre vide (jamais de silence). Bornes invalides : pas de silence.
 */
export function withinQuietHours(now: Date, quietHours: QuietHours | null | undefined): boolean {
  if (!quietHours) return false;
  const start = parseHm(quietHours.start);
  const end = parseHm(quietHours.end);
  if (start === null || end === null) return false;
  if (start === end) return false; // fenêtre nulle
  const t = now.getHours() * 60 + now.getMinutes();
  if (start < end) return t >= start && t < end; // même jour
  return t >= start || t < end; // enjambe minuit
}

/**
 * Le plafond journalier est-il respecté ? `countToday` = nb d'envois déjà faits aujourd'hui.
 * dailyCap <= 0 ⇒ aucun envoi autorisé. On autorise tant que countToday < dailyCap.
 */
export function underDailyCap(countToday: number, dailyCap: number): boolean {
  if (!Number.isFinite(dailyCap) || dailyCap <= 0) return false;
  return countToday < dailyCap;
}

/**
 * Le cooldown est-il écoulé depuis le dernier envoi de ce type ?
 * - lastSentAt null/absent ⇒ jamais envoyé ⇒ écoulé (true).
 * - cooldownSec <= 0 ⇒ pas de cooldown (true).
 * - sinon : (now - lastSentAt) >= cooldownSec.
 */
export function cooldownElapsed(
  lastSentAt: Date | null | undefined,
  now: Date,
  cooldownSec: number,
): boolean {
  if (!lastSentAt) return true;
  if (!Number.isFinite(cooldownSec) || cooldownSec <= 0) return true;
  const elapsedSec = (now.getTime() - lastSentAt.getTime()) / 1000;
  return elapsedSec >= cooldownSec;
}

/** Une clé de préférence est-elle activée ? Opt-out explicite : seul `false` désactive. */
export function prefEnabled(prefs: Record<string, boolean> | null | undefined, key: string): boolean {
  if (!prefs) return true;
  return prefs[key] !== false;
}
