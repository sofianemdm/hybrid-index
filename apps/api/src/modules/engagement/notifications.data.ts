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

export const NOTIFICATION_TRIGGERS: NotificationTrigger[] = [
  { key: "rival-overtaken", trigger: "rival_resolved && rivalIndex > userIndex", title: "Ton rival vient de te passer", body: "Reprends la tête : un WOD bien placé peut suffire.", priority: "high", cooldown: "24h", category: "rival" },
  { key: "rival-beaten", trigger: "rival_resolved && userIndex > rivalIndex", title: "Tu as dépassé ton rival 🔥", body: "Index devant. Garde l'avance cette semaine.", priority: "high", cooldown: "24h", category: "rival" },
  { key: "week-almost-complete", trigger: "weekCount == weeklyGoal-1 && daysLeft >= 1", title: "Plus qu'un WOD", body: "Un seul entraînement et ta semaine est validée.", priority: "high", cooldown: "48h", category: "streak" },
  { key: "streak-protected", trigger: "streak_evaluated && outcome == frozen", title: "Ta série est protégée", body: "On a utilisé un jeton de gel. Ta série continue, tranquille.", priority: "medium", cooldown: "0", category: "streak" },
  { key: "new-rank", trigger: "rank_changed && newRank > oldRank", title: "Nouveau rang", body: "Ta progression paie. Continue sur ta lancée.", priority: "high", cooldown: "0", category: "progression" },
  { key: "badge-unlocked", trigger: "badge_unlocked", title: "Badge débloqué", body: "Tu as débloqué un nouveau badge.", priority: "medium", cooldown: "0", category: "badges" },
  { key: "index-improved", trigger: "index_recomputed && newIndex > oldIndex+5", title: "Ton Index grimpe", body: "Ton dernier effort a compté.", priority: "medium", cooldown: "24h", category: "progression" },
  { key: "next-rank-close", trigger: "index_recomputed && pointsToNextRank <= 15", title: "Le prochain rang est tout proche", body: "Un bon WOD et tu y es.", priority: "medium", cooldown: "72h", category: "progression" },
  { key: "gentle-comeback", trigger: "noWodForDays == 3 && !plannedRest", title: "Prêt à reprendre ?", body: "Quand tu veux, on est là. Même 10 minutes comptent.", priority: "low", cooldown: "7d", category: "reengagement" },
  { key: "rest-week-respected", trigger: "streak_evaluated && outcome == rest", title: "Semaine de repos validée", body: "La récup fait partie du jeu. Ta série est intacte.", priority: "low", cooldown: "0", category: "streak" },
];
