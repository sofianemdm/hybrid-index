# HYBRID INDEX — Spécification d'engagement & gamification

> **Statut :** spec de référence pour l'engagement. Source de vérité : `docs/cahier-des-charges.md` (§3-4, §9.2, §11.4, §12, §14, §16) + `CLAUDE.md`.
> **Rôle de ce document :** définir des règles et des algorithmes *implémentables*. Les ingénieurs implémentent ; ce document décide du comportement.
>
> **Verrous respectés (ne JAMAIS réintroduire) :** pas de **quêtes**, pas de **saisons**, pas de **score de fatigue**, pas de **catégories de poids**. Score normalisé **par sexe uniquement**. Le score **ne baisse jamais brutalement** (meilleur effort retenu). 2 ligues (Hommes / Femmes). Tout public (`visibility` réservé pour l'avenir). 100 % gratuit. App utilisable sans matériel.
>
> **Doctrine non négociable :** engagement **SAIN** (régularité + récupération récompensées, jamais le surentraînement), **dopamine honnête** (la crédibilité du « top 5 % » est sacrée, zéro fausse flatterie), **ZÉRO dark pattern** (pas de honte de streak, pas de FOMO punitif).

---

## 0. Légende des phases

| Tag | Sens |
|---|---|
| **[MVP]** | Phase 1 — thin slice. Doit exister au lancement. |
| **[P2]** | Phase 2 — boucle complète & viralité. |
| **[P3]** | Phase 3 — échelle, vérification, endgame mondial enrichi. |

> Note de cadrage : le cahier (§19) range « badges complets », « défis », « kudos » en Phase 2. Ce document **distingue le sous-ensemble de badges/notifs strictement nécessaires à la boucle MVP** (progression solo : rang, percentile, Grand Chelem partiel, streak) des badges sociaux (Phase 2). Voir §4 et §6 pour le marquage par badge/notif.

---

## 1. La boucle d'habitude (modèle Hooked)

La boucle est **solo-suffisante** (fonctionne sans amis ni box, exigence §2) et **se referme sur elle-même** : chaque investissement arme le déclencheur suivant.

```
DÉCLENCHEUR ──► ACTION ──► RÉCOMPENSE VARIABLE ──► INVESTISSEMENT ──┐
     ▲                                                              │
     └──────────────────────────────────────────────────────────────┘
```

### 1.1 Les quatre temps, formalisés

| Temps | Contenu HYBRID INDEX | Détail |
|---|---|---|
| **Déclencheur** | externe : push « séance suggérée », « rival a bougé », « proche d'un rang », récap hebdo. interne : envie de battre son rival / compléter le radar / défendre son rang. | Plafonné (§6). L'objectif est que le déclencheur **interne** prenne le relais de l'externe en ~2-3 semaines. |
| **Action** | **faire + logger un WOD** (ou re-tester un benchmark). C'est l'action centrale, à friction minimale (logging hors-ligne, mode guidé). | Le « hot trigger » : action atteignable maintenant, motivation présente (envie de voir son score bouger). |
| **Récompense variable** | le **reveal** du résultat (§6.2 cahier) : sous-score, percentile, place gagnée, attribut qui monte, **rival dépassé**, badge, palier de percentile, PR. **Variable car inconnue avant la fin.** | Voir §1.2 : conséquences visibles garanties à chaque log. |
| **Investissement** | le log **enrichit l'actif de l'utilisateur** : radar plus complet, historique, rang, badges, avatar amélioré, place au classement, streak entretenu. → « j'ai quelque chose à défendre ». | Plus l'utilisateur investit, plus le prochain déclencheur interne est fort (capital accumulé = perte potentielle perçue, *sans* qu'on l'agite comme menace). |

### 1.2 Conséquences visibles de CHAQUE effort logué (contrat de récompense)

Un log ne doit **jamais** être « plat ». À chaque `WodResult` validé, le client affiche, dans l'ordre, ce qui s'applique (animation + haptique + son, §3.7 cahier) :

| Événement | Condition d'affichage | Récompense |
|---|---|---|
| Sous-score révélé | toujours | jauge animée 0→sous_score, percentile « meilleur que X % ». |
| Attribut débloqué | `unlocked(A)` passe false→true | branche du radar qui s'allume + « nouvel attribut ! ». |
| Attribut amélioré | `attribute_score(A)` augmente | delta `+Δ` sur la branche du radar. |
| **PR** | nouveau meilleur résultat sur ce WOD | badge PR + carte partageable. |
| Index mis à jour | l'Index recalculé change | compteur Index qui monte, delta `+Δ pts`. |
| Place gagnée | rang de ligue amélioré | « +N places ». |
| **Rival dépassé** | voir §2.5 | carte de célébration + nouveau rival. |
| Palier de percentile | franchit top 25/10/5/1 % | célébration marquante (§4). |
| Montée de rang | franchit une borne de rang (§3) | grande célébration + cosmétique. |
| Badge débloqué | condition badge remplie (§4) | carte badge + cosmétique éventuel. |
| Progrès « prochaine marche » | aucun des ci-dessus n'a sauté | **fallback obligatoire** : « +Δ pts — plus que X avant [prochaine marche] » (objectif proximal, §8). |

> **Règle anti-frustration :** si un log *n'améliore rien* (résultat sous le meilleur retenu), on n'affiche **aucune baisse** (le meilleur est conservé, §5.2 cahier). Message neutre et honnête : « Effort enregistré. Ton meilleur sur [WOD] reste [valeur]. » + suggestion douce (« re-tente quand tu es frais »). Jamais de ton punitif.

---

## 2. Système RIVAL (levier n°1) — spécification implémentable

> Source : §4.3 (levier 1) + §11.4. Le rival est le moteur d'engagement principal : un **duel personnel, atteignable, honnête**.

### 2.1 Définitions

- **Rival d'un utilisateur `U`** = l'athlète **actif** de **la même ligue** (= même sexe) ayant **le plus petit Index strictement supérieur** à celui de `U`.
- **Actif** = a logué **≥ 1 effort dans les 30 derniers jours** (fenêtre glissante). Garantit une cible réelle et battable.
- **Éligible comme rival** = actif **ET** `visibility` permet le classement (tout public en MVP) **ET** `HybridIndex.isProvisional == false` **ET** non exclu des classements (pas de flag anti-triche `isFlagged`, §5.5 cahier).
- Égalité d'Index : si plusieurs candidats ont exactement le même Index strictement supérieur, on prend celui dont **l'activité est la plus récente** (cible la plus « chaude »), puis `userId` le plus petit comme tie-break déterministe.

### 2.2 Données nécessaires

| Source | Champs |
|---|---|
| `Rival` (§16) | `userId`, `rivalUserId` (nullable), `recomputedAt`, **+ ajouts** : `rivalIndexSnapshot` (Index du rival au dernier recalcul, pour détecter le franchissement), `state` (`active` / `is_number_one` / `disabled_low_population`). |
| `HybridIndex` | `value`, `percentile`, `isProvisional`. |
| `WodResult` | `timestamp` (pour calculer « actif »), `isFlagged`. |
| `League` | dérivée du sexe. Index Redis sorted set par ligue (`zset:league:{men|women}` → score = Index). |
| `Profile` | `sex`, `visibility`. |

> **Implémentation classement :** le sorted set Redis par ligue donne en O(log n) le voisin immédiatement au-dessus. Le filtre « actif » se fait soit via un **second zset des actifs** (`zset:league:{sex}:active`, TTL/refresh quotidien des membres dont le dernier effort < 30 j), soit par itération `ZRANK`+ vérification. Recommandé : maintenir `zset:league:{sex}:active` pour O(log n) garanti.

### 2.3 Déclencheurs de recalcul

Le rival de `U` est recalculé :
1. **À chaque variation de l'Index de `U`** (après validation d'un `WodResult` qui change l'Index).
2. **Une fois par jour** (batch nocturne, par ligue) — capte les mouvements des autres et l'expiration de l'« actif » à 30 j.
3. **Opportuniste** : quand le rival actuel logue (son Index peut monter → reste rival ou est dépassé ; on rafraîchit `rivalIndexSnapshot`).

### 2.4 Algorithme `computeRival(U)`

```text
function computeRival(U):
    league = leagueOf(U.sex)
    if not eligibleForRanking(U):          // Index provisoire ou flaggé
        return { rivalUserId: null, state: "disabled_low_population" }
        // (on n'affiche pas de rival tant que l'Index n'est pas stable ; fallback "battre le pro")

    activePool = activeAthletes(league)     // efforts < 30 j, éligibles, != U
    if size(activePool) < 2:                // tout début de ligue
        return { rivalUserId: null, state: "disabled_low_population" }

    // candidats avec Index strictement supérieur
    candidates = [ a in activePool where a.index > U.index ]

    if candidates is empty:                 // U est n°1 des actifs
        return { rivalUserId: null, state: "is_number_one" }

    // plus petit Index strictement supérieur
    minIndex = min(c.index for c in candidates)
    tied = [ c in candidates where c.index == minIndex ]
    rival = argmax_recent_activity(tied)    // tie-break: activité la + récente, puis userId asc

    return {
        rivalUserId: rival.userId,
        rivalIndexSnapshot: rival.index,
        state: "active",
        recomputedAt: now()
    }
```

### 2.5 Détection du dépassement & célébration

Le **dépassement** est détecté au moment où l'Index de `U` change (déclencheur 1) :

```text
on indexChanged(U, oldIndex, newIndex):
    prev = loadRival(U)
    if prev.state == "active" and prev.rivalUserId != null:
        rivalNow = indexOf(prev.rivalUserId)
        if newIndex > rivalNow:                 // U vient de passer devant son rival
            emit OVERTOOK_RIVAL(U, prev.rivalUserId)   // carte de célébration côté U
            scheduleOptionalPush(prev.rivalUserId, "rival_overtaken_you", U)  // §6, optionnel & plafonné
    newRival = computeRival(U)
    save(U, newRival)
    if newRival.state == "active" and newRival.rivalUserId != prev.rivalUserId:
        emit NEW_RIVAL(U, newRival.rivalUserId) // "Nouveau rival : X (+Δ pts)"
```

- **Carte de célébration (côté `U`)** : « Tu as dépassé [Nom] ! » + animation + immédiatement **« Nouveau rival : [Nom] (+Δ pts) »** pour relancer la boucle (jamais de vide après une victoire).
- **Push au dépassé** (`rival_overtaken_you`) : **optionnel** (réglable, OFF possible), **plafonné** (max 1/jour par utilisateur dépassé, jamais entre quiet hours), ton **positif et non culpabilisant** : « [Nom] vient de passer devant. Reprends ta place quand tu veux. » Jamais « tu vas te faire dépasser », jamais de minuteur, jamais de honte.

### 2.6 Cas limites (table de décision)

| Situation | `state` | Affichage côté utilisateur |
|---|---|---|
| Rival normal trouvé | `active` | Bloc rival : « Bats [Nom] — il n'est qu'à +Δ pts. » |
| **N°1 des actifs** (personne au-dessus) | `is_number_one` | « Tu es n°1 de ta ligue — défends ta place. » Cible : **record du monde / pro** + tes PR (renvoie vers endgame §7). |
| **< 2 athlètes actifs** (lancement) | `disabled_low_population` | Pas de rival. Fallback : **« Bats le pro »** sur un WOD + chasse tes propres PR. |
| **Index provisoire** (`isProvisional`) | `disabled_low_population` | « Complète ton Index pour débloquer ton rival. » (incite à logger → boucle). |
| **Rival devient inactif** (>30 j sans effort) | recalcul auto → `active` ou autre | Réassignation silencieuse au suivant actif au prochain recalcul (batch quotidien). |
| **Rival a quitté / supprimé son compte** | recalcul auto | Réassignation au suivant actif. Si `rivalUserId` introuvable → `computeRival`. |
| **Rival masque son profil** (`visibility` futur) | non éligible | Exclu du pool, réassignation. |
| **Rival flaggé anti-triche** | non éligible | Exclu du pool (préserve l'honnêteté). |
| **Égalité parfaite d'Index** | `active` | Voir tie-break §2.1 (activité récente). |

> **Honnêteté :** on ne fabrique jamais un faux rival (bot, valeur inventée). Si aucun rival réel n'existe, on bascule honnêtement sur n°1 / pro / PR.

---

## 3. Rangs (paliers d'Index)

> Source : §9.2. Bornes verrouillées dans le cahier — reprises **à l'identique**.

> **Note display-v2 (2026-06-24).** Le **rang affiché** dérive désormais de l'OVR /100 (`display-v2`, cf. sport-science §4.4)
> via `rankFromIndex`. La **table de bornes faisant autorité est dans le code** : `packages/contracts/src/enums/index.ts`
> (`RANK_BANDS`). Bornes /100 recalibrées : `rookie [40,44)` · `bronze [44,52)` · `silver [52,64)` · `gold [64,73)` ·
> `platinum [73,85)` · `diamond [85,92)` · `elite [92,100]`. Ancrages : médian ~57 → **silver**, BON ~77 → **platinum**,
> élite nationale ~88 → **diamond**, pro ~93 → **elite**. La table /1000 ci-dessous reste la lecture **interne** historique
> et n'est plus la source du rang affiché ; `RANK_ORDER` (l'ordre des 7 rangs) est **inchangé**.

### 3.1 Bornes & cosmétiques

| Rang | Index | Convention de borne | Déblocage cosmétique | Célébration |
|---|---|---|---|---|
| **Rookie** | 0 – 149 | `[0, 150)` | tenue de départ | accueil onboarding |
| **Bronze** | 150 – 299 | `[150, 300)` | cadre bronze + teinte | montée de rang (moyenne) |
| **Argent** | 300 – 449 | `[300, 450)` | cadre argent + accessoire | montée de rang (moyenne) |
| **Or** | 450 – 599 | `[450, 600)` | cadre or + effet aura léger | grande célébration |
| **Platine** | 600 – 749 | `[600, 750)` | cadre platine + particules | grande célébration |
| **Diamant** | 750 – 899 | `[750, 900)` | cadre diamant + animation | grande célébration |
| **Élite** | 900 – 1000 | `[900, 1000]` | **cadre prestige** + aura exclusive | célébration maximale + entrée endgame |

- **Convention de borne** : `[min, max)` (max exclusif) sauf Élite `[900, 1000]` inclusif. Évite l'ambiguïté à 150, 300, etc. À implémenter strictement ainsi.
- **Anti-régression de rang** : le rang affiché ne **redescend jamais** d'un cran à cause d'un mauvais jour, puisque l'Index lui-même ne baisse jamais (meilleur effort retenu, §5.2 cahier). Si un recalcul de calibration (`f`/poids versionnés) faisait baisser l'Index, **le rang acquis reste affiché** avec une note honnête « recalibrage du barème » (jamais de rétrogradation punitive surprise ; voir §10 mapping). **[MVP : règle ; communication = P2]**

### 3.2 Barre « prochain rang » **[MVP]**

Toujours visible sur le hub (§9.3 cahier).

```text
nextRankFloor   = borne basse du rang suivant   // ex. Platine = 600
pointsToNext    = max(0, nextRankFloor - currentIndex)
progressInRank  = (currentIndex - currentRankFloor) / (nextRankFloor - currentRankFloor)
label           = "Encore " + pointsToNext + " pts avant " + nextRankName
```
- Si rang = Élite : pas de « prochain rang » → bascule sur **objectifs endgame** (§7) : « % vers record du monde », top-100.

### 3.3 Index projeté (simulation) **[MVP]**

> Source : §4.3 levier 3. Chiffre la récompense de travailler sa faiblesse.

Donne « ton Index **si** l'attribut A atteignait la cible Y », sans modifier l'Index réel.

```text
function projectedIndex(U, attribute A, targetScore Y):
    scores = currentAttributeScores(U)        // sur attributs débloqués
    if A not unlocked: traiter A comme nouvellement débloqué à Y
    scores[A] = max(scores[A], Y)             // simulation : on ne fait jamais baisser
    return weightedAverage(scores, weights(U.goal))   // même formule que l'Index réel (§5.2)
```

**Cibles `Y` suggérées par l'app (pour rendre la projection actionnable) :**
- `Y = score de l'attribut le plus fort de U` → « amène ta Force au niveau de ton Engine ».
- `Y = borne du prochain rang` (si atteignable via cet attribut).
- `Y = percentile rond supérieur` (ex. passer top 25 % sur cet attribut).

Affichage : « Amène ta **Force** à **620** → Index projeté **~580 (PLATINE)**. Travaille [séances suggérées]. » → renvoie au moteur de reco (§10 cahier). **L'Index projeté est toujours marqué « projeté / simulation » — jamais confondu avec l'Index réel (honnêteté).**

---

## 4. Badges & trophées

> Source : §12. Salle des trophées (profil public). Catégories : Progression / Collection / Performance / Régularité / Social. Chaque déblocage = animation + carte partageable ; les badges rares débloquent des cosmétiques.

### 4.1 Conventions

- **`id`** : `snake_case` stable (clé permanente, ne change jamais).
- **`condition`** : règle **évaluable** (déclencheur + prédicat). Évaluée à chaque événement pertinent (log, recalcul Index, batch quotidien).
- **`rarity`** : `common` / `rare` / `epic` / `legendary` (pilote la couleur/effet de la carte et l'éventuel cosmétique).
- **`cosmeticUnlock`** : id de cosmétique avatar débloqué (ou `null`).
- **Honnêteté :** les badges de niveau réel (percentile, Grand Chelem) ne sont **jamais** attribués par flatterie ; conditionnés à des résultats **non flaggés** et **non provisoires**.
- **Idempotence :** un `UserBadge` ne se débloque qu'une fois (`unique(userId, badgeId)`). Un badge ne se **retire jamais** une fois obtenu (le score ne baisse jamais → l'accompli reste).

### 4.2 Catalogue — Progression

| id | rareté | condition (évaluable) | cosmétique | phase |
|---|---|---|---|---|
| `rank_bronze` … `rank_elite` | common→legendary | franchir la borne basse du rang X (§3.1) pour la 1ʳᵉ fois | cadre du rang | **[MVP]** |
| `pct_top25` | rare | `HybridIndex.percentile ≥ 0.75`, Index non provisoire | teinte | **[MVP]** |
| `pct_top10` | epic | `percentile ≥ 0.90` | accessoire | **[MVP]** |
| `pct_top5` | epic | `percentile ≥ 0.95` | aura légère | **[MVP]** |
| `pct_top1` | legendary | `percentile ≥ 0.99` | aura prestige | **[MVP]** |
| `first_complete_index` | common | Index passe `isProvisional=false` (radar suffisamment couvert) | — | **[MVP]** |

> Les paliers de percentile sont **monotones acquis** : une fois `top10` obtenu, il reste, même si la population grandit et fait varier le percentile instantané (sinon on punirait l'arrivée de nouveaux users → malsain). Le **badge de percentile en cours** affiché sur le profil reflète le percentile *actuel* ; le **badge historique** reste dans la salle des trophées.

### 4.3 Catalogue — Collection

| id | rareté | condition | cosmétique | phase |
|---|---|---|---|---|
| `wod_first_logged` | common | 1ᵉʳ `WodResult` validé (tout WOD) | — | **[MVP]** |
| `wod_done_{wodId}` | common | ≥ 1 résultat sur ce WOD de référence | — | **[MVP]** (au moins pour les 15 benchmarks) |
| `all_no_equipment` | rare | ≥ 1 résultat sur les **7 WODs sans matériel** | accessoire | **[MVP]** |
| `all_with_equipment` | rare | ≥ 1 résultat sur les **8 WODs avec matériel** | accessoire | **[P2]** |
| **`grand_chelem`** | legendary | **battre le `proReference` sur les 15 WODs** (résultat ≥ niveau pro sur chacun, non flaggé) | **aura Grand Chelem** | **[P2]** (endgame — voir §7) |
| `collector_all_15_logged` | epic | ≥ 1 résultat sur **les 15** WODs de référence | cadre collectionneur | **[MVP léger]** (collection seule, sans niveau pro) |

### 4.4 Catalogue — Performance

| id | rareté | condition | cosmétique | phase |
|---|---|---|---|---|
| `pr_first` | common | 1ᵉʳ PR enregistré | — | **[MVP]** |
| `beat_pro_{wodId}` | epic | résultat ≥ `proReference` sur ce WOD (par sexe) | — | **[P2]** (badge nommé ; le %-vers-pro existe en MVP via §7) |
| `pft_sub_x` | epic | PFT (Benchmark hybride) sous un seuil cible défini par sport-science | accessoire | **[P2]** |
| `pr_streak_3` | rare | 3 PR sur 3 logs distincts en 30 j | — | **[P2]** |

### 4.5 Catalogue — Régularité (sain)

| id | rareté | condition | cosmétique | phase |
|---|---|---|---|---|
| `streak_7` | common | streak intelligent (§5) atteint **7** | — | **[MVP]** |
| `streak_30` | rare | streak atteint **30** | accessoire | **[MVP]** |
| `streak_100` | epic | streak atteint **100** | aura régularité | **[P2]** |
| `wods_logged_10` / `_50` / `_100` | common→rare | N `WodResult` validés cumulés | — (50/100 = accessoire) | **[MVP]** (10), **[P2]** (50/100) |
| `comeback` | common | re-log après ≥ 14 j d'inactivité | — | **[P2]** |

> **`comeback` est un badge de bienvenue, jamais une honte.** Il célèbre le retour. Aucun badge ne pénalise une pause.

### 4.6 Catalogue — Social **[P2]** (tout différé Phase 2, cf. §19 cahier)

| id | rareté | condition | cosmétique | phase |
|---|---|---|---|---|
| `social_first_challenge` | common | 1ᵉʳ défi envoyé | — | **[P2]** |
| `social_beat_friend` | rare | battre un ami (Index ou WOD) | — | **[P2]** |
| `social_recruit` | rare | un filleul crée un Index complet (recruter un rival) | accessoire | **[P2]** |
| `social_kudos_given_10` | common | 10 kudos donnés | — | **[P2]** |

### 4.7 Rareté → effet visuel & cosmétique

| rareté | carte | cosmétique typique |
|---|---|---|
| common | couleur neutre, anim courte | souvent aucun |
| rare | couleur accentuée | teinte / accessoire mineur |
| epic | particules | accessoire visible |
| legendary | aura animée + son dédié | aura/cadre prestige (Grand Chelem, top 1 %) |

---

## 5. Streak intelligent (sain)

> Source : §4.6. **Régularité, pas volume.** Repos planifié maintient la série. **Jamais** de notif culpabilisante.

### 5.1 Définitions

- **Unité de streak = la SEMAINE**, pas le jour (on récompense la régularité hebdomadaire, jamais l'entraînement quotidien qui pousserait au surentraînement).
- **Semaine « réussie »** = l'utilisateur a logué **≥ `weeklyGoal` efforts** dans la semaine ISO (par défaut `weeklyGoal = 3`, aligné sur « ~3 entraînements suffisent », configurable 2–5).
- **Streak** = nombre de semaines réussies **consécutives**.
- **Jour de repos planifié** : concept hérité du cahier — concrètement, **une semaine peut être « gelée » (frozen) sans casser la série** via un **jeton de repos**.

### 5.2 Jeton de repos (« streak freeze » sain)

- L'utilisateur dispose de **1 jeton de repos par mois glissant** (configurable, défaut 1). Un jeton **gèle une semaine** : la semaine non atteinte ne casse pas la série.
- Le jeton se **régénère automatiquement** (pas d'achat, pas de monnaie — 100 % gratuit, aucun dark pattern marchand).
- Une **pause planifiée déclarée** (l'utilisateur indique « je suis en repos / blessé / vacances » sur N semaines) **met la série en pause sans la casser ni la décompter** — on ne punit jamais la récupération.

### 5.3 Algorithme d'évaluation (batch hebdomadaire, fin de semaine ISO)

```text
on weekEnd(U, week):
    effortsThisWeek = count(WodResult where U, timestamp in week, not isFlagged)
    if effortsThisWeek >= U.weeklyGoal:
        U.streak += 1
        emit STREAK_INCREASED(U, U.streak)          // récompense discrète
        checkStreakBadges(U)                          // 7? 30? 100? (en semaines équivalentes, voir note)
    else if U.plannedRest covers week OR consume(freezeToken(U)):
        // série gelée : ni +1 ni reset
        keep U.streak
    else:
        if U.streak > 0:
            U.bestStreak = max(U.bestStreak, U.streak)
            U.streak = 0
            // AUCUNE notification de honte. Au plus, un message neutre dans l'app au retour.
```

> **Note d'unité des badges :** `streak_7 / 30 / 100` du §4.5 s'expriment en **jours de référence** dans le cahier ; on les mappe en **équivalents de régularité** : `streak_7` = 1 semaine réussie, `streak_30` ≈ 4 semaines consécutives, `streak_100` ≈ 14 semaines consécutives. Les libellés affichés restent « 7 / 30 / 100 jours » pour la familiarité, mais la **mécanique sous-jacente est hebdomadaire** (anti-surentraînement). *(À valider avec le designer pour le wording.)*

### 5.4 Règles anti-dark-pattern du streak

- **Jamais** de notification « tu vas perdre ta série », **jamais** de minuteur anxiogène, **jamais** de compte à rebours.
- La perte d'une série **n'efface aucun acquis** (rang, badges, Index intacts) et **`bestStreak` est conservé** et célébré.
- On **n'incite jamais à logger un effort bidon** juste pour sauver la série (la condition est « effort réel non flaggé »). Le but est la santé, pas le chiffre.

---

## 6. Notifications & ré-engagement

> Source : §14. **Plafond global : ≤ 1–2 push/jour.** Toutes configurables. Quiet hours par défaut. **Jamais** de honte de streak ni de FOMO punitif.

### 6.1 Réglages globaux (`NotificationPrefs`, §16)

| Réglage | Défaut | Note |
|---|---|---|
| Plafond global | **2/jour** (cible 1/jour en régime établi) | compteur quotidien serveur ; au-delà → notifs basse priorité **abandonnées** (pas reportées en file) sauf priorité haute. |
| Quiet hours | **21:00 → 08:00** (fuseau de l'appareil) | aucune notif envoyée ; les déclenchées pendant la fenêtre sont **annulées** (pas accumulées). |
| Granularité | **on/off par type** | chaque ligne du tableau §6.3 a son toggle. |
| Désactivation totale | possible | aucun « êtes-vous sûr ? » culpabilisant. |

### 6.2 Priorités & arbitrage (quand plusieurs candidates le même jour)

| Priorité | Types | Règle |
|---|---|---|
| **Haute** | `you_overtook_rival` (célébration), `rank_up_imminent` (proche d'un rang) | passe en premier ; compte dans le plafond. |
| **Moyenne** | `rival_overtaken_you`, `friend_PR`, `challenge_received` | envoyée si plafond non atteint. |
| **Basse** | `suggested_session`, `weekly_recap` | abandonnée si plafond atteint (jamais empilée). |

> Si deux candidates de même priorité : on garde **la plus actionnable / positive**, on jette l'autre (pas de rafale).

### 6.3 Taxonomie (reprise & enrichie du tableau §14)

| Type | Déclencheur (condition évaluable) | Ton / texte exemple | Fréquence / plafond | Configurable | Phase |
|---|---|---|---|---|---|
| `rival_overtaken_you` | un rival/proche passe devant `U` (Δ Index franchi) | « [Nom] vient de passer devant. Reprends ta place quand tu veux. » | **max 1/jour**, jamais 2 jours d'affilée sur le même dépasseur | oui | **[MVP]** |
| `you_overtook_rival` | `OVERTOOK_RIVAL` (§2.5) | « Tu as dépassé [Nom] ! Nouveau rival : [Nom2] (+Δ). » | par événement, plafond global | oui | **[MVP]** |
| `suggested_session` | **aucune** activité loguée depuis ≥ 24 h ET pas en quiet hours ET pas en pause planifiée | « Prêt pour [séance] ? ~20 min, cible ta [attribut faible]. » | **1/jour max** | oui | **[MVP]** |
| `weekly_recap` | fin de semaine ISO | « Ta semaine : +Δ Index, [WOD] battu, série [N]. » (positif uniquement) | **1/semaine** | oui | **[MVP léger]** / **[P2]** complet |
| `rank_up_imminent` | `pointsToNext ≤ 15` ET pas notifié pour ce rang | « Encore X pts avant PLATINE — un bon WOD peut suffire. » | **1× par rang** (anti-spam : ne re-notifie pas tant que le rang n'est pas franchi/réinitialisé) | oui | **[MVP]** |
| `percentile_near` | franchit à ≤ 1 pt d'un palier (top 25/10/5/1) | « Tu es tout proche du top 10 % ! » | **1× par palier** | oui | **[P2]** |
| `friend_active_PR` | un suivi logue un PR / action sociale | « [Ami] a battu son record sur [WOD]. Va réagir. » | **max 1/jour agrégé** (digest si plusieurs) | oui | **[P2]** |
| `challenge_received` | défi reçu | « [Ami] te défie sur [WOD]. » | par événement, plafond global | oui | **[P2]** |
| `challenge_result` | défi résolu | « Résultat du défi vs [Ami] : … » | par événement | oui | **[P2]** |
| `freshness_nudge` | un benchmark clé > 8–12 sem. (§5.4 cahier) | « Ton [WOD] date de 10 semaines — envie d'un nouveau PR ? » | **max 1/semaine**, jamais culpabilisant | oui | **[P2]** |
| `comeback_welcome` | retour après ≥ 14 j d'absence (ouverture app) | in-app de préférence : « Content de te revoir. On reprend en douceur ? » | **1× par retour** | oui | **[P2]** |

### 6.4 Règles anti-dark-pattern (impératives)

- **Interdits absolus :** « tu vas perdre ta série », compte à rebours anxiogène, « X personnes te dépassent en ce moment », notifications nocturnes, ré-engagement par culpabilité, fréquence agressive de réactivation (pas de « on te relance tous les jours si tu pars »).
- **Dégressivité du ré-engagement** : si `suggested_session` est ignorée **3 jours de suite**, on **réduit** sa fréquence (1×/3 jours, puis 1×/semaine), on ne l'augmente jamais. On respecte le silence de l'utilisateur.
- **Tout texte est positif et actionnable** : il propose une action atteignable, ne menace jamais d'une perte.
- **Honnêteté** : aucune notif ne ment sur le niveau, la position ou la rareté.

---

## 7. Endgame (rétention des experts — §4.4)

> Quand le rival se raréfie (Diamant/Élite, ou n°1 d'une petite ligue), on maintient l'obsession **sans** quêtes ni saisons (verrous), par des objectifs **absolus et honnêtes**.

| Mécanique | Rendu actionnable | Données | Phase |
|---|---|---|---|
| **Grand Chelem** | checklist visible des 15 WODs « pro battu / pas encore » + carte de progression « 11/15 ». Badge `grand_chelem` (legendary) + aura. | `proReference` par WOD/sexe, `WodResult` non flaggés. | **[P2]** |
| **Top-100 mondial par sexe** | classement absolu (le seul) ; objectif « entrer / défendre le top-100 ». Notif `rank_up_imminent` adaptée (« +Δ pour entrer top-100 »). | zset Redis ligue, rang absolu. | **[P2/P3]** |
| **Top-100 par WOD** | 15 leaderboards absolus ; « tu es 73ᵉ mondial sur Fran — +0:12 pour le top-50 ». | 15 zsets WOD (§15 cahier). | **[P2/P3]** |
| **% vers le record du monde** | sur chaque WOD : barre « 88 % du record du monde » ; cible ultime affichée. (Le « % vers pro » existe dès le MVP comme variante.) | `proReference` + record absolu connu. | **[MVP]** (% vers pro) / **[P3]** (record monde) |
| **Cadence de re-test (PR-chasing)** | rappel doux quand un benchmark fondateur vieillit (`freshness_nudge`) ; « chasse ton PR » comme moteur principal en l'absence de rival. | `WodResult.timestamp`, meilleur retenu. | **[MVP]** (mécanique) |
| **Statut ambassadeur** | aura/cadre exclusifs pour le top (ex. top 1 % ou top-100) → devient moteur de communauté (modèle, pas un classement à fuir). | percentile/rang + cosmétique exclusif. | **[P3]** |

> **Anti-vide :** un Élite n°1 doit toujours voir **au moins une marche** : prochain WOD où battre le pro, prochain palier de % vers record, prochaine place mondiale, prochain PR à rafraîchir. C'est la version « experte » des objectifs proximaux (§8).

---

## 8. Courbes de progression & objectifs proximaux

> Doctrine §3.4 : **toujours une prochaine marche atteignable.**

### 8.1 Forme de la courbe (héritée du score, §5.2)

La courbe `f(percentile)→sous_score` est **calibrée** : **gains rapides au milieu** (dopamine débutant), **lents aux extrêmes** (le haut est dur, ce qui protège la crédibilité du top). Conséquences gamification :

- **Début (Rookie→Or, médiane ≈ 450)** : chaque séance fait bouger l'Index de façon nette → renforcement fréquent.
- **Haut (Platine→Élite)** : la progression d'Index ralentit ; on **remplace la récompense « gros Δ Index » par des récompenses discrètes** : percentile fin, % vers pro/record, places mondiales, PR, Grand Chelem (§7). Le sentiment de progrès ne s'éteint jamais même quand l'Index plafonne.

### 8.2 Garantie « prochaine marche » (algorithme de sélection de l'objectif affiché)

À chaque ouverture du hub, l'app affiche **un objectif proximal principal**, choisi par priorité décroissante d'**atteignabilité + impact** :

```text
function nextStep(U):
    if U.index isProvisional: return "Complète ton Index (+1 attribut)"     // boucle d'onboarding
    if rival.state == "active" and rival.delta <= 30: return "Bats {rival} (+{delta})"
    if pointsToNextRank <= 30: return "Encore {pts} avant {nextRank}"
    if existe attribut faible A avec projectedIndex(U,A,target) - U.index >= 10:
        return "Travaille {A} → Index projeté {x}"
    if existe palier percentile à <= 1 pt: return "Tout proche du top {p} %"
    if existe benchmark stale: return "Rafraîchis ton {WOD} — vise un PR"
    // endgame fallback (Élite/n°1)
    return endgameNextStep(U)   // pro à battre / place mondiale / % record
```

- **Seuils d'atteignabilité** (`≤ 30 pts`, `≤ 1 pt percentile`) garantissent que la marche proposée est **crédible** : on ne propose pas « +200 pts ». Si rien n'est à ≤ 30 pts, on bascule sur le ciblage d'axe (Index projeté) qui décompose un grand écart en sous-objectifs.
- **Honnêteté :** une marche n'est affichée que si elle est réellement franchissable par l'effort proposé (pas de carotte mensongère).

---

## 9. Octalysis — couverture (contrôle qualité)

| Ressort (core drive) | Mécanique HYBRID INDEX | Sain ? |
|---|---|---|
| Accomplissement (CD2) | Index, rangs, barre prochain rang, badges, PR | oui |
| Appartenance / comparaison (CD5) | ligues, rival, classements publics, kudos | oui |
| Rareté / impatience (CD6) | paliers de percentile, top-100, Grand Chelem | oui (basée sur mérite réel, pas sur minuteurs) |
| Imprévisibilité (CD7) | **reveal** variable du score | oui (sur résultat réel) |
| Sens / empowerment (CD1) | « deviens un meilleur athlète », progression mesurable | oui |
| **Évité — Perte/évitement (CD8)** | **non utilisé en mode punitif** : pas de honte de streak, le score ne baisse jamais, repos protégé | dark pattern proscrit |
| **Évité — Pénurie toxique / FOMO** | pas de saisons, pas de fenêtres limitées punitives | verrou respecté |

---

## 10. Mapping avec le modèle de données (§16)

Champs **existants** réutilisés et **ajouts** requis par les mécaniques de ce document.

| Mécanique | Entité | Champs requis (★ = ajout par rapport au §16) |
|---|---|---|
| Boucle / reveal | `WodResult` | `subScore`, `percentile`, `attributesAffected[]`, `isFlagged`, `timestamp` |
| Rival | `Rival` | `userId`, `rivalUserId` (nullable), `recomputedAt`, ★`rivalIndexSnapshot`, ★`state` (`active`/`is_number_one`/`disabled_low_population`) |
| Rival — pool actif | `WodResult`, `Profile` | `timestamp` (≤30 j), `sex`, `visibility`, `HybridIndex.isProvisional` ; ★ zset Redis `league:{sex}:active` |
| Rangs | `Profile.rank`, `HybridIndex.value` | rang dérivé des bornes §3.1 ; ★ `rankAchievedHistory[]` (pour ne jamais rétrograder l'affiché) |
| Barre prochain rang / Index projeté | `HybridIndex` | `value`, `projectedValue` (déjà prévu), `percentile`, `radarCoverage`, `isProvisional` ; `AttributeScores[*]` |
| Badges | `Badge` | `id`, `category`, `condition`, `rarity`, `cosmeticUnlock` ; ★ `phase` (mvp/p2/p3) recommandé |
| Badges débloqués | `UserBadge` | `userId`, `badgeId`, `unlockedAt` ; ★ contrainte `unique(userId, badgeId)` |
| Cosmétiques débloqués | `Avatar` | `unlockedCosmetics[]`, `equippedCosmetics` |
| Streak | ★ `Streak` (nouvelle entité) ou champs sur `Profile` | ★`current`, ★`best`, ★`weeklyGoal` (défaut 3), ★`freezeTokens`, ★`freezeTokensRefreshedAt`, ★`plannedRest` (intervalles), ★`lastWeekEvaluated` |
| Percentile acquis | `UserBadge` (`pct_top*`) + `HybridIndex.percentile` | badge = acquis monotone ; percentile affiché = instantané |
| Notifications | `NotificationPrefs` | par type on/off + quiet hours (déjà prévu) ; ★ `dailyCap` (défaut 2), ★ `lastSentAt` par type (anti-spam), ★ `quietHoursStart/End` |
| Endgame | `ReferenceDistribution.proReference`, zsets WOD | Grand Chelem, % vers pro/record, top-100 |
| Anti-triche (préserve honnêteté) | `WodResult.isFlagged`, `source` | exclusion des classements/rival/badges de niveau |

> **Aucune entité supprimée n'est réintroduite** : pas de `Quest`, `Season`, ni pools/tiers de ligue (conforme à la note finale du §16).

---

## Résumé exécutif (8–12 lignes)

1. La **boucle Hooked** est solo-suffisante : déclencheur cadré → logger un WOD → reveal variable → investissement (radar/rang/badges/avatar), avec un **contrat de récompense** garantissant qu'aucun log n'est « plat » (fallback objectif proximal obligatoire).
2. Le **RIVAL** est entièrement spécifié (pseudo-algo `computeRival`, détection de dépassement, tous les cas limites n°1 / <2 actifs / inactif / parti / flaggé / provisoire), avec push au dépassé **optionnel, plafonné, positif**.
3. **Rangs** Rookie→Élite aux bornes exactes du cahier (`[min,max)`, Élite inclusif), barre « prochain rang » et **Index projeté** (simulation honnête, jamais confondue avec l'Index réel).
4. **Catalogue de badges** complet, condition évaluable par badge, rareté, cosmétique, et marquage **MVP/P2/P3** (Grand Chelem et social en P2 ; rang/percentile/streak/collection en MVP).
5. **Streak hebdomadaire** (régularité, pas volume) avec **jeton de repos** gratuit et **pause planifiée** qui protègent la récupération ; perte de série jamais punitive, `bestStreak` conservé.
6. **Notifications** : plafond ≤ 2/jour (cible 1), quiet hours par défaut, priorités, **dégressivité du ré-engagement**, et liste explicite des **interdits anti-dark-pattern**.
7. **Endgame** actionnable (Grand Chelem, top-100 mondial/par WOD, % vers record, cadence de re-test, ambassadeur) garantissant « toujours une marche » même à l'Élite n°1.
8. **Mapping data** précis : ajouts requis (`Streak`, `Rival.state/snapshot`, `NotificationPrefs.dailyCap`, `phase` de badge) sans réintroduire aucune entité verrouillée.

### Alertes / incohérences détectées

- **Unité de streak vs libellés badges.** Le cahier parle de streaks « 7 / 30 / 100 **jours** » (§12) mais aussi de « régularité, pas volume » et « jour de repos hebdo » (§4.6). Pour rester sain (anti-surentraînement) j'ai défini la mécanique **hebdomadaire** et mappé les libellés « 7/30/100 jours » sur des équivalents de régularité. **À trancher avec le designer** (garder le wording « jours » ou afficher « semaines »). C'est le seul point où l'esprit (§4.6) prime sur la lettre (§12).
- **Badges en MVP vs Phase 2.** Le §19 repousse « badges complets » en P2. J'ai isolé un **sous-ensemble strictement nécessaire à la boucle solo** en MVP (rang, percentile, collection, streak, PR) ; les badges **sociaux et Grand Chelem** restent en P2. À valider : ce sous-ensemble MVP est-il dans le périmètre de la thin slice ? (Recommandé : oui, car ce sont les récompenses de la boucle de rétention, pas du social.)
- **Percentile acquis vs instantané.** Risque malsain évité : si le percentile-badge se retirait quand la population grandit, on punirait l'arrivée de nouveaux users. Décision : **badge de percentile monotone acquis** (jamais retiré) + percentile *instantané* affiché à côté. À confirmer côté produit.
- **Recalibrage du barème (`f`/poids versionnés).** Un recalcul d'historique pourrait théoriquement faire baisser un Index/rang. J'ai posé la règle « le rang acquis reste affiché + note honnête », mais **la stratégie exacte de communication doit être décidée** avec l'architecte (Service Score versionné, §15) pour ne jamais créer de rétrogradation surprise (dark pattern involontaire).
- **Aucun dark pattern ni mécanique verrouillée détecté** dans le reste de la spec : pas de quêtes, saisons, fatigue, catégories de poids ; le score ne baisse jamais ; toutes les notifs sont positives, plafonnées, configurables.
