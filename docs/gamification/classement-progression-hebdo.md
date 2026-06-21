# Classement de Progression Hebdomadaire — Spec implémentable

> Statut : spec validée par l'expert gamification (2026-06-21). Les ingénieurs implémentent.
> Source de vérité produit : `docs/cahier-des-charges.md` (§3-4, §11-12, §14).
> S'aligne sur l'existant : `streak.service.ts`, `leaderboard.service.ts`, `results.service.ts`,
> `badges.data.ts`, `iso-week.ts`, `feed-events.service.ts`, `notifications.data.ts`.

## 0. Intention et garde-fous psychologiques

Board **distinct** du classement Index absolu. On ne classe PAS par niveau atteint, on classe
par **effort fourni cette semaine**. Fondé sur la SDT (compétence + autonomie) : la comparaison
par effort est moins écrasante que l'absolu, et féliciter les plus faibles est sain tant que la
récompense reste honnête (on récompense un effort réel, pas une flatterie creuse).

Principe fondateur appliqué :
- Beaucoup de séances cette semaine -> bien classé.
- Battre son record -> bien classé.
- Toute petite action -> une chance d'être bien classé.

Interdits (décisions verrouillées + playbook) :
- PAS de saisons, PAS de season pass, PAS d'échelle de récompenses à paliers temporels.
- PAS de honte des bas du classement, PAS de FOMO punitif, PAS de streak-shaming.
- La crédibilité reste sacrée : ce board mesure l'effort, jamais le talent. On ne le confond
  jamais avec le « Top 5 % » de la ligue Index (qui, lui, reste compétitif et honnête).

## 1. Barème de points d'effort (EP — Effort Points)

Tout est exprimé en **EP**. Le score hebdo d'un utilisateur = somme des EP gagnés dans la
fenêtre courante (cf. §3), après application des plafonds (§2).

| # | Action (event) | EP | Notes |
|---|----------------|----|-------|
| A | **Logger une séance valide** (WodResult, `review = ok`, `subScore != null`) | **+10** | Brique de base. Plafonné, cf. §2. |
| B | **Jour actif** (≥1 séance valide dans la journée UTC) | **+15** | Récompense la régularité, pas le volume. Max 1 fois/jour. |
| C | **Bonus régularité 3 jours actifs** (3 jours distincts actifs dans la semaine) | **+30** | Palier unique/semaine. |
| D | **Bonus régularité 5 jours actifs** | **+50** | Palier unique/semaine (cumulable avec C : 3j puis 5j = 80). |
| E | **Battre un PR** (nouveau meilleur `subScore` sur un WOD déjà fait avant cette semaine) | **+40** | Pondéré, cf. §2.3. Détection = event `pr` de `results.service`. |
| F | **Première séance d'un WOD jamais fait** (WOD distinct nouveau pour l'utilisateur) | **+25** | Encourage l'exploration. N'est PAS un PR (pas de baseline). |
| G | **Débloquer un attribut du radar** (AttributeScore passe `unlocked: false -> true`) | **+60** | Rare et structurant. Max 6 à vie. |
| H | **Compléter le radar (6/6)** cette semaine | **+100** | One-shot à vie. Gros pic honnête : c'est un vrai jalon. |
| I | **Valider sa semaine de streak** (`thisWeekCount >= weeklyGoal`, cf. `StreakState`) | **+35** | Atteindre SON objectif perso (autonomie SDT), pas un objectif imposé. |
| J | **Semaine de repos planifié** (`plannedRest = true`) | **+35** | Égalité stricte avec I : le repos vaut autant que l'effort. ANTI-surentraînement. |
| K | **Réveil après inactivité** (1ère séance après ≥2 semaines sans séance) | **+20** | Bonus de retour bienveillant. Max 1/mois. |

Notes de conception :
- B (jour actif) > A×1 : on veut « 3 séances sur 3 jours » mieux classé que « 3 séances le
  même jour ». La régularité prime sur le burst.
- I et J sont volontairement **égaux** : le système ne préfère jamais l'effort au repos.
- Un débutant qui logue 2 jours + 1 PR + 1 WOD nouveau = 10×2 + 15×2 + 40 + 25 = **105 EP**,
  largement de quoi figurer honorablement. C'est le but : l'effort sincère paie vite.

## 2. Anti-triche / anti-farming (CRITIQUE)

Le barème doit récompenser l'effort **sincère**, pas le spam de logs bidon.

### 2.1 Plafonds durs

| Plafond | Valeur | Raison |
|---------|--------|--------|
| EP « log de séance » (A) par **jour** | **30** (= 3 séances) | Au-delà, A rapporte 0. On ne récompense pas le volume malsain. |
| EP « log de séance » (A) par **semaine** | **120** (= 12 séances) | Cohérent avec ~3 séances/sem recommandées ; tolère l'athlète assidu sans ouvrir au farm. |
| Nombre de **PR comptabilisés** (E) par jour | **2** | Empêche de « battre son PR » 10× d'affilée par micro-incréments. |
| Nombre de **PR comptabilisés** (E) par semaine | **5** | — |
| Logs **par WOD** comptés pour A par jour | **1** | Reloguer le même WOD 5× le même jour = 1 seul A compté. |
| EP **total** par jour (toutes sources) | **120** | Filet de sécurité global anti-burst. |

Implémentation : les plafonds s'appliquent à l'**écriture** du ledger (cf. §7), pas à
l'affichage. Un event au-delà du plafond est enregistré avec `epAwarded = 0` et
`cappedReason` renseigné (auditable, jamais montré « négativement » à l'utilisateur).

### 2.2 Validité d'une séance comptabilisable

Un WodResult ne génère des EP que si **tous** ces critères sont vrais :
- `review = ok` (pas `pending`/`rejected`) ET `subScore != null`.
- `performedAt` dans la fenêtre courante (§3) ET `performedAt <= now + 5 min` (pas de futur).
- Le `rawResult` a passé les bornes physiologiques du score-service (déjà garanti par
  `ResultsService.log` -> `scoreClient.computeSubScore`, qui renvoie 422 hors bornes §5.5).
- Backfill toléré mais borné : un résultat antidaté de plus de **8 jours** dans le passé
  n'entre dans AUCUNE fenêtre hebdo (il compte pour l'Index, pas pour le board d'effort).

### 2.3 Pondération des PR (anti micro-PR)

Un PR ne compte (event E, +40) que si l'amélioration est **significative** :
- Gain de `subScore` ≥ **2 points** OU ≥ **1 %** du subScore précédent (le plus grand des deux).
- Sinon : l'amélioration est enregistrée comme un meilleur résultat (l'Index en bénéficie),
  mais ne déclenche PAS l'EP de PR. Évite le farming par incréments d'un point.
- Premier résultat sur un WOD = event F (+25), jamais E (pas de baseline à battre).

### 2.4 Détection de logs « bidon »

- Déduplication forte : deux WodResult identiques (`userId`, `wodId`, `rawResult` à ±0)
  à moins de 10 min d'intervalle -> le second ne génère aucun EP (`cappedReason: "duplicate"`).
- Le plafond « 1 log/WOD/jour pour A » (§2.1) neutralise déjà le spam du même WOD.
- Heuristique de revue (best-effort, non bloquante) : un utilisateur dépassant **8 logs en
  < 30 min** voit ses séances suivantes du créneau marquées `review = pending` (déjà supportée
  par le champ `WodResult.review`), donc EP différés jusqu'à validation. À surveiller via
  PostHog, ajustable.

### 2.5 Pourquoi ces plafonds ne pénalisent pas l'effort sincère

Un athlète qui s'entraîne dur fait 1-2 WODs/jour sur 4-5 jours : il atteint A (B×5 + C + D +
quelques E) très confortablement **sans** jamais toucher les plafonds. Les plafonds ne mordent
que sur les patterns non physiologiques (10 logs en 5 minutes).

## 3. Cadence — fenêtre hebdomadaire

- **Fenêtre = semaine ISO-8601, lundi 00:00 UTC -> dimanche 23:59:59 UTC.** On réutilise
  `isoWeekKey(d)` / `weekStart(d)` de `engagement/iso-week.ts` (même convention que le streak,
  cohérence garantie). Clé de fenêtre = `isoWeekKey(now)` (format `YYYY-Www`).
- **Réinitialisation : lundi 00:00 UTC.** Le total repart de 0. (Phase ultérieure : décaler sur
  le fuseau utilisateur ; pour l'instant tout est UTC, aligné sur le streak.)
- « Glissante » au sens produit = chaque lundi une nouvelle course démarre ; ce n'est pas une
  fenêtre de 7 jours mobiles (le board partagé exige une borne commune à tous). Le snapshot de
  fin de semaine (top progression) est figé à la clôture (§5).

### Affichage (réponse API `GET /v1/leaderboard/progress`)

```jsonc
{
  "weekKey": "2026-W25",
  "weekEndsAt": "2026-06-22T00:00:00Z",
  "scope": "all",            // "all" | "club"
  "total": 1842,             // participants ayant >=1 EP cette semaine
  "me": {
    "position": 312,
    "ep": 105,
    "rankBand": "top_25",    // cf. §5.2
    "delta": "+105",         // EP gagnés cette semaine
    "isPersonalBest": true   // meilleure semaine personnelle (cf. §5.3)
  },
  "entries": [               // page autour de moi + top, comme leaderboard.service
    { "position": 1, "userId": "...", "displayName": "...", "ep": 410, "isMe": false }
  ]
}
```

- Distinct du `leaderboard.service` (Index). On NE réutilise PAS le sorted set Index. Voir §7
  pour le store dédié (Redis sorted set `progress:{weekKey}:{scope}` + ledger Postgres durable).
- Pagination/forme alignées sur `LeaderboardEntry` (position 1-indexée, `isMe`, `displayName`,
  `rank` via `Profile.rank` si on veut afficher le badge de rang à côté).

## 4. Filtrable — Tous / Mon club

- `scope=all` : tous les participants actifs de la semaine, ligue confondue OU séparée par sexe
  selon le réglage UI (par défaut **séparé par sexe**, cohérent avec les 2 ligues verrouillées).
  Clé Redis : `progress:{weekKey}:all:{sex}`.
- `scope=club` : **même barème exact**, restreint aux membres du club de l'utilisateur.
  - Dépendance : il n'existe PAS encore de modèle `Club`/`Membership` (décision verrouillée :
    box/amis seulement après 200 users). Donc `scope=club` est **spécifié mais désactivé**
    (feature flag `clubProgressBoard=false`) tant que le modèle club n'existe pas. À l'activation :
    clé Redis `progress:{weekKey}:club:{clubId}`, filtre `membership.clubId`.
  - Aucune duplication de logique : le ledger EP (§7) est unique ; le scope ne change que le
    périmètre d'agrégation et la clé du sorted set.

## 5. Reconnaissance saine (sans saison)

### 5.1 Mise en avant du top progression de la semaine

- À la **clôture** (lundi 00:00 UTC, job `closeProgressWeek`), on fige le classement de la
  semaine écoulée. Le **#1 de chaque ligue** reçoit une mise en avant douce dans le feed
  (`FeedEvent` — nécessite d'étendre l'enum `FeedEventType` avec `progress_week_top`).
- **Pas de récompense matérielle exclusive** (pas de season pass). Reconnaissance = mise en
  avant sociale + un badge **répétable non rival** : `weekly-grinder` (cf. §6).
- On met en avant **l'effort**, pas la domination : copie « plus gros progrès de la semaine »,
  jamais « le plus fort ».

### 5.2 Bandes de reconnaissance (rankBand) — tout le monde gagne une bande

Calculées sur les participants actifs de la semaine (≥1 EP), par scope :

| rankBand | Condition | Ton |
|----------|-----------|-----|
| `top_1` | percentile ≥ 99 | « Semaine exceptionnelle » |
| `top_5` | percentile ≥ 95 | « Énorme semaine » |
| `top_25` | percentile ≥ 75 | « Grosse semaine » |
| `rising` | a gagné ≥ 50 EP cette semaine, hors top_25 | « Belle progression » |
| `active` | a gagné ≥ 1 EP | « Tu as bougé cette semaine » |

Tout participant a au minimum `active` : **personne n'est étiqueté « dernier »**. Aucune bande
négative n'existe. Les non-participants ne reçoivent AUCUNE bande (pas de honte d'absence).

### 5.3 Félicitation à TOUS (message personnel)

À la clôture, chaque participant reçoit un message **positif et personnel** (notification +
carte in-app), jamais comparatif vers le bas :
- Compare l'utilisateur à **lui-même** (meilleure semaine perso, total, jours actifs).
- `isPersonalBest` = EP de la semaine > meilleur total hebdo historique de l'utilisateur
  (champ persistant `bestWeeklyEp`, cf. §7).

## 6. Badge associé (collection régularité, répétable)

À ajouter à `badges.data.ts`, catégorie `consistency`, sans cosmétique exclusif (reconnaissance
honnête, pas de scarcity artificielle) :

```ts
{ id: "weekly-grinder", category: "consistency",
  name: "Semaine pleine",
  description: "Tu as fini une semaine avec 3 jours actifs ou plus.",
  rarity: "common",
  condition: "active_days_week>=3",   // nouvelle clé à câbler dans matchesCondition
  cosmeticUnlock: null }
```

- Répétable conceptuellement (la reconnaissance hebdo vit dans le board) mais le badge de
  collection ne s'attribue qu'une fois (cohérent avec `UserBadge`). La répétition se vit dans
  le board, pas dans une inflation de badges.
- Nouvelle clé `active_days_week` à brancher dans `matchesCondition` (BadgeContext +
  `activeDaysThisWeek`), source : ledger EP (events B de la semaine courante).

## 7. Modèle de données & events (implémentation)

### 7.1 Ledger durable (source de vérité, Postgres)

Nouveau modèle `ProgressEvent` (schema.prisma, schéma `app`) :

```prisma
model ProgressEvent {
  id          String   @id @default(uuid()) @db.Uuid
  userId      String   @map("user_id") @db.Uuid
  weekKey     String   @map("week_key")           // isoWeekKey(performedAt)
  type        String                              // "wod_logged" | "active_day" | "pr" | ...
  epAwarded   Int      @map("ep_awarded")         // 0 si plafonné
  cappedReason String? @map("capped_reason")      // "daily_cap" | "duplicate" | "micro_pr" | null
  refId       String?  @map("ref_id") @db.Uuid    // ex. wodResultId
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz(6)

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([weekKey, userId])
  @@index([userId, weekKey])
  @@map("progress_event")
  @@schema("app")
}
```

Et un agrégat persistant par utilisateur (pour `bestWeeklyEp` et l'historique) :

```prisma
model ProgressWeekly {
  userId       String  @map("user_id") @db.Uuid
  weekKey      String  @map("week_key")
  ep           Int     @default(0)
  activeDays   Int     @default(0) @map("active_days")
  prCount      Int     @default(0) @map("pr_count")
  closed       Boolean @default(false)
  rankBand     String? @map("rank_band")
  @@id([userId, weekKey])
  @@index([weekKey, ep(sort: Desc)])
  @@map("progress_weekly")
  @@schema("app")
}
```

Plus un champ `bestWeeklyEp Int @default(0)` à ajouter sur `Streak` ou un petit modèle profil
gamification (au choix de l'architecte ; `Streak` est déjà le foyer de l'engagement hebdo).

### 7.2 Where points are awarded (câblage existant)

Tout passe par un nouveau `ProgressService.award(userId, event)` appelé **depuis
`ResultsService.log`**, juste après la détection PR existante (lignes ~81-93) — on réutilise
`isPr`, `wodMeta`, `scored.subScore` déjà calculés. Pseudo-flux :

```
log() {
  ... (existant: scored, created, recomputed) ...
  isPr = scored.subScore === best._max.subScore   // déjà calculé
  // NOUVEAU, best-effort comme streak/badges (ne fait jamais échouer le log) :
  progress.awardForResult(userId, {
    wodResultId: created.id, wodId, subScore: scored.subScore,
    performedAt, isPr, prevBest: best._max.subScore, isFirstEverOnWod, unlockedAttrs
  }).catch(e => logger.warn(...))
}
```

`awardForResult` applique en une transaction : validité (§2.2), dédup (§2.4), pondération PR
(§2.3), puis insère les events A/B/E/F/G/H/K avec plafonds (§2.1), et met à jour `ProgressWeekly`
+ le sorted set Redis `progress:{weekKey}:{scope}:{sex}` (ZINCRBY de l'EP net).

Les events streak I/J sont émis par `StreakService.evaluateAndGet` à la **clôture** de chaque
semaine validée/repos (point d'extension : après calcul de `outcome` dans la boucle while).

### 7.3 Redis (lecture rapide, comme leaderboard.service)

- Sorted set par semaine/scope/sexe : `progress:{weekKey}:all:{sex}`, membre = userId,
  score = EP net courant. TTL = 16 jours (couvre la semaine + la clôture + grâce).
- Repli Postgres : si Redis vide/froid, lire `ProgressWeekly` (`orderBy ep desc`), exactement
  le pattern `pgTop`/`positionOf` de `leaderboard.service`.

### 7.4 Job de clôture `closeProgressWeek` (lundi 00:00 UTC)

1. Pour la semaine qui vient de finir : marquer `ProgressWeekly.closed = true`, figer `rankBand`.
2. Mettre à jour `bestWeeklyEp` de chaque participant.
3. Émettre `progress_week_top` (FeedEvent) pour le #1 de chaque ligue.
4. Programmer les notifications de félicitation (§8), en respectant `quietHours` + `dailyCap`.
5. Idempotent (rejouable sans double-compter, comme `evaluateAndGet`).

## 8. Notifications (taxonomie — zéro dark pattern)

S'ajoutent à `notifications.data.ts`, soumises à `quietHours` + `dailyCap` (`NotificationPrefs`).

| id | Déclencheur | Plafond | Ton |
|----|-------------|---------|-----|
| `progress_week_recap` | Clôture hebdo, à TOUS les participants | 1/semaine | Félicitation perso (§5.3). Jamais comparatif vers le bas. |
| `progress_personal_best` | `isPersonalBest` à la clôture | 1/semaine (remplace le recap si déclenché) | « Meilleure semaine ! » |
| `progress_week_top` | #1 de ligue à la clôture | 1/semaine | « Plus gros progrès de la semaine. » |
| `progress_nudge_midweek` | Jeudi, si 0 EP cette semaine ET opt-in actif | 1/semaine, jamais 2 sem. de suite | Invitation douce, AUCUNE culpabilité. |

Interdits explicites : pas de « tu vas perdre ta place », pas de « X t'a dépassé, dépêche-toi »,
pas de compte à rebours anxiogène. Le board ne notifie jamais une chute de position.

## 9. Exclusion des faux utilisateurs de seed

- Les comptes de seed sont marqués par `User.consents = { seed: true }` (cf.
  `prisma/seed.ts:123`). Leurs données Index sont figées (pas d'activité « cette semaine »).
- Garde-fou principal **naturel** : le board est alimenté **uniquement** par des
  `ProgressEvent` créés à partir d'activité réelle dans la fenêtre. Les seeds n'en génèrent
  aucun -> ils n'apparaissent jamais (EP = 0, donc absents du sorted set, qui ne contient que
  les membres ayant reçu un ZINCRBY).
- Garde-fou explicite (défense en profondeur) : `ProgressService.award` ET le repli Postgres
  filtrent `where: { user: { NOT: { consents: { path: ["seed"], equals: true } } } }`.
  Ainsi, même un seed accidentellement « actif » ne pollue ni le classement, ni les
  dénominateurs de percentile (`total`, bandes §5.2).
- Conséquence saine : les bandes/percentiles d'effort reflètent de vrais humains -> la
  félicitation reste honnête.

## 10. Exemples de copies FR valorisantes (par cas)

Recap hebdo — débutant peu actif (1 jour, 1 séance) :
> « +10 cette semaine. Tu as commencé, c'est ça qui compte. On se retrouve lundi ? »

Recap hebdo — actif régulier (3 jours) :
> « Semaine pleine : 3 jours actifs, +85. Ta régularité parle pour toi. »

Personal best :
> « +160 cette semaine : ta meilleure semaine jusqu'ici. Tu montes en puissance. »

Nouveau WOD exploré :
> « Premier {wodName} bouclé. +25, et un attribut de plus qui s'éclaire. »

PR significatif :
> « Nouveau record sur {wodName}. +40 — tu repousses ta propre limite. »

Repos planifié (anti-surentraînement) :
> « Semaine de repos validée. Récupérer fait partie de l'entraînement. +35, série intacte. »

Réveil après pause :
> « Content de te revoir. +20 pour la reprise — on repart doucement. »

Top progression de la semaine (#1) :
> « Plus gros progrès de la semaine dans ta ligue. Pas le plus fort : celui qui a le plus
>   avancé. Chapeau. »

Nudge mi-semaine (opt-in, jamais culpabilisant) :
> « Une séance cette semaine et tu rejoins le classement progression. Même 15 minutes comptent. »

Cas « aucune activité » : **aucune notification de honte**. Au pire un nudge doux opt-in (§8),
jamais « tu as raté ta semaine ».
