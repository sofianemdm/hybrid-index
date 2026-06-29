/** Catalogue des déclencheurs de notification (spec gamification 20 juin). L'envoi push réel
 *  (FCM) est différé ; on expose ici les déclencheurs + leurs réglages d'opt-out. Ton toujours
 *  positif, jamais de honte/FOMO punitif ; respect des quietHours et du dailyCap. */
export interface NotificationTrigger {
  key: string;
  trigger: string;
  title: string;
  body: string;
  priority: "high" | "medium" | "low";
  cooldown: string;
  category: string;
}

/**
 * Catalogue exposé à l'écran Réglages = STRICTEMENT les 6 push réellement émis (1 toggle = 1 vraie
 * notification, piloté par le gating par clé `prefEnabled(prefs, key)`). On a retiré les déclencheurs
 * « fantômes » (week-almost-complete, streak-protected, new-rank, badge-unlocked, index-improved,
 * gentle-comeback, rest-week-respected, wod-overtaken) qui n'émettaient AUCUN push : ils donnaient à
 * l'utilisateur des interrupteurs qui ne coupaient rien. Les `key` ci-dessous == les types de push
 * (cf. PUSH_COPY) ⇒ opt-out et cooldown s'appliquent réellement. Titres/corps ALIGNÉS sur PUSH_COPY.
 */
export const NOTIFICATION_TRIGGERS: NotificationTrigger[] = [
  { key: "rank-overtaken", trigger: "leaguePosition > snapshotPosition", title: "On t'a doublé au classement", body: "Reprends ta place — un bon WOD peut suffire.", priority: "medium", cooldown: "24h", category: "leaderboard" },
  { key: "near-rank", trigger: "index_recomputed && pointsToNextRank <= NEXT_RANK_CLOSE_THRESHOLD", title: "Le prochain palier est tout proche", body: "Un bon WOD et tu y es.", priority: "medium", cooldown: "72h", category: "progression" },
  { key: "stale-attribute", trigger: "attribute_stale && unlocked", title: "Un de tes axes mérite un re-test", body: "Un attribut peut grimper. Quand tu veux.", priority: "low", cooldown: "7d", category: "progression" },
  { key: "kudos", trigger: "session_kudos_received", title: "On a réagi à ta perf", body: "Des athlètes ont salué ta séance.", priority: "medium", cooldown: "12h", category: "social" },
  { key: "weekly-recap", trigger: "weekly_cron && (sessions > 0 || deltaIndex > 0)", title: "Ta semaine en bref", body: "Ton récap de la semaine est prêt.", priority: "low", cooldown: "7d", category: "progression" },
  { key: "new-message", trigger: "direct_message_received", title: "Nouveau message", body: "Ouvre la conversation pour répondre.", priority: "medium", cooldown: "0", category: "social" },
];

/**
 * SOURCE DE VÉRITÉ UNIQUE du seuil « prochain rang tout proche » (en points d'AFFICHAGE /100).
 * Importé à la fois par le flux in-app (engagement.service.ts) et le catalogue ci-dessus, pour
 * que le déclencheur documenté et le code qui le déclenche ne divergent jamais (avant : 15 vs 5).
 */
export const NEXT_RANK_CLOSE_THRESHOLD = 5;

/** Langue d'un payload push. Le modèle n'a pas (encore) de `locale` → on retombe sur FR. */
export type PushLocale = "fr" | "en";

/**
 * Libellés lisibles des attributs du radar, par langue, pour les push (ex. stale-attribute).
 * Aligné sur ATTRIBUTE_KEYS (contracts). FR par défaut ; EN pour les anglophones (cf. TODO i18n).
 */
export const ATTRIBUTE_LABELS: Record<PushLocale, Record<string, string>> = {
  fr: {
    engine: "cardio",
    speed: "vitesse",
    strength: "force",
    power: "puissance",
    muscular_endurance: "endurance musculaire",
    hybrid: "hybride",
  },
  en: {
    engine: "engine",
    speed: "speed",
    strength: "strength",
    power: "power",
    muscular_endurance: "muscular endurance",
    hybrid: "hybrid",
  },
};

/** Libellé d'un attribut dans la langue voulue (FR par défaut, repli = la clé brute). */
export function attributeLabel(attribute: string, locale: PushLocale = "fr"): string {
  return ATTRIBUTE_LABELS[locale]?.[attribute] ?? ATTRIBUTE_LABELS.fr[attribute] ?? attribute;
}

/**
 * Copie localisée des push de ré-engagement, centralisée ici (avant : FR codé en dur dans
 * push.service.ts). Chaque déclencheur fournit `title`/`body` en FR et EN ; `body` est une
 * fonction des paramètres (pluriels, nom, etc.). Ton bienveillant verrouillé, jamais punitif.
 *
 * La langue est résolue par destinataire via `Profile.locale` (cf. `PushService.recipientLocale`),
 * passée en 2e argument de `pushCopy(...)`. Repli FR si la locale est absente ou inconnue.
 */
export interface PushCopyEntry {
  title: string;
  body: (p: Record<string, string | number>) => string;
}

const PUSH_COPY: Record<string, Record<PushLocale, PushCopyEntry>> = {
  // Formulation UNIFIÉE avec le catalogue NOTIFICATION_TRIGGERS (« doublé » / « overtaken »).
  "rank-overtaken": {
    fr: { title: "On t'a doublé au classement", body: () => "Reprends ta place — un bon WOD peut suffire. 👊" },
    en: { title: "You've been overtaken in the ranking", body: () => "Take your spot back — one good WOD can do it. 👊" },
  },
  "stale-attribute": {
    fr: { title: "Un de tes axes mérite un re-test", body: (p) => `Ton ${p.attributeLabel} peut grimper. Quand tu veux.` },
    en: { title: "One of your areas deserves a re-test", body: (p) => `Your ${p.attributeLabel} can climb. Whenever you're ready.` },
  },
  "near-rank": {
    fr: { title: "Le prochain palier est tout proche", body: (p) => `Plus que ${p.points} point${Number(p.points) > 1 ? "s" : ""} — un bon WOD et tu y es.` },
    en: { title: "The next tier is within reach", body: (p) => `Just ${p.points} point${Number(p.points) > 1 ? "s" : ""} to go — one good WOD and you're there.` },
  },
  kudos: {
    fr: { title: "On a réagi à ta perf", body: (p) => `${p.count} athlète${Number(p.count) > 1 ? "s ont" : " a"} salué ta séance. 🔥` },
    en: { title: "Someone reacted to your effort", body: (p) => `${p.count} athlete${Number(p.count) > 1 ? "s" : ""} cheered your session. 🔥` },
  },
  "weekly-recap": {
    fr: { title: "Ta semaine en bref", body: (p) => `+${p.deltaIndex} pts d'Index, ${p.sessions} séance${Number(p.sessions) > 1 ? "s" : ""}. Belle semaine. 📈` },
    en: { title: "Your week in a nutshell", body: (p) => `+${p.deltaIndex} Index pts, ${p.sessions} session${Number(p.sessions) > 1 ? "s" : ""}. Great week. 📈` },
  },
  "new-message": {
    fr: { title: "Message de {senderName}", body: () => "Ouvre la conversation pour répondre." },
    en: { title: "Message from {senderName}", body: () => "Open the conversation to reply." },
  },
};

/**
 * Résout la copie d'un push pour un déclencheur + une langue (FR par défaut). Le titre peut porter
 * des placeholders `{name}` interpolés depuis `params`. Best-effort : un type inconnu retombe sur
 * un libellé neutre plutôt que de planter l'envoi.
 */
export function pushCopy(
  type: string,
  locale: PushLocale = "fr",
  params: Record<string, string | number> = {},
): { title: string; body: string } {
  const entry = PUSH_COPY[type]?.[locale] ?? PUSH_COPY[type]?.fr;
  if (!entry) return { title: "Athlete League", body: "" };
  const title = entry.title.replace(/\{(\w+)\}/g, (_, k: string) => String(params[k] ?? ""));
  return { title, body: entry.body(params) };
}
