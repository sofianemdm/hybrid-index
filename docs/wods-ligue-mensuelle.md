# WODs « Ligue du mois » — 5 séances dédiées (sport-science)

Statut : SPEC (données prêtes à implémenter). Aucun fichier de code modifié.
Auteur : agent `sport-science`. Date : 2026-06-26.

## 1. Objet et règles

Ces **5 WODs sont créés UNIQUEMENT pour la « Ligue du mois »**. Ils **remplacent
intégralement** les WODs benchmark actuellement imposés en Ligue
(`burpees_7min`, `max_air_squats_2min`, `max_pushups`, `profil_express`, `run_1k`).
On ne réutilise **aucun** WOD existant pour la Ligue.

Contraintes respectées (cahier des charges produit) :
- **JAMAIS d'EMOM** dans les WODs imposés de la Ligue (contrainte produit permanente, humain,
  27 juin 2026). Formats autorisés : **AMRAP** ou **for time (RFT / chipper)** uniquement.
  → l'ancienne semaine 4 EMOM (`league_power_emom`) est remplacée par `league_power_amrap` (AMRAP 10 min).
- 100 % **sans matériel** (poids du corps + course en option) → `requiresEquipment: false`.
- Durée cible **8–15 min** chacun (time cap inclus).
- **5 semaines = 5 qualités différentes** : Vitesse, Endurance (moteur), Force-endurance,
  Puissance, Hybride. Chaque semaine, un profil d'athlète différent peut briller.
- Mouvements pris **exclusivement** dans `movements.data.ts` (sauf 1 manquant signalé en §7).

Convention de scoring (identique aux 15 benchmarks, cf. `wods.data.ts`) :
- `scoreType: "time"` → `dir = -1` (plus bas = mieux).
- `scoreType: "reps"` → `dir = +1` (plus haut = mieux). Inclut AMRAP (score = reps totales).
- Modèles dispo : `lognormalFromMedian(median, sigmaLn)` (median = P50/intermédiaire),
  `normal(mu, sigma)` (mu = P50 reps), `points([[p,r]...])` (table percentile→brut).
- Repères de spread : pour un log-normal, P10/P90 ≈ median × exp(∓1.2816·σ_ln).
  Pour un normal, P10/P90 ≈ mu ∓ 1.2816·σ.

Repères de calibration empruntés à l'existant (pour rester dans les ordres de grandeur) :
`burpees_7min` H `normal(70, 18)`, `max_air_squats_2min` H `normal(50, 12)`,
`run_1k` H `lognormalFromMedian(300, 0.22)`, `profil_express` (pointTable ~3–10 min),
`benchmark_zero` (pointTable ~9–15 min). On reste dans cette même enveloppe.

---

## 2. Vue d'ensemble — répartition sur les 5 semaines

| Sem. | id | Nom FR | Qualité dominante | Format | scoreType | Sens | Durée |
|------|----|--------|-------------------|--------|-----------|------|-------|
| 1 | `league_sprint_ladder` | La Flèche | **Vitesse** | Intervalles course | `time` | bas = mieux | ~9–12 min |
| 2 | `league_engine_12` | Le Moteur | **Endurance (aérobie)** | AMRAP 12 min | `reps` | haut = mieux | 12 min |
| 3 | `league_grind_squats` | Le Pilier | **Force-endurance** (bas du corps) | AMRAP 10 min | `reps` | haut = mieux | 10 min |
| 4 | `league_power_amrap` | La Détente | **Puissance** | AMRAP 10 min | `reps` | haut = mieux | 10 min |
| 5 | `league_hybrid_chipper` | Le Chaos | **Hybride / mixte** | RFT (chipper) | `time` | bas = mieux | ~10–15 min |

Logique d'attribution : on alterne **time/reps** et **haut/bas du corps** d'une
semaine à l'autre pour qu'aucun profil ne domine deux semaines de suite, et on place
l'épreuve la plus longue/complète (hybride) en semaine 5, comme « finale » du mois.

> **Note d'implémentation (rotation Ligue).**
> Le pool actuel (`league-lifecycle.service.ts` → `bodyweightWodPool()`) sélectionne
> *tous* les WODs `requiresEquipment:false` non exclus. Pour que **seuls ces 5** soient
> imposés en Ligue, deux options (décision d'ingénierie, hors scope sport-science) :
> (a) ajouter les 15 anciens bodyweight à `LEAGUE_EXCLUDED_WODS` et seeder ces 5 ;
> (b) introduire un flag `isLeagueOnly` et filtrer le pool dessus. L'option (b) est plus
> propre et évite de polluer l'Index (cf. §6). Voir aussi §7 (champs DB à prévoir).

---

## 3. Spécification détaillée des 5 WODs

### Semaine 1 — `league_sprint_ladder` « La Flèche » (VITESSE)

- **Qualité** : vitesse / capacité anaérobie lactique. L'athlète rapide et nerveux brille.
- **Structure** : intervalles de course en échelle, **for time** (chrono total course seul,
  les marches de récup ne comptent PAS dans le score affiché mais sont imposées).
- **Contenu EXACT** :
  - 100 m sprint — 30 s repos
  - 200 m sprint — 45 s repos
  - 300 m sprint — 60 s repos
  - 400 m sprint — 60 s repos
  - 300 m sprint — 45 s repos
  - 200 m sprint — 30 s repos
  - 100 m sprint
  - **Score = somme des temps de course uniquement** (1 600 m couru). Time cap 12 min.
- **Mouvements** : `run` / `sprint` (déjà mappés ; `sprint` weight speed 0.7).
- **scoreType** : `time` — **bas = mieux**.
- **targetAttributes** (primaire **speed**) :
  ```
  [ { attribute: "speed", estimated: false },
    { attribute: "engine", estimated: false } ]
  ```
- **Barème de référence** (temps de course cumulé, secondes) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 300 | 420 | 600 |
  | Femme | 345 | 480 | 690 |

  Justification : 1 600 m de sprint fractionné se court ~2–4 s/100 m plus vite qu'un
  1 600 m continu mais avec coût lactique élevé ; on se cale juste au-dessus du `run_1k`
  ×1,5 en allure. Intermédiaire H 420 s (~26 s/100 m moyen, départs/arrêts inclus).
- **Distribution recommandée** : `lognormalFromMedian(median = intermediate, 0.20)`.
  σ_ln 0,20 = même dispersion que `run_1k`-like mais un peu plus large (fractionné =
  technique de gestion, plus discriminant). Vérif : H P10 ≈ 420·exp(+1.2816·0.20) ≈ 543 s
  (proche de l'occasionnel), H P90 ≈ 420·exp(−1.2816·0.20) ≈ 325 s (proche du champion). OK.
  ```
  male:   { model: lognormalFromMedian(420, 0.20), hardMin: 270, hardMax: 900,  proReference: 290 }
  female: { model: lognormalFromMedian(480, 0.20), hardMin: 310, hardMax: 1020, proReference: 335 }
  ```

---

### Semaine 2 — `league_engine_12` « Le Moteur » (ENDURANCE / aérobie)

- **Qualité** : moteur aérobie soutenu sur 12 min. L'athlète d'endurance (gros VO2/seuil) brille.
- **Structure** : **AMRAP 12 min** d'un triplet cyclique léger et continu (pas de mouvement
  qui force l'arrêt) → score = **nombre de tours + reps partielles converties** (voir note).
- **Contenu EXACT (1 tour)** :
  - 200 m course (`run`)
  - 15 air squats (`air_squat`)
  - 10 burpees (`burpee`)
  - → répéter pendant 12 min. **Score = reps totales** (chaque mètre de course compte
    comme 1 unité de progression interne ; le score affiché à l'utilisateur = **nombre
    de tours complétés, à la décimale** — ex. 6,4 tours).
- **Mouvements** : `run`, `air_squat`, `burpee` (tous mappés).
- **scoreType** : `reps` (AMRAP) — **haut = mieux**.
- **targetAttributes** (primaire **engine**) :
  ```
  [ { attribute: "engine", estimated: false },
    { attribute: "muscular_endurance", estimated: false },
    { attribute: "hybrid", estimated: false } ]
  ```
- **Barème de référence** (en **tours** complétés ; 1 tour = 200 m + 15 squats + 10 burpees ≈ 90–100 s pour l'intermédiaire) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 9 | 6 | 4 |
  | Femme | 8 | 5.5 | 3.5 |

  Justification : à allure intermédiaire un tour ≈ 110–120 s → ~6 tours en 12 min. Le
  champion (moteur élite) tient ~75–80 s/tour → ~9 tours. Aligné sur la densité de
  `burpees_7min` (70 burpees/7 min ≈ 10/min) et `max_air_squats_2min`.
- **Distribution recommandée** : `normal(mu = intermediate, sigma)` **en tours**.
  σ choisie pour que P10/P90 collent aux paliers : H σ = 2.0 → P90 ≈ 6+1.28·2 ≈ 8.6 (~champion),
  P10 ≈ 3.4 (~occasionnel). OK.
  ```
  male:   { model: normal(6.0, 2.0), hardMin: 2.0, hardMax: 12.0, proReference: 9.5 }
  female: { model: normal(5.5, 1.9), hardMin: 1.5, hardMax: 11.0, proReference: 8.5 }
  ```
  > **Unité de saisie** : l'app demande le **nombre de tours (décimal)**. Si on préfère
  > saisir les reps brutes, prévoir une conversion reps→tours côté scoring
  > (1 tour = 225 unités : 200 m + 25 reps), **avant** d'appeler `percentile()`.
  > Recommandation sport-science : saisir en **tours** (lisible, robuste).

---

### Semaine 3 — `league_grind_squats` « Le Pilier » (FORCE-ENDURANCE bas du corps)

- **Qualité** : endurance-force du bas du corps + gainage. L'athlète « jambes / volume »
  (cuisses solides, tolérance à la brûlure) brille — typiquement pas le même profil que sem. 1/2.
- **Structure** : **AMRAP 10 min**, doublet bas-du-corps lourd en volume + un mouvement de
  stabilité unilatérale. Score = **reps totales**.
- **Contenu EXACT (1 tour)** :
  - 20 fentes marchées (`lunge`, 10/jambe)
  - 15 air squats (`air_squat`)
  - 10 pistol squats (`pistol_squat`, 5/jambe) — **scaling autorisé** : pistol assisté
    ou « step-down » compte 0,5 rep (géré côté barème/scaling, comme la décote Scaled ×0.9).
  - → AMRAP 10 min. **Score = reps totales** (toutes reps comptées : 45 reps/tour à plein).
- **Mouvements** : `lunge`, `air_squat`, `pistol_squat` (tous mappés ; tous bas-du-corps,
  attributs muscular_endurance + strength + power → cohérent force-endurance).
- **scoreType** : `reps` (AMRAP) — **haut = mieux**.
- **targetAttributes** (primaire **muscular_endurance**, avec **strength** = endurance-force
  au poids du corps, cohérent avec le traitement de `max_pushups`/`max_air_squats`) :
  ```
  [ { attribute: "muscular_endurance", estimated: false },
    { attribute: "strength", estimated: true } ]
  ```
  `strength` en **estimé** (proxy bodyweight, analogie D2 comme `max_pushups`/`max_air_squats`).
- **Barème de référence** (reps totales en 10 min) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 270 | 170 | 110 |
  | Femme | 250 | 155 | 95 |

  Justification : 45 reps/tour. Intermédiaire ≈ 3,8 tours = 170 reps (le pistol casse la
  cadence). Champion (force-endurance jambes élite, pistols enchaînés) ≈ 6 tours = 270 reps.
  Échelle de densité cohérente avec `max_air_squats` (médiane 80 en 1 série à l'échec) extrapolée
  sur 10 min avec mouvements plus durs.
- **Distribution recommandée** : `normal(mu = intermediate, sigma)`.
  H σ = 50 → P90 ≈ 170+64 ≈ 234, P10 ≈ 106 (≈ occasionnel). On élargit légèrement vers le
  champion (queue droite des spécialistes jambes).
  ```
  male:   { model: normal(170, 52), hardMin: 60,  hardMax: 360, proReference: 285 }
  female: { model: normal(155, 48), hardMin: 50,  hardMax: 340, proReference: 265 }
  ```

---

### Semaine 4 — `league_power_amrap` « La Détente » (PUISSANCE)

> **REMPLACE `league_power_emom` — PLUS D'EMOM.** Contrainte produit permanente (humain,
> 27 juin 2026) : les WODs imposés de la Ligue du mois sont **exclusivement AMRAP ou
> for time (RFT/chipper)**. Aucun EMOM. La semaine 4 reste la semaine **PUISSANCE** (le
> profil explosif/détente doit y briller), mais via un **AMRAP 10 min** au lieu de l'EMOM.
> **Nouvel id : `league_power_amrap`** — remplacer `league_power_emom` PARTOUT (wods.data.ts,
> wod-levels.data.ts, wod-prescriptions.data.ts, rotation Ligue, seed, tests).

- **Qualité** : puissance / explosivité répétée (force-vitesse, détente verticale + horizontale).
  L'athlète explosif (sauts, détente, hanches puissantes) brille. En AMRAP, on récompense
  la **densité de reps explosives** : produire de la puissance saut après saut, le plus de
  tours possible, sans se cramer. Le couplet est **dominé par les sauts** (pas de mouvement
  de cardio pur ni de charge) → la qualité dominante reste sans ambiguïté la PUISSANCE.
- **Structure** : **AMRAP 10 min** d'un couplet 100 % saut/explosivité, répété en boucle.
  Score = **nombre total de répétitions validées** (sauts comptés un à un ; pas de plafond
  artificiel — un athlète explosif peut accumuler beaucoup de tours, c'est voulu : la
  détente se voit dans le compteur). Pas de course, pas de charge, pas d'EMOM.
- **Contenu EXACT (1 tour = 25 reps)** :
  - **15 squat jumps** (`squat_jump`, saut vertical départ squat, genoux montés ; mappé : power 0.55)
  - **10 burpee broad jumps** (`burpee_broad_jump`, burpee + saut horizontal vers l'avant ; mappé : power 0.3)
  - → **AMRAP 10 min, score = reps totales validées** (tours partiels comptés à la rep près).
- **Mouvements** : `squat_jump` (mappé : power 0.55, muscular_endurance 0.25, engine 0.2),
  `burpee_broad_jump` (mappé : power 0.3). **Les deux sont déjà dans `movements.data.ts`** —
  aucun mouvement manquant, aucun ajout requis (cf. §7, mis à jour). 100 % sans matériel.
- **scoreType** : `reps` (AMRAP) — **haut = mieux** (`dir = +1`).
- **targetAttributes** (primaire **power**) :
  ```
  [ { attribute: "power", estimated: false },
    { attribute: "muscular_endurance", estimated: false } ]
  ```
- **Barème de référence** (reps totales validées en 10 min ; 1 tour = 25 reps) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 200 | 112 | 65 |
  | Femme | 180 | 100 | 56 |

  Justification (débits `movements.data.ts` + dégradation fatigue) :
  - Intermédiaire H : 15 squat jumps @ ~0,55 rep/s ≈ 27 s, 10 burpee broad jumps @ ~0,18 rep/s
    ≈ 56 s, + transitions ≈ 10–12 s → **~95 s/tour à froid**, mais les burpee broad jumps
    s'effondrent en fin de WOD (très coûteux) → cadence moyenne réelle ≈ 130 s/tour →
    **~4,5 tours ≈ 112 reps** en 10 min. Cohérent avec `max_air_squats_2min` (50 squats/2 min)
    et la densité `burpees_7min`, en plus explosif/plus lent par rep.
  - Champion H (détente élite, hanches qui claquent, broad jumps enchaînés sans temps mort) :
    cadence ~85–90 s/tour tenue → **~8 tours ≈ 200 reps**.
  - Occasionnel H : casse beaucoup sur les broad jumps (repos longs), ~2,5 tours → **~65 reps**.
  - Femmes : même structure, débits saut légèrement inférieurs (cf. `r(...)` female) →
    champion 180 / inter 100 / occ 56.
- **Distribution recommandée** : `normal(mu = intermediate, sigma)` **en reps** (pas de
  saturation : l'AMRAP est ouvert vers le haut, donc plus de plafond artificiel à 100 comme
  l'ancien EMOM). σ calée pour que P10/P90 collent aux paliers occasionnel/champion :
  - H σ = 34 → P90 ≈ 112 + 1,2816·34 ≈ **156**, P99 ≈ 112 + 2,326·34 ≈ **191** (≈ champion 200).
    P10 ≈ 112 − 1,2816·34 ≈ **68** (≈ occasionnel 65). OK.
  - F σ = 31 → P90 ≈ 100 + 40 ≈ **140**, P99 ≈ **172** (≈ champion 180), P10 ≈ **60** (≈ occ 56). OK.
  ```
  male:   { model: normal(112, 34), hardMin: 30, hardMax: 280, proReference: 200 }
  female: { model: normal(100, 31), hardMin: 25, hardMax: 250, proReference: 180 }
  ```
  > **Pas de saturation** : contrairement à l'ancien EMOM (plafond dur 100), l'AMRAP est
  > ouvert vers le haut. `hardMax` (280 H / 250 F) est un garde-fou anti-aberration de saisie
  > (≈ 11–12 tours, au-delà du record réaliste sur ce couplet), pas un plafond de design.
  > `proReference` = palier champion (élite explosif réel estimé), pas un record absolu —
  > confiance *low*, à recalibrer sur la communauté (N≥200/sexe) comme les 4 autres WODs Ligue.
  > **Variante non retenue** : ratio 12 squat jumps / 8 broad jumps (tour de 20 reps, plus
  > « propre » techniquement en fatigue) — écarté car le tour de 25 reps donne un compteur
  > plus granulaire et un meilleur étalement des percentiles. Si l'ingénierie observe trop de
  > casse technique sur les broad jumps en fin de WOD, basculer sur 12/8 et diviser le barème
  > par 1,25 (200→160, 112→90, 65→52 H ; 180→144, 100→80, 56→45 F).

---

### Semaine 5 — `league_hybrid_chipper` « Le Chaos » (HYBRIDE / mixte)

- **Qualité** : hybride — course + gym + gainage + explosif dans une seule pièce.
  Le profil **complet/équilibré** (pas de trou) brille ; récompense le « généraliste »
  qui n'a gagné aucune des 4 semaines précédentes mais est bon partout.
- **Structure** : **chipper for time** (on descend la liste une seule fois). Time cap 15 min.
  Si non terminé au cap → score = **temps cap + pénalité reps restantes** (voir note).
- **Contenu EXACT (une seule fois, dans l'ordre)** :
  - 400 m course (`run`)
  - 40 air squats (`air_squat`)
  - 30 sit-ups (`sit_up`)
  - 20 burpees (`burpee`)
  - 10 wall walks (`wall_walk`)
  - 400 m course (`run`)
  - **For time.** Time cap **15 min**.
- **Mouvements** : `run`, `air_squat`, `sit_up`, `burpee`, `wall_walk` (tous mappés ;
  couvre engine + muscular_endurance + power + strength → vrai mix hybride).
- **scoreType** : `time` — **bas = mieux**.
- **targetAttributes** (primaire **hybrid**) :
  ```
  [ { attribute: "hybrid", estimated: false },
    { attribute: "engine", estimated: false },
    { attribute: "muscular_endurance", estimated: false } ]
  ```
- **Barème de référence** (temps total, secondes) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 420 (7:00) | 660 (11:00) | 870 (14:30) |
  | Femme | 480 (8:00) | 720 (12:00) | 900 (15:00) |

  Justification : aligné sur `benchmark_zero` (intermédiaire H 570 s) mais un peu plus long
  (wall walks = goulot d'étranglement technique très discriminant). Intermédiaire H ~11 min.
- **Distribution recommandée** : `lognormalFromMedian(median = intermediate, 0.18)`.
  σ_ln 0,18 ≈ celle de `helen`/`hyrox_sprint` (chippers mixtes). Vérif H : P10 ≈ 660·exp(+0.231)
  ≈ 831 s (≈ occasionnel), P90 ≈ 660·exp(−0.231) ≈ 524 s (entre champion et inter). OK.
  ```
  male:   { model: lognormalFromMedian(660, 0.18), hardMin: 360, hardMax: 900,  proReference: 400 }
  female: { model: lognormalFromMedian(720, 0.18), hardMin: 420, hardMax: 900,  proReference: 460 }
  ```
  > **Gestion du time cap (cohérence pipeline)** : si l'athlète atteint le cap sans finir,
  > convertir en « temps équivalent » = `cap + reps_restantes × k` (k ≈ 3 s/rep, course
  > restante comptée en s à l'allure occasionnelle) **avant** de scorer, puis clamp à
  > `hardMax`. Même principe que la normalisation Riegel de `run_free_distance` : on
  > ramène toujours à l'échelle de la distribution avant `percentile()`.

---

## 4. Chaîne de notation (rappel, identique aux benchmarks)

Pour chaque WOD Ligue :
1. Résultat brut (s ou reps/tours) → `percentile(result, model_bySex)` borné par
   `[hardMin, hardMax]` (clamp avant percentile).
2. Percentile → sous-score 0–1000 (même fonction que les 15 benchmarks).
3. **Score de Ligue** = agrégation des sous-scores des semaines jouées (le pipeline Ligue
   existant `totalsBestPerWeek` / `rankTotals` s'applique tel quel : meilleur résultat par
   semaine, somme sur le mois). **Aucune nouvelle mécanique d'agrégation requise.**
4. Affichage /100 au bord (display-v1), jamais le brut /1000 à l'app.

Tous les `model` ci-dessus sont **exprimés dans les mêmes unités que le résultat saisi**
(secondes, reps, ou tours décimaux) — donc compatibles directement avec `percentile()`.

---

## 5. Paliers d'affichage (`wod-levels.data.ts`)

À ajouter (mêmes valeurs champion/intermediate/occasional que les barèmes §3, en respectant
la monotonie : `time` → champion < inter < occ ; `reps` → champion > inter > occ) :

```
league_sprint_ladder: { male: { champion: 290, intermediate: 420, occasional: 600 },
                        female: { champion: 335, intermediate: 480, occasional: 690 } }
league_engine_12:     { male: { champion: 9.5, intermediate: 6.0, occasional: 4.0 },
                        female: { champion: 8.5, intermediate: 5.5, occasional: 3.5 } }   // en TOURS
league_grind_squats:  { male: { champion: 285, intermediate: 170, occasional: 110 },
                        female: { champion: 265, intermediate: 155, occasional: 95 } }     // en REPS
league_power_amrap:   { male: { champion: 200, intermediate: 112, occasional: 65 },
                        female: { champion: 180, intermediate: 100, occasional: 56 } }     // en REPS (AMRAP 10 min) — remplace league_power_emom
league_hybrid_chipper:{ male: { champion: 400, intermediate: 660, occasional: 870 },
                        female: { champion: 460, intermediate: 720, occasional: 900 } }    // en s
```

---

## 6. Recommandation : ces WODs nourrissent-ils l'Index ? — NON (avis sport-science argumenté)

**Recommandation : « Ligue uniquement ». Ils ne doivent PAS alimenter l'Athlete Index.**

Raisons :
1. **Décision verrouillée** : les **15 benchmarks de l'Index sont figés** (CLAUDE.md). Ajouter
   ces 5 au calcul de l'Index violerait cette décision et déstabiliserait la comparabilité
   historique de tous les scores déjà calculés.
2. **Intégrité statistique des distributions** : les barèmes §3 sont des **estimations**
   (confiance *low*, non encore bootstrapées sur N≥200/sexe). Les injecter dans l'Index
   propagerait du bruit dans un score « source de vérité » qui se veut stable et crédible.
   La Ligue est le bon bac à sable : mensuelle, jetable, sans effet rémanent sur l'Index.
3. **Anti-double-comptage d'attributs** : la plupart de ces WODs partagent leurs attributs
   avec des benchmarks existants (ex. sem. 2 ≈ `burpees_7min`/`benchmark_zero` sur engine+ME).
   Les compter deux fois sur-pondérerait engine/muscular_endurance dans le radar.
4. **Liberté de design Ligue** : « Ligue uniquement » nous laisse calibrer pour la
   compétition (saturation volontaire en sem. 4, time caps agressifs) sans craindre de
   fausser l'Index. C'est précisément ce qui permet de « donner sa chance à tout le monde »
   chaque semaine.

**Conséquence d'implémentation** (à acter par l'ingénierie, pas par moi) :
- Seeder ces 5 WODs avec **`isBenchmark: false`** (et idéalement un flag **`isLeagueOnly: true`**),
  pour qu'ils n'entrent **jamais** dans le calcul du radar/Index ni dans le feed « benchmark ».
- Ils restent loguables et classables **dans la Ligue uniquement** ; un résultat sur un de ces
  WODs **n'écrase aucun attribut** de l'Index (ni réel ni estimé).

---

## 7. Champs DB / mouvements à AJOUTER (à faire par l'ingénierie — listé explicitement)

**Aucun mouvement manquant.** `squat_jump` a depuis été ajouté à `movements.data.ts`
(`power 0.55`, `muscular_endurance 0.25`, `engine 0.2` ; `loadFactor 0.85`, `fatigueExponent 1.22`,
`maxSet 20`, `rate r(0.85, 0.78, 0.55, 0.48, 0.38, 0.32)`). Tous les mouvements utilisés par les
5 WODs Ligue sont donc **déjà mappés** : `run`, `sprint`, `air_squat`, `burpee`, `squat_jump`,
`burpee_broad_jump`, `lunge`, `pistol_squat`, `sit_up`, `wall_walk`.

> La semaine 4 (`league_power_amrap`, AMRAP 10 min) n'a **plus aucune dépendance bloquante** :
> elle utilise `squat_jump` + `burpee_broad_jump`, tous deux mappés. Le fallback `box_jump`
> (qui cassait la contrainte « sans matériel ») n'a plus lieu d'être.

**Champs / réglages côté seed & Ligue à prévoir** :
- `isBenchmark: false` (et `isLeagueOnly: true` si on introduit le flag) sur les 5 WODs.
- Exclure les 5 anciens WODs Ligue du pool imposé, OU basculer le pool Ligue sur le flag
  `isLeagueOnly` (option (b) §2 — recommandée). Les 5 anciens **restent** des benchmarks
  Index (ne pas les supprimer), ils cessent juste d'être **imposés en Ligue**.
- Saisie : `league_engine_12` se saisit en **tours décimaux** (sinon prévoir conversion
  reps→tours avant scoring). `league_power_amrap` et `league_grind_squats` se saisissent en
  **reps totales**. Les deux `time` se saisissent en **secondes**, avec conversion time-cap
  (sem. 5) avant `percentile()`.

---

## 8. Niveau de confiance des données

- **Confiance : LOW/estimation** sur tous les barèmes (pas de dataset public direct pour ces
  formats inédits). Méthode : extrapolation à partir des distributions calibrées existantes
  (`burpees_7min`, `max_air_squats_2min`, `run_1k`, `benchmark_zero`, `helen`) + débits
  `rate` de `movements.data.ts`. À **recalibrer sur la communauté** (N≥200/sexe) après le
  premier mois de Ligue — exactement comme prévu pour les distributions *low* des benchmarks.
- Aucun chiffre n'est présenté comme mesuré ; tout est marqué estimation, cohérent avec le
  principe « crédibilité avant tout / pas de chiffre inventé sans le signaler ».
