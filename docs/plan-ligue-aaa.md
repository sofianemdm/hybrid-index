# Plan d'implémentation AAA — Mode Ligue + features gamification

> **Statut : PLAN (pas de code écrit).** À valider avant implémentation (règle projet : planifier avant de coder).
> Sources : `docs/gamification-strategy.md`, specs **architecte** + **sport-science**, vérifiées contre le code réel.

## 0. Décisions humaines déjà actées
- **Ligue = système OPT-IN, séparé et complémentaire** du classement Index (qui reste INTACT, jamais réinitialisé).
- **Cycle MENSUEL = une « saison » assumée** : les **points de Ligue** se remettent à zéro chaque mois ; l'**Index NON**.
- **1 WOD imposé/semaine → 4 WODs/mois**, points selon le temps/score (réutilise le `subScore` du score-service, AUCUNE nouvelle formule de scoring).
- **Synergie** : la séance faite pour la Ligue **compte AUSSI pour l'Index** (un seul log → points du mois + meilleur effort permanent via le flux `results` no-drop).
- **Multi-tentatives** : on retient le **MEILLEUR effort de la semaine** (pas la somme).
- **🆕 Démarrage SIMPLE (décision du 25/06)** : au lancement, **mêmes WODs sans matériel pour tout le monde**, **pas de poids adaptable / pas de Rx-Scaled** → tout le monde est comparable → **seulement 2 ligues : Homme / Femme** (respecte parfaitement la décision verrouillée « 2 ligues », zéro classement fantôme).
- **Évolutions FUTURES** (quand la population grandit, à rediscuter le moment venu) : filière Avec/Sans matériel, niveau Rx/Scaled, divisions 1→10 + montée/relégation + clubs (≥ 200 inscrits). On garde dès maintenant les colonnes `filiere`/`niveau` en base (defaults), pour que ces évolutions ne demandent **aucune migration**.
- Badge **Pionnier** aux premiers inscrits.
- **Pas de faux comptes dans la Ligue** (compétition 100 % réelle).

## 0bis. Ce qui existe déjà (audit du code) → moins à construire
- ✅ **A2 (Index Projeté)** : endpoint `/v1/score/project` **déjà câblé** → surtout du front.
- ✅ **C2 (badges régularité)** : **déjà présents** (`badges.data.ts`).
- ✅ **WOD de la semaine** : module **`challenge`** existe déjà → on réutilise.
- ✅ **D3 messagerie**, **D6 profils publics** : déjà en place.
- ⚠️ `@nestjs/schedule` (cron) à ajouter pour le cycle mensuel. **C3** (8/8 matériel), **C6**, **C10** à créer.

---

## 1. Démarrage : 2 ligues seulement (H/F) — le plus simple et le plus juste

Au lancement, **un seul WOD imposé par semaine, sans matériel, identique pour tout le monde, sans poids adaptable**. Conséquence : tout le monde est directement comparable → **2 ligues uniquement (Homme / Femme)**, triées par points mensuels. Pas de filière, pas de Rx/Scaled, pas de divisions tant qu'on est peu nombreux. **Aucun classement fantôme, conforme à 100 % à la décision « 2 ligues ».**

**Évolutions futures (sans migration, à activer plus tard)** : la base portera dès maintenant des colonnes `filiere` (default `bodyweight`) et `niveau` (default `rx`) sur `LeagueEntry`/`LeagueWeek`, et la clé Redis les inclura. Quand la population grandira, on pourra activer — par simple bascule de données — la filière Avec/Sans matériel, le niveau Rx/Scaled, puis les divisions 1→10 + montée/relégation (≥ 200 inscrits). Ces évolutions seront rediscutées le moment venu.

---

## 2. Architecture (architecte)

### 2.1 Modèle de données (Prisma, schéma `app`)
- `LeagueSeason` (`monthKey`, `status`, `divisionTier` figé à l'ouverture, dates).
- `LeagueWeek` (4/mois, `weekIndex`, `weekKey`, **`wodId` PAR FILIÈRE** → en pratique 2 WODs imposés/semaine : 1 avec matériel, 1 sans).
- `LeagueEntry` (opt-in ; **`sex` + `filiere` (equip/bodyweight) + `niveau` (rx/scaled)** figés ; `divisionId` nullable).
- `LeaguePoints` (ledger durable = vérité ; `wodResultId @unique` → anti-double-comptage ; `points`, `subScore`, `review`).
- `LeagueDivision`, `LeagueStanding` (archive classement final → historique).

### 2.2 Redis (ZSET versionnés par mois et par segment)
- Clé : `league:{monthKey}:{sex}:{filiere}:{niveau}[:d{tier}]`.
- `ZINCRBY` (cumul sur 4 semaines), **source de vérité = Postgres** (`LeaguePoints`), Redis = cache de tri. Nouveau mois = nouvelle clé (reset propre), `EXPIRE` 7 j sur le mois clos.

### 2.3 Flux « 1 log → 2 usages » (cœur)
Insertion dans **`ResultsService.log()`** (point d'écriture unique `POST /v1/results`) : après scoring → anti-triche → upsert `WodResult` → **recompute Index no-drop (usage 1)** → feed/streak/badges → **award points Ligue (usage 2, best-effort)**.
`awardForResult` ne compte que si : saison active, user inscrit, `wodId` = WOD imposé de **sa filière** cette semaine, `review === "ok"`. Idempotent sur `wodResultId`. Retient le **meilleur effort de la semaine**.

### 2.4 API (`/v1/league/*`, lecture seule sauf enroll)
`GET /season/current` · `POST /enroll` (choix filière + niveau, ou dérivé de l'onboarding) · `GET /week/current` (le WOD de MA filière) · `GET /standings?sex=&filiere=&niveau=&div=` · `GET /me` · `GET /history`. DTO Zod dans `packages/contracts`.

### 2.5 Cycle de vie (cron `@nestjs/schedule`, module `league`)
- **Ouverture** (1er du mois) : créer saison, figer `divisionTier` selon inscrits, créer les `LeagueWeek` (1 WOD avec matériel + 1 sans, par semaine), push invitation.
- **Clôture** (début mois suivant) : figer classement final → `LeagueStanding` ; montée/relégation si tier>1 (hystérésis anti ping-pong) ; `EXPIRE` ZSET ; push recap. **Index jamais touché.** Idempotent (verrou sur `status`).

---

## 3. Formule de points (sport-science) — simplifiée par la segmentation

Comme Rx et Scaled sont désormais des **classements séparés**, **plus besoin de décote** : dans un classement donné, tout le monde est au même niveau.

```
PERF_MAX = 900 ; PART_BONUS = 100
weekPoints(s) = clamp( round( 100 + round(900 * s/1000) ), 0, 1000 )
monthScore = Σ_{semaine 1..4} max( weekPoints des efforts valides de la semaine )
```
- Points dérivés du `subScore` (0–1000) déjà normalisé **par sexe** → équité inter-sexes et inter-WODs héritée + anti-triche hérité (bornes `hardMin/Max`).
- Absence = 0 (jamais de malus). Re-tests = on garde le **max** de la semaine.
- Exemples (Fran) : Élite ≈ **955** · Intermédiaire ≈ **640** · Débutant ≈ **280–330**.
- Effet voulu : un **débutant régulier** (4 semaines) bat un **intermédiaire irrégulier** (1 semaine).

Cas limites testés : plancher (s=0→100), plafond (s=1000→1000), absence (0), hors bornes (422), double soumission (max), reset mensuel, clamp.

---

## 4. Calendrier des WODs (sport-science)

**Au lancement : pool 100 % SANS matériel, un WOD identique pour tous** (la filière « avec matériel » est une évolution future).
- **Pool de lancement (sans matériel)** : Benchmark Zéro, Burpees 7 min, Max pompes strictes, Max air squats 2 min, 5 km, 3 km, Profil Express… (rotation FIFO sans répétition jusqu'à épuisement).
- **Pool futur (avec matériel, désactivé au début)** : Fran, Karen, Helen, Cindy, Grace, Jackie, Row 2k, Isabel…
- **Règle R-ROT** : rotation FIFO par pool (un WOD ne réapparaît pas avant épuisement du pool), ≥ 4 des 6 attributs couverts/mois.
- **Exclus du pool imposé** (trop longs/risqués, restent dispo pour l'Index) : Murph, Marathon, Semi, 10000m, HYROX solo, Squat 1RM.

**Anti double-comptage Index** : l'Index garde le **meilleur subScore par attribut (no-drop)** ; la Ligue lit le **même** subScore. Une mauvaise séance Ligue **ne baisse jamais l'Index**.

**WOD de la Semaine (WOTW)** : il y en a désormais **2 par semaine** (1 par filière). Le module `challenge` affiche à chaque user le WOTW **de sa filière**. → 1 seule séance test/semaine par personne (anti-surentraînement préservé).

---

## 5. Garde-fous sportifs
- 1 WOD imposé/semaine (celui de ta filière), fenêtre 7 j, re-test conseillé après 48–72 h.
- Chaque filière 100 % jouable (la filière « sans matériel » n'impose jamais de matériel). Aucun WOD imposé sans alternative basse-technicité.
- No-drop : la Ligue ne peut jamais faire baisser l'Index → pas de peur de « casser son Index ».

---

## 6. Autres features (rappel)
| Feat | Quoi | Effort |
|---|---|---|
| **A2** Index Projeté (curseur cible → anneau animé) | F (endpoint déjà là) |
| **A8** PR Wall (onglet records dans l'historique) | F |
| **A21** Radar Insight (phrase auto à côté du radar + bouton « Combler ») | F |
| **B5** WOTW board (classement du WOD de la semaine, par filière) | F |
| **B9** 6 ladders d'attribut | M |
| **C3** badge « 8/8 avec matériel » · **C6** Hybrid Master · **C10** Pionnier | F |
| **D5** Co-WOD · **D7** mur PR club (post-200) | M |
| **E9** Fresh Week (bannière lundi) | F |
| **Section I** notifs éthiques (quiet hours 21h-8h, plafond 1/j ~4/sem, désactivables, ton positif, anti dark-pattern) + écran réglages | M |

---

## 7. Vagues d'implémentation
- **Vague 1** : fondations Ligue segmentée (enroll filière+niveau + WOD semaine par filière + award points + classement mensuel, tier=1, Rx/Scaled en tag) + badge Pionnier + **A2, A8, A21, B5**. Tests : formule de points, idempotence `wodResultId`, no-double-comptage, garde `review`, segmentation correcte.
- **Vague 2** : split Rx/Scaled à 40, divisions à 200 + montée/relégation + **B9** + **C3/C6** + **Section I** + **E9**.
- **Vague 3** : social post-200 (**D7**, **D5**, club vs club).

---

## 8. Risques & garde-fous
- **Double-comptage Index/Ligue** → `wodResultId @unique`, point d'écriture unique.
- **Classements fantômes au début** → segmentation progressive (filière toujours, Rx/Scaled à 40, divisions à 200).
- **Reset/clôture non atomique** → idempotent sur `status`, transaction par segment, nouvelle clé Redis mensuelle.
- **Anti-triche** → hérité (review ≠ ok exclut ; bornes hardMin/Max).
- **Redis desync** → source durable Postgres + rebuild (SUM par user).
- **WOD imposé absent en DB** → cron valide le `wodId` avant création (seed obligatoire après migration en prod).

---

## 9. Reste à confirmer
- ✅ Multi-tentatives = meilleur effort. ✅ Filières séparées matériel/sans. ✅ Rx/Scaled séparés. ✅ Barème (à valider §3). ✅ Démarrage = Vague 1 complète.
- ❓ **Granularité au lancement** : segmenter Rx/Scaled tout de suite (risque de classements à 4 personnes) **ou** progressivement (tag d'abord, split à ~40) — *recommandé : progressif*.
