# WODs « Ligue du mois » — 5 séances dédiées (sport-science)

Statut : SPEC (données prêtes à implémenter). Aucun fichier de code modifié.
Auteur : agent `sport-science`. Date : 2026-06-26.

## 1. Objet et règles

Ces **5 WODs sont créés UNIQUEMENT pour la « Ligue du mois »**. Ils **remplacent
intégralement** les WODs benchmark actuellement imposés en Ligue
(`burpees_7min`, `max_air_squats_2min`, `max_pushups`, `profil_express`, `run_1k`).
On ne réutilise **aucun** WOD existant pour la Ligue.

Contraintes respectées (cahier des charges produit) :
- **RÈGLE AMRAP LIGUE — UN TOUR ≥ ~3 MIN** (contrainte produit permanente, humain, 27 juin 2026).
  Dans tout AMRAP imposé en Ligue, **un tour complet doit durer AU MOINS ~3 min pour un athlète
  INTERMÉDIAIRE** (estimé via les débits `rate` de `movements.data.ts`). Motif : un tour trop
  court (ex. ancienne « Détente » à ~45–60 s) fait enchaîner trop de tours et vide le format de
  son sens. Les tours doivent être **plus lourds** (plus de reps / plus de mouvements par tour).
  Conséquence directe : sur un AMRAP de 10–12 min, on ne fait que **3–4 tours** → on **score en
  REPS TOTALES** (granularité fine), pas en tours décimaux (trop grossier à 3–4 tours).
- **JAMAIS d'EMOM** dans les WODs imposés de la Ligue (contrainte produit permanente, humain,
  27 juin 2026). Formats autorisés : **AMRAP** ou **for time (RFT / chipper)** uniquement.
  → l'ancienne semaine 4 EMOM (`league_power_emom`) est remplacée par `league_power_amrap` (AMRAP 12 min).
- 100 % **sans matériel** (poids du corps + course en option) → `requiresEquipment: false`.
- Durée cible **8–15 min** chacun (time cap inclus).
- **5 semaines = 5 qualités différentes** : Vitesse, Endurance (moteur), Force-endurance,
  Puissance, Hybride. Chaque semaine, un profil d'athlète différent peut briller.
- Mouvements pris **exclusivement** dans `movements.data.ts` (sauf 1 manquant signalé en §7).

Convention de scoring (identique aux 15 benchmarks, cf. `wods.data.ts`) :
- `scoreType: "time"` → `dir = -1` (plus bas = mieux).
- `scoreType: "reps"` → `dir = +1` (plus haut = mieux). Inclut AMRAP (score = **reps totales** ;
  pour un AMRAP avec course, le « rep » interne compte aussi chaque mètre couru comme 1 unité de
  travail — voir sem. 2). On n'utilise **plus** le score « en tours décimaux » : avec des tours
  ≥ 3 min, 3–4 tours suffisent à plier l'AMRAP, donc les tours sont trop grossiers pour étaler les
  percentiles. **Les 3 AMRAP Ligue se scorent désormais en reps/unités totales.**
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
| 2 | `league_engine_12` | Le Moteur | **Endurance (aérobie)** | AMRAP 12 min (tour ≥ 3 min) | `reps` (unités) | haut = mieux | 12 min |
| 3 | `league_grind_squats` | Le Pilier | **Force-endurance** (bas du corps) | AMRAP 12 min (tour ≥ 3 min) | `reps` | haut = mieux | 12 min |
| 4 | `league_power_amrap` | La Détente | **Puissance** | AMRAP 12 min (tour ≥ 3 min) | `reps` | haut = mieux | 12 min |
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
- **Structure** : **AMRAP 12 min** d'un triplet cyclique. Tour **alourdi** pour respecter la règle
  « tour ≥ 3 min » (l'ancien tour 200 m + 15 + 10 bouclait en ~95–100 s → trop court). On double la
  course et on densifie le gym, sans casser le caractère continu/aérobie.
- **Contenu EXACT (1 tour)** :
  - 400 m course (`run`)
  - 20 air squats (`air_squat`)
  - 15 burpees (`burpee`)
  - → répéter pendant 12 min.
- **Durée d'un tour (intermédiaire, via `rate`)** :
  - Homme : course 400 m ÷ 3,8 m/s = **105 s** ; 20 air squats ÷ 1,0/s = **20 s** ; 15 burpees ÷ 0,5/s
    = **30 s** ; transitions ≈ **12 s** → **~167 s à froid**, ~185–195 s avec la dégradation sur 12 min.
    **≥ 3 min : OK.** → ~3,9 tours en 12 min pour l'intermédiaire H.
  - Femme : 400 ÷ 2,8 = **143 s** ; 20 ÷ 0,66 = **30 s** ; 15 ÷ 0,28 = **54 s** ; transitions ≈ **12 s**
    → **~239 s à froid**, ~255–265 s en fatigue. **≥ 3 min : largement OK.** → ~2,8 tours.
- **Unité de SCORE** : **REPS / UNITÉS TOTALES** (plus de « tours décimaux »). Convention interne
  identique à l'existant : **1 m couru = 1 unité**, **1 rep = 1 unité**. **1 tour = 400 + 35 = 435 unités.**
  Avec ~3–4 tours seulement, le score en unités totales donne une granularité fine (le mètre et la
  rep partielle comptent) là où les « tours » seraient trop grossiers.
- **Mouvements** : `run`, `air_squat`, `burpee` (tous mappés).
- **scoreType** : `reps` (AMRAP, en unités totales) — **haut = mieux**.
- **targetAttributes** (primaire **engine**) — inchangés :
  ```
  [ { attribute: "engine", estimated: false },
    { attribute: "muscular_endurance", estimated: false },
    { attribute: "hybrid", estimated: false } ]
  ```
- **Barème de référence** (en **unités totales** = mètres courus + reps ; 1 tour = 435 unités) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 2600 (~6,0 tours) | 1740 (~4,0 tours) | 1130 (~2,6 tours) |
  | Femme | 1560 (~3,6 tours) | 1220 (~2,8 tours) | 910 (~2,1 tours) |

  Justification (débits `rate`) : intermédiaire H ~185 s/tour → ~3,9 tours ≈ **1740 unités**.
  Champion H (course 400/5,6=71 s, gym serré ~45 s, ~120 s/tour) → ~6 tours ≈ **2600**. Occasionnel H
  (course 400/2,8=143 s, gym lent ~117 s, ~275 s/tour) → ~2,6 tours ≈ **1130**. Femmes : course plus
  lente (inter 2,8 m/s) → ~2,8 tours ≈ **1220**, champion ~3,6 ≈ **1560**, occ ~2,1 ≈ **910**.
- **Distribution recommandée** : `normal(mu = intermediate, sigma)` **en unités totales**.
  H σ = 470 → P90 ≈ 1740 + 1,2816·470 ≈ **2342**, P99 ≈ **2833** (~champion), P10 ≈ **1138** (~occasionnel).
  F σ = 360 → P90 ≈ **1681**, P99 ≈ **2058**, P10 ≈ **759**. OK.
  ```
  male:   { model: normal(1740, 470), hardMin: 600, hardMax: 3200, proReference: 2750 }
  female: { model: normal(1220, 360), hardMin: 450, hardMax: 2400, proReference: 1900 }
  ```
  > **Unité de saisie** : l'app demande les **unités totales** (mètres courus complets + reps de la
  > série en cours). Conversion possible côté front : `unités = mètres_run + reps_gym`. Plus de
  > saisie « en tours ». `proReference` = élite moteur estimé (confiance *low*, à recalibrer N≥200/sexe).

---

### Semaine 3 — `league_grind_squats` « Le Pilier » (FORCE-ENDURANCE bas du corps)

- **Qualité** : endurance-force du bas du corps + gainage. L'athlète « jambes / volume »
  (cuisses solides, tolérance à la brûlure) brille — typiquement pas le même profil que sem. 1/2.
- **Structure** : **AMRAP 12 min** (porté de 10 à 12 min pour bien étaler 3–4 tours longs),
  triplet bas-du-corps lourd en volume + gainage + stabilité unilatérale. Tour **alourdi** pour
  respecter « tour ≥ 3 min » (l'ancien tour 20+15+10 = 45 reps bouclait en ~70–110 s → trop court).
  Score = **reps totales**.
- **Contenu EXACT (1 tour = 106 reps)** :
  - 40 fentes marchées (`lunge`, 20/jambe)
  - 30 air squats (`air_squat`)
  - 20 sit-ups (`sit_up`) — composante **gainage** (le « pilier »)
  - 16 pistol squats (`pistol_squat`, 8/jambe) — **scaling autorisé** : pistol assisté ou
    « step-down » compte 0,5 rep (géré côté barème/scaling, comme la décote Scaled ×0.9).
  - → AMRAP 12 min. **Score = reps totales** (106 reps/tour à plein).
- **Durée d'un tour (intermédiaire, via `rate`)** :
  - Homme : 40 fentes ÷ 0,65/s = **62 s** ; 30 air squats ÷ 1,0 = **30 s** ; 20 sit-ups ÷ 0,8 = **25 s** ;
    16 pistols ÷ 0,55 = **29 s** ; transitions ≈ **14 s** → **~160 s à froid**, ~185–195 s avec la
    dégradation (pistols + fentes très coûteux en fatigue). **≥ 3 min : OK.** → ~3,8 tours en 12 min.
  - Femme : 40 ÷ 0,4 = **100 s** ; 30 ÷ 0,66 = **45 s** ; 20 ÷ 0,5 = **40 s** ; 16 ÷ 0,26 = **62 s** ;
    transitions ≈ **14 s** → **~261 s à froid**. **≥ 3 min : largement OK.** → ~2,8 tours.
- **Unité de SCORE** : **REPS TOTALES** (toutes reps validées, tour partiel à la rep près).
  Avec 3–4 tours, les reps totales discriminent finement (un demi-tour = ~53 reps d'écart).
- **Mouvements** : `lunge`, `air_squat`, `sit_up`, `pistol_squat` (tous mappés ; bas-du-corps +
  gainage → cohérent force-endurance / « pilier »).
- **scoreType** : `reps` (AMRAP) — **haut = mieux**.
- **targetAttributes** (primaire **muscular_endurance**, avec **strength** = endurance-force
  au poids du corps, cohérent avec le traitement de `max_pushups`/`max_air_squats`) — inchangés :
  ```
  [ { attribute: "muscular_endurance", estimated: false },
    { attribute: "strength", estimated: true } ]
  ```
  `strength` en **estimé** (proxy bodyweight, analogie D2 comme `max_pushups`/`max_air_squats`).
- **Barème de référence** (reps totales en 12 min ; 1 tour = 106 reps) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 520 (~4,9 tours) | 400 (~3,8 tours) | 250 (~2,4 tours) |
  | Femme | 330 (~3,1 tours) | 290 (~2,7 tours) | 175 (~1,7 tours) |

  Justification (débits `rate`) : intermédiaire H ~190 s/tour → ~3,8 tours ≈ **400 reps**.
  Champion H (fentes/pistols enchaînés, ~147 s/tour) → ~4,9 tours ≈ **520**. Occasionnel H (pistols
  scalés, ~300 s/tour) → ~2,4 tours ≈ **250**. Femmes plus lentes sur fentes/pistols → inter ~2,7
  tours ≈ **290**, champion ~3,1 ≈ **330**, occ ~1,7 ≈ **175**.
- **Distribution recommandée** : `normal(mu = intermediate, sigma)` **en reps**.
  H σ = 115 → P90 ≈ 400 + 1,2816·115 ≈ **547** (~champion), P10 ≈ **253** (~occasionnel).
  F σ = 90 → P90 ≈ **405**, P10 ≈ **175**. OK.
  ```
  male:   { model: normal(400, 115), hardMin: 90,  hardMax: 760, proReference: 560 }
  female: { model: normal(290, 90),  hardMin: 70,  hardMax: 560, proReference: 400 }
  ```

---

### Semaine 4 — `league_power_amrap` « La Détente » (PUISSANCE)

> **REMPLACE `league_power_emom` — PLUS D'EMOM.** Contrainte produit permanente (humain,
> 27 juin 2026) : les WODs imposés de la Ligue du mois sont **exclusivement AMRAP ou
> for time (RFT/chipper)**. Aucun EMOM. La semaine 4 reste la semaine **PUISSANCE** (le
> profil explosif/détente doit y briller), mais via un **AMRAP 12 min** au lieu de l'EMOM.
> **Nouvel id : `league_power_amrap`** — remplacer `league_power_emom` PARTOUT (wods.data.ts,
> wod-levels.data.ts, wod-prescriptions.data.ts, rotation Ligue, seed, tests).

- **Qualité** : puissance / explosivité répétée (force-vitesse, détente verticale + horizontale).
  L'athlète explosif (sauts, détente, hanches puissantes) brille. En AMRAP, on récompense
  la **densité de reps explosives** : produire de la puissance saut après saut, le plus de
  tours possible, sans se cramer. Le couplet est **dominé par les sauts** (pas de mouvement
  de cardio pur ni de charge) → la qualité dominante reste sans ambiguïté la PUISSANCE.
- **Structure** : **AMRAP 12 min** d'un couplet 100 % saut/explosivité, répété en boucle. Tour
  **alourdi** pour respecter « tour ≥ 3 min » : l'ancien tour 15 + 10 = 25 reps bouclait en ~45–95 s
  (BEAUCOUP trop court — motif du redesign). On double quasi le volume par tour (le burpee broad
  jump, très coûteux, devient le « moteur de durée »), sans ajouter de cardio pur ni de charge : la
  qualité dominante reste sans ambiguïté la **PUISSANCE / explosivité répétée**.
  Score = **reps totales validées** (sauts comptés un à un ; AMRAP ouvert vers le haut).
- **Contenu EXACT (1 tour = 55 reps)** :
  - **30 squat jumps** (`squat_jump`, saut vertical départ squat, genoux montés ; mappé : power 0.55)
  - **25 burpee broad jumps** (`burpee_broad_jump`, burpee + saut horizontal vers l'avant ; mappé : power 0.3)
  - → **AMRAP 12 min, score = reps totales validées** (tours partiels comptés à la rep près).
- **Durée d'un tour (intermédiaire, via `rate`)** :
  - Homme : 30 squat jumps ÷ 0,78/s = **38 s** ; 25 burpee broad jumps ÷ 0,34/s = **74 s** ;
    transitions ≈ **12 s** → **~124 s à froid**, mais les broad jumps s'effondrent (fatigueExp 1,3,
    et `maxSet` squat_jump = 20 force une coupure à 30) → cadence réelle **~175–190 s/tour**.
    **≥ 3 min : OK.** → ~3,9 tours en 12 min.
  - Femme : 30 ÷ 0,48 = **63 s** ; 25 ÷ 0,13 = **192 s** ; transitions ≈ **12 s** → **~267 s à froid**
    (le burpee broad jump est très lent en débit féminin). **≥ 3 min : largement OK.** → ~2,3 tours.
- **Unité de SCORE** : **REPS TOTALES** (pas de tours décimaux). Avec ~2–4 tours de 55 reps, les
  reps totales sont la bonne granularité (un tour = 55 reps d'écart, une demi-série encore visible).
- **Mouvements** : `squat_jump` (mappé : power 0.55, muscular_endurance 0.25, engine 0.2),
  `burpee_broad_jump` (mappé : power 0.3). **Les deux sont déjà dans `movements.data.ts`** —
  aucun mouvement manquant, aucun ajout requis (cf. §7). 100 % sans matériel.
- **scoreType** : `reps` (AMRAP) — **haut = mieux** (`dir = +1`).
- **targetAttributes** (primaire **power**) — inchangés :
  ```
  [ { attribute: "power", estimated: false },
    { attribute: "muscular_endurance", estimated: false } ]
  ```
- **Barème de référence** (reps totales validées en 12 min ; 1 tour = 55 reps) :

  | | champion | intermediate | occasional |
  |--|--|--|--|
  | Homme | 360 (~6,5 tours) | 215 (~3,9 tours) | 130 (~2,4 tours) |
  | Femme | 195 (~3,5 tours) | 127 (~2,3 tours) | 80 (~1,5 tours) |

  Justification (débits `rate` + dégradation) :
  - Intermédiaire H : ~185 s/tour → **~3,9 tours ≈ 215 reps** en 12 min.
  - Champion H (détente élite, broad jumps enchaînés ~105 s/tour) → **~6,5 tours ≈ 360 reps**.
  - Occasionnel H : casse énormément sur les broad jumps (~286 s/tour) → **~2,4 tours ≈ 130 reps**.
  - Femmes : burpee broad jump très lent en débit féminin → inter ~267 s/tour ≈ **127**,
    champion ~204 s/tour ≈ **195**, occ ~360 s/tour ≈ **80**.
- **Distribution recommandée** : `normal(mu = intermediate, sigma)` **en reps** (AMRAP ouvert vers
  le haut, pas de saturation/plafond comme l'ancien EMOM). σ calée sur les paliers occ/champion :
  - H σ = 68 → P90 ≈ 215 + 1,2816·68 ≈ **302**, P99 ≈ 215 + 2,326·68 ≈ **373** (≈ champion 360).
    P10 ≈ **128** (≈ occasionnel 130). OK.
  - F σ = 42 → P90 ≈ 127 + 54 ≈ **181**, P99 ≈ **225** (≈ champion 195), P10 ≈ **73** (≈ occ 80). OK.
  ```
  male:   { model: normal(215, 68), hardMin: 50, hardMax: 480, proReference: 380 }
  female: { model: normal(127, 42), hardMin: 30, hardMax: 300, proReference: 210 }
  ```
  > **Pas de saturation** : l'AMRAP est ouvert vers le haut. `hardMax` (480 H / 300 F ≈ 8–9 tours)
  > est un garde-fou anti-aberration de saisie, pas un plafond de design. `proReference` = palier
  > champion (élite explosif réel estimé) — confiance *low*, à recalibrer sur la communauté
  > (N≥200/sexe) comme les 4 autres WODs Ligue.
  > **Variante non retenue** : 24 squat jumps / 16 burpee broad jumps (tour de 40 reps) — écarté car
  > le tour de 55 reps assure plus franchement les ~3 min côté intermédiaire H (le 40-reps retombait
  > sous 3 min pour le H rapide). Si l'ingénierie observe trop de casse technique sur les broad jumps
  > en fin de WOD, basculer sur 24/16 et multiplier le barème par 40/55 ≈ 0,73.

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
(secondes ou reps/unités totales — plus aucun tour décimal) — donc compatibles directement avec `percentile()`.

---

## 5. Paliers d'affichage (`wod-levels.data.ts`)

À ajouter (mêmes valeurs champion/intermediate/occasional que les barèmes §3, en respectant
la monotonie : `time` → champion < inter < occ ; `reps` → champion > inter > occ) :

```
league_sprint_ladder: { male: { champion: 290,  intermediate: 420,  occasional: 600 },
                        female: { champion: 335,  intermediate: 480,  occasional: 690 } }   // en s
league_engine_12:     { male: { champion: 2600, intermediate: 1740, occasional: 1130 },
                        female: { champion: 1560, intermediate: 1220, occasional: 910 } }   // en UNITÉS (m + reps), AMRAP 12 min
league_grind_squats:  { male: { champion: 520,  intermediate: 400,  occasional: 250 },
                        female: { champion: 330,  intermediate: 290,  occasional: 175 } }   // en REPS, AMRAP 12 min
league_power_amrap:   { male: { champion: 360,  intermediate: 215,  occasional: 130 },
                        female: { champion: 195,  intermediate: 127,  occasional: 80 } }    // en REPS, AMRAP 12 min — remplace league_power_emom
league_hybrid_chipper:{ male: { champion: 400,  intermediate: 660,  occasional: 870 },
                        female: { champion: 460,  intermediate: 720,  occasional: 900 } }   // en s
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

> La semaine 4 (`league_power_amrap`, AMRAP 12 min) n'a **plus aucune dépendance bloquante** :
> elle utilise `squat_jump` + `burpee_broad_jump`, tous deux mappés. Le fallback `box_jump`
> (qui cassait la contrainte « sans matériel ») n'a plus lieu d'être.

**Champs / réglages côté seed & Ligue à prévoir** :
- `isBenchmark: false` (et `isLeagueOnly: true` si on introduit le flag) sur les 5 WODs.
- Exclure les 5 anciens WODs Ligue du pool imposé, OU basculer le pool Ligue sur le flag
  `isLeagueOnly` (option (b) §2 — recommandée). Les 5 anciens **restent** des benchmarks
  Index (ne pas les supprimer), ils cessent juste d'être **imposés en Ligue**.
- Saisie (HARMONISÉE — plus aucun « tour décimal ») : les **3 AMRAP** se saisissent en
  **reps / unités totales** :
  - `league_engine_12` : **unités totales** = mètres courus complets + reps gym (1 tour = 435).
  - `league_grind_squats` : **reps totales** (1 tour = 106 reps).
  - `league_power_amrap` : **reps totales** (1 tour = 55 reps).
  Les deux `time` (`league_sprint_ladder`, `league_hybrid_chipper`) se saisissent en **secondes**,
  avec conversion time-cap (sem. 5) avant `percentile()`.

---

## 8. Niveau de confiance des données

- **Confiance : LOW/estimation** sur tous les barèmes (pas de dataset public direct pour ces
  formats inédits). Méthode : extrapolation à partir des distributions calibrées existantes
  (`burpees_7min`, `max_air_squats_2min`, `run_1k`, `benchmark_zero`, `helen`) + débits
  `rate` de `movements.data.ts`. À **recalibrer sur la communauté** (N≥200/sexe) après le
  premier mois de Ligue — exactement comme prévu pour les distributions *low* des benchmarks.
- Aucun chiffre n'est présenté comme mesuré ; tout est marqué estimation, cohérent avec le
  principe « crédibilité avant tout / pas de chiffre inventé sans le signaler ».
