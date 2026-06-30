# Audit — Système de prédiction des temps de WOD

> Autorité : Gamification + Science du sport. Date : 2026-06-30.
> Périmètre : `predictResult` (GET `/v1/wods/:id/prediction`), moteur par mouvement
> (`wod-time-engine.ts`), blueprints (`wod-blueprints.data.ts`), distributions (`wods.data.ts`),
> paliers (`wod-levels.data.ts`).
> Principe directeur préservé : **ESTIMATION ≠ NOTATION**. Toute recalibration ci-dessous ne touche
> que l'estimation/les paliers affichés ; aucune ne déplace un sous-score, un Index ni un classement
> au-delà de ce qui est explicitement noté.

---

## NOTE GLOBALE : **5,5 / 10**

| Axe | Note | Justification courte |
|---|---|---|
| Architecture du moteur per-mouvement | 8,5/10 | Excellent socle (capacité par mouvement, pénalité de charge relative, fatigue, fourchette de confiance). Bien testé sur les WODs couverts. |
| Couverture blueprint (per-user) | **3/10** | **8 WODs multi-mouvements loguables retombent en SILENCE sur la population** → prédictions fausses (Le Chaos, Murph, Isabel, 4 autres Ligue). C'est le défaut bloquant. |
| Réalisme des niveaux/distributions | **4/10** | Médianes et σ calées sur des données de COMPÉTITION (CrossFit Open / Beyond the Whiteboard). « Intermédiaire » = niveau régional, « débutant » = bon amateur → décourageant en vraie salle. |
| Cohérence scoring ↔ terrain | **3,5/10** | Un Fran à 9m50 (réalité d'un pratiquant 1 an honorable) ressort à **P≈0,16 = sous le 1er quintile**. Démotivant et faux. |
| Garde-fous (pas de crash/NaN, bornes) | 8/10 | Repli silencieux jamais de crash, clamp population correct. Mais le « silence » est précisément le problème. |

**Verdict** : le moteur est bon ; **ce qui est cassé, c'est (a) la COUVERTURE (trop de WODs sans
blueprint) et (b) le CALIBRAGE des niveaux (compétition au lieu de salle)**. Les deux sont corrigeables
sans retoucher le moteur.

---

## 1. DIAGNOSTIC per-user — blueprints manquants

### 1.1 Le chemin réel (lecture de `scoring.service.ts:528 predictResult`)
```
resolved = resolveBlueprintBlocks(wodId, sex)        // null si pas de blueprint exploitable
if (resolved) { estimate = estimateBlueprintTime(...) }  // ← MOTEUR per-mouvement + loadMult
else { ... quantile(percentileFromInternal(moyenne cibles), ref.model) }  // ← REPLI POPULATION
```
Le repli population est **SILENCIEUX** : aucune trace, aucun flag de confiance dégradé. Un WOD
multi-mouvements sans blueprint produit donc une prédiction « moyenne d'attributs → percentile →
quantile lognormal » — exactement le modèle que la refonte « pro » visait à remplacer.

### 1.2 Inventaire (vérifié par script)
**Blueprints existants (12)** : `fran, grace, jackie, helen, karen, cindy, hyrox_sprint, row_2k,
ergo_skill, profil_express, benchmark_zero` (+ `row_2k` mono).

**WODs LOGUABLES SANS blueprint** :

| WOD | scoreType | Mono/1RM légitime ? | Verdict |
|---|---|---|---|
| run_5k / run_3k / run_1k / run_free_distance | time | OUI (course pure, Riegel) | OK, repli légitime |
| track_10000m / half_marathon / marathon | time | OUI (course pure) | OK, repli légitime |
| max_pushups / max_air_squats / max_air_squats_2min / max_strict_pullups | reps | OUI (mono-mouvement) | Tolérable (cf. §3a note) |
| squat_1rm | load | OUI (1RM) | OK, repli légitime |
| **hyrox_solo** | time | NON — 8 km + 8 stations | **❌ repli population faux** |
| **isabel** | time | NON — 30 snatch chargés | **❌ pénalité de charge ignorée** |
| **murph** | time | NON — course + 600 reps gym | **❌ repli population faux** |
| **league_sprint_ladder** (La Flèche) | time | NON — échelle 1600 m sprint | **❌** |
| **league_engine_12** (Le Moteur) | reps | NON — AMRAP course+squats+burpees | **❌** |
| **league_grind_squats** (Le Pilier) | reps | NON — AMRAP 4 mouvements | **❌** |
| **league_power_amrap** (La Détente) | reps | NON — AMRAP 2 mouvements explosifs | **❌** |
| **league_hybrid_chipper** (Le Chaos) | time | NON — chipper 6 blocs | **❌** |

→ **8 WODs multi-mouvements loguables retombent en silence sur la population.** Confirmé : **Le Chaos
et Murph n'ont AUCUN blueprint.**

### 1.3 Preuve chiffrée du défaut (profil « soso » : strength 661, power 737, ME 971)
Simulation du repli population (sigmoid-v1 inverse k=6/p0=0,55 → `quantile(p, lognormal)`) :

| WOD | cibles utilisées | meanInternal | p | **prédiction repli** | Réalité attendue | Écart |
|---|---|---|---|---|---|---|
| **Le Chaos** (med 720 s, σ0,30) | hybrid+engine+ME | 790 | 0,77 | **~900 s (15:00, clampé au cap)** ou ~9:00 selon attrs | il serait **plus LENT** que le champion 7m10 | la moyenne ME=971 tire le percentile haut → prédiction trop optimiste/instable |
| **Murph** (med 3300 s, σ0,32) | engine+ME+hybrid | 790 | 0,77 | **~4185 s (69:45)** ou ~40:00 selon attrs | force faible + 100 tractions = **énorme** → bien plus lent | la force (mur réel des 100 pull-ups) **n'est pas dans les cibles** → ignorée |

Le défaut est **structurellement identique au bug Fran d'origine** documenté dans
`plan-estimation-pro.md` : `predictResult` lit `targetAttributes` (grossier) au lieu des `attributes`
par mouvement, et **n'applique aucune pénalité de charge**. Pour Murph la FORCE (limitante sur 100
tractions strictes) est absente des cibles `[engine, ME, hybrid]` → sous-évaluation garantie.

**Principe à acter : « plus jamais de repli population silencieux sur un WOD multi-mouvements. »**
Tout WOD loguable comportant ≥ 2 mouvements (ou un mouvement chargé) DOIT avoir un blueprint.

---

## 2. DIAGNOSTIC niveaux — calage « compétition » vs réalité de salle

### 2.1 Le constat (Fran, homme)
Distribution actuelle : `lognormalFromMedian(390, 0.42)` → **médiane = 6:30**, paliers
`champion 113 / intermediate 390 / occasional 660`.

| Repère | Valeur actuelle | Réalité « vraie box » (terrain) | Écart |
|---|---|---|---|
| Élite / champion | 113 s (1:53) | 1:47–2:15 — **vrai tail extraterrestre, à GARDER** | OK ✔ |
| **Médiane (P50)** | **390 s (6:30)** | en vraie salle **quasi personne ne passe sous 10:00** → P50 ≈ **11:00 (660 s)** | **−270 s, ~1,7× trop rapide** |
| Intermédiaire (~1 an) | 390 s (6:30) | **~11:00** | idem |
| Débutant / occasional | 660 s (11:00) | **~18:00 (1080 s)** atteignable, non décourageant | **−420 s, ~1,6× trop dur** |

**Conséquence scoring** (vérifiée) : un Fran à **9:50 (590 s)** — soit un pratiquant ~1 an
parfaitement honorable — tombe à **percentile 0,16** (sous le 1er quintile, « mauvais »). Or il
devrait ressortir **« bon / au-dessus du milieu »**. Le modèle dit l'inverse de la réalité.

Cause : la médiane 6:30 et σ=0,42 viennent des bases de données CrossFit (population auto-sélectionnée,
souvent compétitive et Rx), pas d'une vraie salle moyenne. Le « débutant » du modèle est en fait un
pratiquant intermédiaire de compétition.

### 2.2 Le même biais sur les autres benchmarks (homme)

| WOD | Médiane actuelle | Médiane réaliste salle | Champion (garder) | Occasionnel actuel | Occasionnel réaliste |
|---|---|---|---|---|---|
| **Fran** | 6:30 | **11:00** | 1:53 ✔ | 11:00 | **18:00** |
| **Grace** (30 C&J 60 kg) | 4:12 | **6:00** | 1:08 ✔ | 6:40 | **10:00** |
| **Helen** (3 RFT) | 10:40 | **12:30** | 6:30 ✔ | 15:00 | **18:00** |
| **Karen** (150 WB) | 10:00 | **11:30** | 5:00 ✔ | 14:00 | **17:00** |
| **Jackie** | 9:00 | **9:30** (ok) | 5:00 ✔ | 12:00 | **14:00** |
| **Murph** (gilet) | 55:00 | **52:00** (ok) | 33:20 ✔ | 80:50 | **75:00** |
| **Le Chaos** (cap 15') | 12:00 | **12:00** (ok, borné cap) | 7:10 ✔ | 17:00 | cap |

Lecture : **les benchmarks « courts et chargés » (Fran, Grace) sont les plus faux** (médiane ~1,5–1,7×
trop rapide) parce que la base CrossFit y est la plus auto-sélectionnée. Les WODs longs/cardio
(Jackie, Murph, courses, Le Chaos) sont déjà à peu près réalistes (recalibrés 29/06). La σ de Fran/Grace
(0,42–0,45) est en plus trop SERRÉE pour une population de salle hétérogène (devrait être ~0,30–0,34).

---

## 3. PLAN 10/10 — chiffré et actionnable

### (a) per-user — AJOUTER les blueprints manquants

Règle d'or à coder dans un test d'intégrité (`wod-blueprints.spec.ts`) :
> **Tout WOD `WODS` loguable avec ≥ 2 mouvements distincts OU ≥ 1 mouvement chargé DOIT avoir une
> entrée dans `WOD_BLUEPRINTS`.** Le test échoue sinon (interdit le repli population silencieux).

À ajouter dans `apps/score-service/src/wods/wod-blueprints.data.ts` (tous les `movementId` ci-dessous
existent déjà dans `movements.data.ts`) :

```ts
// Le Chaos — chipper pour le temps (cap 15 min) : 400 m + 40 air squats + 30 sit-ups + 20 burpees + 10 wall walks + 400 m.
league_hybrid_chipper: {
  blocks: [
    { movementId: "run",       repsPerRound: [400] },
    { movementId: "air_squat", repsPerRound: [40]  },
    { movementId: "sit_up",    repsPerRound: [30]  },
    { movementId: "burpee",    repsPerRound: [20]  },
    { movementId: "wall_walk", repsPerRound: [10]  },
    { movementId: "run",       repsPerRound: [400] },
  ],
},

// Murph — 1600 m + 100 tractions + 200 pompes + 300 air squats + 1600 m (gilet 9/6 kg = NON modélisé en charge
// de barre ; le gilet alourdit course+gym uniformément → on le laisse hors loadKg, la lenteur vient de la FORCE
// faible sur 100 tractions strictes via athleteRate + maxSet).
murph: {
  blocks: [
    { movementId: "run",       repsPerRound: [1600] },
    { movementId: "pull_up",   repsPerRound: [100]  },
    { movementId: "push_up",   repsPerRound: [200]  },
    { movementId: "air_squat", repsPerRound: [300]  },
    { movementId: "run",       repsPerRound: [1600] },
  ],
},

// Isabel — 30 arrachés (snatch) 60/40 kg, un seul « tour » de 30. La pénalité de charge relative DOIT jouer.
isabel: {
  blocks: [{ movementId: "snatch", repsPerRound: [30], loadKg: { male: 60, female: 40 } }],
},

// La Flèche — échelle de sprint 100-200-300-400-300-200-100 m (1600 m). Récup imposée non comptée → un seul
// « tour » multi-distances. Mouvement `sprint` (≤200 m) ou `run` ; on garde `run` pour les segments ≥300 m et
// `sprint` pour ≤200 m via 2 blocs, OU plus simple : un bloc `run` de 1600 m total (perd la structure d'échelle).
// Recommandé (réaliste) — segmenter par distance avec le bon mouvement :
league_sprint_ladder: {
  blocks: [
    { movementId: "sprint", repsPerRound: [100, 200] },   // ≤200 m = sprint
    { movementId: "run",    repsPerRound: [300, 400, 300] },
    { movementId: "sprint", repsPerRound: [200, 100] },
  ],
  // NB : la récup imposée (30/45/60 s) NE compte pas dans le score → ne pas l'ajouter. Le temps prédit
  // est le temps de course cumulé (1600 m), cohérent avec scoringNote.
},

// Le Moteur — AMRAP 12 min : 400 m course (NON comptée) + 20 air squats + 15 burpees. Score = reps (air squats+burpees).
// Le moteur compte le 400 m dans le TEMPS du tour mais le workPerRound ne doit agréger QUE les reps scorées.
// ⚠️ estimateBlueprintVolume agrège TOUT le workPerRound (reps+mètres) → la course gonflerait le volume.
// CORRECTIF requis (cf. §3a-bis) : marquer le bloc course comme `unscored` pour qu'il compte au temps mais pas au volume.
league_engine_12: {
  blocks: [
    { movementId: "run",       repsPerRound: [400], /* unscored: true */ },
    { movementId: "air_squat", repsPerRound: [20]  },
    { movementId: "burpee",    repsPerRound: [15]  },
  ],
  amrap: { timeCapSec: 720, scoreUnit: "reps" },
},

// Le Pilier — AMRAP 12 min : 40 fentes + 30 air squats + 20 sit-ups + 16 pistols. Score = reps totales.
league_grind_squats: {
  blocks: [
    { movementId: "lunge",        repsPerRound: [40] },
    { movementId: "air_squat",    repsPerRound: [30] },
    { movementId: "sit_up",       repsPerRound: [20] },
    { movementId: "pistol_squat", repsPerRound: [16] },
  ],
  amrap: { timeCapSec: 720, scoreUnit: "reps" },
},

// La Détente — AMRAP 12 min : 30 squat jumps + 25 burpee broad jumps. Score = reps totales.
league_power_amrap: {
  blocks: [
    { movementId: "squat_jump",        repsPerRound: [30] },
    { movementId: "burpee_broad_jump", repsPerRound: [25] },
  ],
  amrap: { timeCapSec: 720, scoreUnit: "reps" },
},

// HYROX solo — 8×(1000 m course + 1 station). Stations : SkiErg 1000 m, Sled Push 50 m, Sled Pull 50 m,
// Burpee Broad Jump 80 m, Row 1000 m, Farmers Carry 200 m, Sandbag Lunges 100 m, 100 Wall Balls.
// Mapping : ski_erg_cal n'est pas en mètres → approx Row pour SkiErg (proche), sled_pull absent → sled_push×2.
hyrox_solo: {
  blocks: [
    { movementId: "run",               repsPerRound: [8000] },   // 8×1000 m agrégés
    { movementId: "ski_erg_cal",       repsPerRound: [70]   },   // ~1000 m SkiErg ≈ 70 cal
    { movementId: "sled_push",         repsPerRound: [100]  },   // push 50 + pull 50 ≈ 100 m push-équiv
    { movementId: "burpee_broad_jump_m", repsPerRound: [80] },
    { movementId: "row",               repsPerRound: [1000] },
    { movementId: "farmers_carry",     repsPerRound: [200]  },
    { movementId: "lunge_m",           repsPerRound: [100]  },
    { movementId: "wall_ball",         repsPerRound: [100], loadKg: { male: 9, female: 6 } },
  ],
},
```

**§3a-bis — correctif moteur nécessaire pour les AMRAP « course non comptée » (Le Moteur)** :
ajouter un drapeau `unscored?: boolean` sur `WodBlueprintBlock`. Dans `estimateRound`/`estimateBlueprintVolume`,
le bloc `unscored` contribue au `roundTimeSec` (il prend du temps) mais **PAS** au `workPerRound`
(il n'est pas dans le score). Sinon le 400 m gonfle le volume de reps prédit (Le Moteur).
~15 lignes, testable.

**§3a-ter — note Murph gilet** : le gilet lesté (9/6 kg) ralentit course + gym uniformément. Ne pas le
modéliser en `loadKg` (qui ne s'applique qu'aux mouvements de la table `ELITE_1RM_FACTOR` : pull_up/push_up/
air_squat n'y sont pas). La lenteur réaliste vient déjà de `athleteRate` (force faible → cadence pull-up
basse) + `maxSet` (coupures). Si on veut intégrer le gilet plus tard : multiplicateur global ~1,08 sur le temps.

**Résultat attendu après ajout** (profil soso) :
- Murph : la force faible effondre la cadence des 100 tractions (pull_up `attributes` = 50 % strength)
  + 200 pompes → temps prédit **monte nettement** vs repli population. Cible plausible ~55–65 min.
- Le Chaos : profil hybride moyen → ~11–13 min, **plus lent que le champion 7m10** (cohérent terrain).
- Isabel : pénalité de charge sur snatch 60 kg vs 1RM estimé → temps réaliste, pas la moyenne population.

### (b) niveaux — RECALIBRER pour des temps de SALLE

Principe : **élite = vrai tail (proReference INCHANGÉ)** ; **intermédiaire (= médiane modèle) =
pratiquant ~1 an réaliste** ; **débutant (occasionnel ≈ P10-12) = atteignable, non décourageant**.
Élargir σ sur les WODs courts/chargés (population de salle hétérogène).

> ⚠️ Recalibrer `wods.data.ts` (médiane + σ) **déplace la NOTATION** (c'est voulu et assumé ici : la
> notation actuelle est FAUSSE — un 9m50 Fran « sous le 1er quintile » est un bug de calibrage, pas
> une décision produit). Garder `proReference`, `hardMin`, `hardMax` cohérents (proRef < médiane pour
> les `time`). Mettre à jour `wod-levels.data.ts` en miroir (inter = médiane, occ ≈ P10-12).

#### Tableau des cibles — HOMMES (les plus faux d'abord)

| WOD | champ (proRef, garder) | **médiane/inter (cible)** | **occ/débutant (cible)** | σ actuelle → cible | Source/raisonnement |
|---|---|---|---|---|---|
| **Fran** | 113 s (1:53) ✔ | **660 s (11:00)** (était 390) | **1080 s (18:00)** (était 660) | 0,42 → **0,34** | Box moyenne : quasi personne < 10:00 ; 1 an de pratique ≈ 11 min Rx ; débutant scalé ≈ 18 min. |
| **Grace** | 90 s (1:30) ✔ | **360 s (6:00)** (était 252) | **600 s (10:00)** (était 400) | 0,45 → **0,36** | 60 kg C&J : régulier ~6 min (séries de 3-5) ; débutant ~10 min (singles). |
| **Helen** | 433 s (7:13) ✔ | **750 s (12:30)** (était 640) | **1080 s (18:00)** (était 900) | 0,29 → **0,30** | 3 RFT cardio : régulier ~12-13 min ; débutant ~18 min. Léger ajustement. |
| **Karen** | 300 s (5:00) ✔ | **690 s (11:30)** (était 600) | **1020 s (17:00)** (était 840) | (pointTable) | 150 WB : régulier ~11-12 min ; débutant ~17 min. Décaler les nœuds P50→690, P10→1020. |
| **Jackie** | 315 s ✔ | **570 s (9:30)** (était 540) | **840 s (14:00)** (était 720) | (pointTable) | Quasi ok ; léger décalage queue lente. |
| **Hyrox Sprint** | 660 s ✔ | **1080 s (18:00)** (était 1020) | **1500 s (25:00)** (était 1380) | 0,26 → **0,28** | Sprint Hyrox amateur ~18 min ; débutant ~25 min. |
| **Benchmark Zéro** | 345 s ✔ | **720 s (12:00)** (était 630) | **1080 s (18:00)** (était 900) | (pointTable) | Sans matériel : régulier ~12 min, débutant ~18 min. |
| **Machine & Mur** | 360 s ✔ | **750 s (12:30)** (était 660) | **1080 s (18:00)** (était 960) | 0,31 → **0,31** | wall walks + t2b lents pour un amateur. |

WODs **déjà réalistes — NE PAS toucher** (recalibrés 29/06 ou course pure) : Murph, Le Chaos et les 5
Ligue, les courses (run_*, track/semi/marathon), row_2k, Isabel, Hyrox solo.

#### Vérification de cohérence scoring (le test qui doit passer)
Après recalibrage Fran (médiane 660 s, σ 0,34) :

| Résultat Fran (H) | Ancien percentile | **Nouveau percentile** | Lecture |
|---|---|---|---|
| 9:50 (590 s) | 0,16 (« mauvais ») | **~0,57** | **« bon / au-dessus du milieu »** ✔ (objectif atteint) |
| 11:00 (660 s) | 0,12 | **0,50** | médiane = pratiquant 1 an ✔ |
| 6:30 (390 s) | 0,50 | **~0,82** | très bon (rare en salle) ✔ |
| 1:53 (113 s) | ~0,999 | **~0,999** | élite intacte ✔ |

→ Ajouter un test golden `score.calibration.spec.ts` : `percentile("fran","male",590)` ∈ [0,50 ; 0,65].

#### Cibles FEMMES (mêmes ratios, σ identiques)
Fran F : champ 135 s ✔ / **inter 780 s (13:00)** (était 450) / **occ 1260 s (21:00)** (était 780), σ 0,42→0,34.
Grace F : champ 120 s ✔ / **inter 420 s (7:00)** / **occ 660 s (11:00)**, σ 0,42→0,36.
Les autres WODs femmes : appliquer le même décalage proportionnel (inter ×1,7 sur Fran/Grace, ×1,15 sur
Helen/Karen/BMZ/Machine&Mur), σ alignée sur l'homologue masculin.

---

## 4. Récapitulatif actionnable (checklist dev)

1. **`wod-blueprints.data.ts`** : ajouter les 8 blueprints (§3a). Tous les `movementId` existent.
2. **`wod-blueprint.types` / `wod-time-engine.ts`** : ajouter `unscored?: boolean` au bloc + l'exclure
   de `workPerRound` (§3a-bis), pour Le Moteur (course non comptée).
3. **Test d'intégrité** `wod-blueprints.spec.ts` : tout WOD loguable ≥2 mouvements OU chargé ⇒ blueprint
   présent (interdit le repli silencieux). Liste blanche explicite pour les mono/course/1RM.
4. **`wods.data.ts`** : recalibrer médiane + σ des 8 WODs « compétition » (§3b tableau). Garder proRef/hardMin/hardMax cohérents.
5. **`wod-levels.data.ts`** : réaligner inter = médiane, occ ≈ P10-12 sur ces 8 WODs.
6. **Tests** : golden `score.calibration.spec.ts` (Fran 590 s ∈ [0,50;0,65]) + estimate golden pour
   Murph/Le Chaos/Isabel (soso : élite < soso < débutant, valeurs bornées et réalistes).
7. **REBUILD + redémarrer le process score-service :3001** (mémoire projet : données en mémoire sinon périmées).

---

## 5. Fichiers concernés (chemins absolus)
- `E:\HYBRID INDEX\hybrid-index-starter\hybrid-index\apps\score-service\src\wods\wod-blueprints.data.ts` (ajout blueprints)
- `E:\HYBRID INDEX\hybrid-index-starter\hybrid-index\apps\score-service\src\score\wod-time-engine.ts` (flag `unscored`)
- `E:\HYBRID INDEX\hybrid-index-starter\hybrid-index\apps\score-service\src\wods\wods.data.ts` (recalibrage médianes/σ)
- `E:\HYBRID INDEX\hybrid-index-starter\hybrid-index\apps\score-service\src\wods\wod-levels.data.ts` (réalignement paliers)
- `E:\HYBRID INDEX\hybrid-index-starter\hybrid-index\apps\score-service\src\score\scoring.service.ts` (chemin `predictResult`, inchangé sauf si on ajoute un flag de confiance « repli » loggué)
- Tests : `apps\score-service\test\estimate.golden.spec.ts`, nouveau `wod-blueprints.spec.ts`, nouveau `score.calibration.spec.ts`
