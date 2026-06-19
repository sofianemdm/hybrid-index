# HYBRID INDEX — Spécification sport-science : les 15 WODs & la chaîne de notation

> **Statut.** Spec de référence produite par l'agent `sport-science`. Source de vérité amont :
> `docs/cahier-des-charges.md` (§5, §6, §7). Données de calibration : `docs/reference-data-sources.md`.
> **Verrous respectés** : score 0→1000 normalisé **PAR SEXE uniquement** (jamais âge/poids) ;
> le score **ne baisse jamais** automatiquement (on garde le meilleur effort dans la fenêtre de
> fraîcheur de 26 semaines) ; **pas de score de fatigue** ; Force sans matériel = **proxy
> bodyweight** marqué `isEstimated`.
>
> **Architecture unificatrice (rappel §0/§5).**
> `effort brut R` → `percentile P vs élite, par sexe` → `courbe f` → `sous-score 0–1000`
> → agrégé en **6 attributs** → agrégé en **HYBRID INDEX 0–1000`.
>
> **Versionnage.** La fonction `f`, les poids `w_A` et chaque `ReferenceDistribution` portent une
> `version`. Le Service Score recalcule l'historique quand l'une d'elles change (cf. §15 CdC).
> Version courante de cette spec : **`scoring-v1`**, `f = sigmoid-v1`, poids `weights-v1`.

---

## 0. Conventions & notations

- **Sexe `S ∈ {H, F}`** : seule dimension de normalisation. Toutes les distributions sont définies par sexe.
- **Résultat brut `R`** : exprimé dans l'unité du `scoreType` du WOD.
  - `time` : secondes (plus bas = meilleur).
  - `reps` : répétitions ou tours (plus haut = meilleur).
  - `load` : kg (plus haut = meilleur) — non utilisé dans les 15 benchmarks, réservé aux customs.
  - `distance` : mètres (plus haut = meilleur).
- **Sens de la métrique `dir(WOD)`** : `+1` si « plus haut = meilleur » (reps/load/distance),
  `-1` si « plus bas = meilleur » (time). Géré explicitement dans `P(R)`.
- **Percentile `P ∈ [0,1]`** : fraction de la population pratiquante de sexe `S` que l'athlète bat.
  `P = 0.5` = médiane ; `P → 1` = élite ; `P → 0` = très en dessous du seuil d'entrée.
- **Sous-score** : `subScore = round(1000 × f(P))`, entier 0–1000.
- Les temps sont notés `mm:ss` ; convertis en secondes pour tout calcul.

### Les 6 attributs (radar, §5.1)
`engine` · `vitesse` · `force` (proxy si sans matériel, `isEstimated`) · `puissance`
· `enduranceMusculaire` · `hybride`.

---

## 1. Fiches détaillées des 15 WODs

Chaque fiche reprend le §7 (mouvements, reps, charges H/F, type, `scoreType`, attributs, matériel,
`isBenchmark = true` pour les 15). On y ajoute les **bornes physiologiques plausibles par sexe**
(`hardMin`/`hardMax`), utilisées par l'anti-triche §5.5 : tout `R` strictement hors `[hardMin, hardMax]`
est **refusé / marqué `isFlagged` et exclu des classements**. Les bornes sont volontairement larges
(on ne pénalise pas un athlète d'exception : on bloque l'impossible).

> Convention bornes pour les `time` : `hardMin` = temps le plus rapide physiquement crédible
> (au-delà = triche/erreur), `hardMax` = plafond de coupure (au-delà = abandon/erreur de saisie,
> on plafonne au lieu de refuser). Pour `reps` : `hardMin` plancher (≥ 0 réaliste), `hardMax` plafond record.

### AVEC MATÉRIEL (8)

#### WOD 1 — PFT HYROX (signature « avec matériel »)
- **Mouvements** : 1000 m run · 50 burpee broad jumps · 100 fentes · 1000 m row · 30 pompes HR · 100 wall balls.
- **Charges Rx** : wall ball 9/6 kg (H/F) ; reste au poids de corps. **Type** : For Time. **scoreType** : `time`.
- **Attributs** : `engine`, `enduranceMusculaire`, `puissance`, `hybride`. **Matériel** : rameur, wall ball. `isBenchmark`.
- **Note** : format PROPRIÉTAIRE inspiré HYROX (≠ HYROX officiel 8 km + 8 stations). À recalibrer si les distances changent.
- **Bornes** : H `[hardMin 14:00, hardMax 60:00]` · F `[hardMin 16:00, hardMax 70:00]`.

#### WOD 2 — Fran
- **Mouvements** : 21-15-9 thrusters + tractions. **Charges Rx** : thruster 43/29 kg. **Type** : For Time. **scoreType** : `time`.
- **Attributs** : `enduranceMusculaire`, `puissance`. **Matériel** : barre, barre de traction. `isBenchmark`.
- **Bornes** : H `[hardMin 1:45, hardMax 25:00]` · F `[hardMin 2:15, hardMax 30:00]`.

#### WOD 3 — Grace
- **Mouvements** : 30 clean & jerk. **Charges Rx** : 61/43 kg. **Type** : For Time. **scoreType** : `time`.
- **Attributs** : `puissance`, `force`. **Matériel** : barre. `isBenchmark`.
- **Bornes** : H `[hardMin 0:55, hardMax 20:00]` · F `[hardMin 1:20, hardMax 25:00]`.

#### WOD 4 — Jackie
- **Mouvements** : 1000 m row · 50 thrusters · 30 tractions. **Charges Rx** : thruster 20/15 kg. **Type** : For Time. **scoreType** : `time`.
- **Attributs** : `engine`, `enduranceMusculaire`, `puissance`, `force`. **Matériel** : rameur, barre, barre de traction. `isBenchmark`.
- **Bornes** : H `[hardMin 5:00, hardMax 30:00]` · F `[hardMin 6:00, hardMax 35:00]`.

#### WOD 5 — 2000 m Rameur (Concept2)
- **Mouvements** : 2000 m row. **Type** : Temps. **scoreType** : `time`.
- **Attributs** : `engine`. **Matériel** : rameur. `isBenchmark`.
- **Bornes** : H `[hardMin 5:30, hardMax 12:00]` · F `[hardMin 6:30, hardMax 13:30]`. (`hardMin` = sous le record logbook 2024.)

#### WOD 6 — Helen
- **Mouvements** : 3 tours (400 m run · 21 KB swings · 12 tractions). **Charges Rx** : KB 24/16 kg. **Type** : For Time. **scoreType** : `time`.
- **Attributs** : `engine`, `enduranceMusculaire`, `hybride`. **Matériel** : kettlebell, barre de traction. `isBenchmark`.
- **Bornes** : H `[hardMin 6:30, hardMax 22:00]` · F `[hardMin 7:30, hardMax 25:00]`.

#### WOD 7 — Karen
- **Mouvements** : 150 wall balls. **Charges Rx** : 9/6 kg (cible 10/9 ft). **Type** : For Time. **scoreType** : `time`.
- **Attributs** : `puissance`, `enduranceMusculaire`. **Matériel** : wall ball. `isBenchmark`.
- **Bornes** : H `[hardMin 3:30, hardMax 25:00]` · F `[hardMin 4:00, hardMax 28:00]`.

#### WOD 8 — Cindy
- **Mouvements** : AMRAP 20 min (5 tractions · 10 pompes · 15 air squats). **Type** : AMRAP. **scoreType** : `reps` (score = **tours**, fractions de tour gérées en reps/20).
- **Attributs** : `enduranceMusculaire`, `engine`. **Matériel** : barre de traction. `isBenchmark`.
- **Bornes** : H `[hardMin 3, hardMax 32]` tours · F `[hardMin 2, hardMax 28]` tours.

### SANS MATÉRIEL (7)

#### WOD 9 — Benchmark Zéro (signature « sans matériel »)
- **Mouvements** : 1 km run · 30 pompes · 30 air squats · 1 km run. **Type** : For Time. **scoreType** : `time`.
- **Attributs** : `engine`, `enduranceMusculaire`, `hybride`. **Matériel** : aucun. `isBenchmark`.
- **Bornes** : H `[hardMin 6:30, hardMax 35:00]` · F `[hardMin 7:30, hardMax 40:00]`.

#### WOD 10 — 5 km Course
- **Mouvements** : 5 km run. **Type** : Temps. **scoreType** : `time`.
- **Attributs** : `engine`. **Matériel** : aucun. `isBenchmark`.
- **Bornes** : H `[hardMin 13:30, hardMax 70:00]` · F `[hardMin 15:00, hardMax 75:00]`.

#### WOD 11 — 1 km Course
- **Mouvements** : 1 km run. **Type** : Temps. **scoreType** : `time`.
- **Attributs** : `vitesse`, `engine`. **Matériel** : aucun. `isBenchmark`.
- **Bornes** : H `[hardMin 2:25, hardMax 12:00]` · F `[hardMin 2:45, hardMax 14:00]`.

#### WOD 12 — Max pompes strictes (à l'échec)
- **Mouvements** : pompes strictes au sol, gainage. **Type** : Reps. **scoreType** : `reps`.
- **Attributs** : `force` (**proxy bodyweight, `isEstimated`**), `enduranceMusculaire`. **Matériel** : aucun. `isBenchmark`.
- **Bornes** : H `[hardMin 0, hardMax 110]` · F `[hardMin 0, hardMax 80]`.

#### WOD 13 — Max air squats en 2 min
- **Mouvements** : air squats, fenêtre 2 min. **Type** : Reps. **scoreType** : `reps`.
- **Attributs** : `enduranceMusculaire`, `puissance`. **Matériel** : aucun. `isBenchmark`.
- **Bornes** : H `[hardMin 10, hardMax 130]` · F `[hardMin 10, hardMax 125]`.

#### WOD 14 — Test burpees 7 min (max reps)
- **Mouvements** : burpees, fenêtre 7 min. **Type** : Reps. **scoreType** : `reps`.
- **Attributs** : `engine`, `enduranceMusculaire`, `puissance`, `hybride`. **Matériel** : aucun. `isBenchmark`.
- **Bornes** : H `[hardMin 15, hardMax 160]` · F `[hardMin 12, hardMax 145]`.

#### WOD 15 — Max sit-ups en 2 min
- **Mouvements** : sit-ups, fenêtre 2 min. **Type** : Reps. **scoreType** : `reps`.
- **Attributs** : `enduranceMusculaire` (gainage/core). **Matériel** : aucun. `isBenchmark`.
- **Bornes** : H `[hardMin 10, hardMax 105]` · F `[hardMin 10, hardMax 105]`.

> **Couverture des 6 attributs des deux côtés** (vérifiée) : voir §8. Angle mort assumé (§7 CdC) :
> Puissance explosive pure sans matériel repose surtout sur burpees/air squats.

---

## 2. Distributions de référence par sexe

### 2.1 Choix de modèle

On utilise **deux familles** de distributions, choisies selon la qualité des données :

- **Modèle paramétrique (loi log-normale sur la métrique « brute »)** quand on dispose d'une
  **moyenne + écart-type sourcés** (Grace, Helen) ou d'une distribution exploitable.
  - Les **temps** (`time`) sont positifs et asymétriques à droite → **log-normale** : `ln(R) ~ N(μ, σ)`.
  - Les **reps** (grands compteurs, ~symétriques) → **normale** : `R ~ N(μ, σ)` tronquée à `hardMin`.
- **Modèle par table de points de percentile (PCHIP / interpolation monotone)** quand on n'a
  que des ancrages de coaching (élite / 90e / médiane / 10e). On stocke `{P_k → R_k}` et on
  interpole de façon **monotone** entre les nœuds (et extrapole linéairement aux extrêmes,
  bornée par `hardMin`/`hardMax`).

Chaque `ReferenceDistribution` porte : `wodId`, `sex`, `model ∈ {lognormal, normal, pointTable}`,
les paramètres, `source` (`public`/`community`), `n`, `confidence ∈ {high, medium, low}`,
`proReference` (le R « pro/élite » affiché dans le reveal), `version`.

> **Convention de conversion µ/σ → table.** Pour un modèle paramétrique, le percentile se calcule
> analytiquement (§3). Pour les WODs « médiane + σ » on dérive les nœuds via les quantiles normaux
> standard `z(0.1)=−1.2816`, `z(0.25)=−0.6745`, `z(0.75)=0.6745`, `z(0.9)=1.2816`, `z(0.99)=2.3263`.

### 2.2 Tables paramétriques par WOD (toutes les valeurs ancrées sur `reference-data-sources.md`)

> Lecture : pour `time`, on donne la **médiane** (≈ centre) et le **σ** ; pour log-normale, σ est
> sur l'échelle log (`σ_ln`). Quand seule une plage est sourcée, on a fitté `σ` pour que les nœuds
> 10e/90e collent aux ancrages. `proReference` = colonne « pro/élite » du reveal.

| # | WOD | scoreType | Sexe | Modèle | Médiane (R50) | σ (échelle) | proReference | Source(s) | Confiance |
|---|-----|-----------|------|--------|---------------|-------------|--------------|-----------|-----------|
| 1 | PFT HYROX | time | H | lognormal | 5100 s (1:25:00) | σ_ln=0.18 | 3300 s (55:00) | HyroxInsider/Hyroxy | medium |
| 1 | PFT HYROX | time | F | lognormal | 5700 s (1:35:00) | σ_ln=0.18 | 3660 s (61:00) | id. | medium |
| 2 | Fran | time | H | lognormal | 345 s (5:45) | σ_ln=0.30 | 135 s (2:15) | Przilla/Coachweb | medium |
| 2 | Fran | time | F | lognormal | 390 s (6:30) | σ_ln=0.30 | 165 s (2:45) | extrapolé +25% | low-medium |
| 3 | Grace | time | H | lognormal | 203 s (3:23) | σ_ln=0.42 | 90 s (1:30) | Cebul.la/Rhapsody (µ 3:23, σ 1:34) | **high** |
| 3 | Grace | time | F | lognormal | 236 s (3:56) | σ_ln=0.39 | 120 s (2:00) | id. (µ 3:56, σ 1:38) | **high** |
| 4 | Jackie | time | H | pointTable | 540 s (9:00) | — | 360 s (6:00) | WODStar/Rhapsody | low-medium |
| 4 | Jackie | time | F | pointTable | 630 s (10:30) | — | 420 s (7:00) | WODStar | low |
| 5 | 2000 m Row | time | H | lognormal | 450 s (7:30) | σ_ln=0.085 | 370 s (6:10) | Concept2 Logbook 2024 | medium |
| 5 | 2000 m Row | time | F | lognormal | 510 s (8:30) | σ_ln=0.085 | 435 s (7:15) | id. | medium |
| 6 | Helen | time | H | lognormal | 590 s (9:50) | σ_ln=0.16 | 433 s (7:13) | Cebul.la/CrossFit.com (µ 9:50) | **high (µ) / medium (σ)** |
| 6 | Helen | time | F | lognormal | 674 s (11:14) | σ_ln=0.16 | 510 s (8:30) | id. (µ 11:14) | high (µ) / medium (σ) |
| 7 | Karen | time | H | pointTable | 570 s (9:30) | — | 240 s (4:00) | WODtimecalc/Rhapsody | medium |
| 7 | Karen | time | F | pointTable | 630 s (10:30) | — | 300 s (5:00) | id. (estimé +10–15%) | low-medium |
| 8 | Cindy | reps(tours) | H | normal | 16 tours | σ=4.0 | 23 tours | Fitnessvolt/Przilla | medium |
| 8 | Cindy | reps(tours) | F | normal | 13 tours | σ=3.5 | 20 tours | id. | medium |
| 9 | Benchmark Zéro | time | H | pointTable | 810 s (13:30) | — | 540 s (9:00) | **ESTIMÉ** (somme composantes) | **low** |
| 9 | Benchmark Zéro | time | F | pointTable | 960 s (16:00) | — | 630 s (10:30) | **ESTIMÉ** | **low** |
| 10 | 5 km Course | time | H | pointTable | 1878 s (31:18) | — | 1050 s (17:30) | RunRepeat (pct 1/10/50/90) | **high** |
| 10 | 5 km Course | time | F | pointTable | 2184 s (36:24) | — | 1170 s (19:30) | RunRepeat | **high** |
| 11 | 1 km Course | time | H | lognormal | 300 s (5:00) | σ_ln=0.22 | 180 s (3:00) | RunningLevel/MarathonHB (dérivé mile) | medium |
| 11 | 1 km Course | time | F | lognormal | 360 s (6:00) | σ_ln=0.22 | 210 s (3:30) | id. | medium |
| 12 | Max pompes | reps | H | normal | 25 | σ=11 | 60 | TopEndSports/ACSM | **high** |
| 12 | Max pompes | reps | F | normal | 12 | σ=7 | 35 | id. | **high** |
| 13 | Air squats 2 min | reps | H | normal | 50 | σ=12 | 85 | TopEndSports 1 min ×2 | **low-medium** |
| 13 | Air squats 2 min | reps | F | normal | 45 | σ=11 | 80 | id. | low-medium |
| 14 | Burpees 7 min | reps | H | normal | 70 | σ=18 | 125 | Guinness (bornes) | **low** |
| 14 | Burpees 7 min | reps | F | normal | 60 | σ=16 | 110 | id. | **low** |
| 15 | Sit-ups 2 min | reps | H | normal | 50 | σ=11 | 80 | Military.com APFT | **high** |
| 15 | Sit-ups 2 min | reps | F | normal | 45 | σ=11 | 80 | id. (barème ~identique) | **high** |

> **Calage des σ log-normaux.** Pour Grace H, la source donne µ_arith=203 s, σ_arith=94 s → CV≈0.46
> → `σ_ln = sqrt(ln(1+CV²)) ≈ 0.43` (arrondi 0.42), `µ_ln = ln(203) − σ_ln²/2 ≈ 5.22`. La médiane
> log-normale = `exp(µ_ln) ≈ 185 s` (légèrement < moyenne, attendu pour une asymétrie droite). On
> stocke la **médiane** comme `exp(µ_ln)` ; ci-dessus on a affiché la moyenne arithmétique sourcée
> par lisibilité — l'implémentation calcule `µ_ln, σ_ln` exacts. Pour les WODs « plage seulement »,
> σ_ln est fitté pour faire passer R10/R90 sur les ancrages.

### 2.3 Tables de points pour les WODs `pointTable`

Nœuds `{P → R(s)}` (interpolation monotone PCHIP, extrapolation linéaire bornée). Source/confiance en §2.2.

**WOD 4 Jackie** — H : `{0.05→780, 0.10→780(13:00), 0.25→600, 0.50→540, 0.75→480, 0.90→450(7:30), 0.99→360}`.
F : `{0.10→900(15:00), 0.25→720, 0.50→630, 0.75→540, 0.90→510(8:30), 0.99→420}`.

**WOD 7 Karen** — H : `{0.10→840(14:00), 0.25→660, 0.50→570, 0.75→420, 0.90→390(6:30), 0.99→240(4:00)}`.
F : `{0.10→900(15:00), 0.25→720, 0.50→630, 0.75→480, 0.90→450, 0.99→300(5:00)}`.

**WOD 9 Benchmark Zéro** — H : `{0.10→1200(20:00), 0.25→960, 0.50→810(13:30), 0.75→690, 0.90→600, 0.99→540(9:00)}`.
F : `{0.10→1380(23:00), 0.25→1140, 0.50→960(16:00), 0.75→810, 0.90→720, 0.99→630(10:30)}`.

**WOD 10 5 km** (RunRepeat pct sourcés, le plus solide) — H : `{0.10→3202(53:22), 0.50→1878(31:18), 0.90→1326(22:06), 0.99→1069(17:49)}`.
F : `{0.10→3391(56:31), 0.50→2184(36:24), 0.90→1516(25:16), 0.99→1169(19:29)}`.
> Note : ici `P` = « bat X% » donc le 90e percentile RunRepeat (les 10% plus lents) correspond à
> `P=0.10` dans notre convention. Les nœuds ci-dessus sont déjà retournés dans la convention HYBRID.

> **Priorité recalibrage communautaire** (confiance `low`) : **WOD 9 Benchmark Zéro**, **WOD 14
> Burpees 7 min**, **WOD 13 Air squats 2 min**. Dès `n ≥ N_min` (proposé 200 résultats valides par
> sexe), bascule `source: community` et recalcul des percentiles empiriques.

---

## 3. La fonction percentile `P(R, WOD, S)`

Renvoie la fraction de la population de sexe `S` battue par le résultat `R`. **Gère le sens** via `dir`.

### 3.1 Modèle log-normal (time)
Soit `µ_ln, σ_ln` les paramètres log de la distribution. On définit la position normalisée
`z = (ln(R) − µ_ln) / σ_ln`. Comme **plus bas = meilleur** (`dir = −1`) :

```
P = 1 − Φ(z)        // Φ = CDF normale standard
```

(Un `R` très rapide → `z` très négatif → `Φ(z) → 0` → `P → 1`. Cohérent.)

### 3.2 Modèle normal (reps, plus haut = meilleur, `dir = +1`)
`z = (R − µ) / σ` puis :

```
P = Φ(z)
```

(Beaucoup de reps → `z` grand → `P → 1`.)

### 3.3 Modèle pointTable
Soit `g` l'interpolant monotone des nœuds `{P_k → R_k}`. On inverse `g` :

```
P = g⁻¹(R)          // inversion monotone (les R_k sont monotones en P après orientation dir)
```

Implémentation : on stocke les nœuds déjà orientés (P croissant ⇒ performance croissante),
on recherche l'intervalle encadrant `R`, on interpole `P` linéairement/PCHIP. Extrapolation linéaire
au-delà des nœuds extrêmes, **clampée** : `P = clamp(P, 0.001, 0.999)`.

### 3.4 Clamp & bornes
- Avant calcul : si `R` hors `[hardMin, hardMax]` → résultat **refusé** (`isFlagged`, hors classement, §5.5).
- Après calcul : `P = clamp(P, 0.001, 0.999)` (jamais 0 ni 1 exact → évite sous-score 0/1000 dégénéré).

---

## 4. La courbe de calibration `f(P) → sous-score [0,1000]`

### 4.1 Cahier des charges de la courbe (`f = sigmoid-v1`)
- **Monotone croissante** sur `[0,1]`, `f(0)=0`, `f(1)=1` (après normalisation des extrêmes).
- **Médiane population ≈ 450/1000** (un athlète médian de sa population reste motivé, pas « moyen = 0 »).
- **Gains rapides au milieu** (zone 0.3–0.7 : effet dopamine débutant/intermédiaire).
- **Gains lents aux extrêmes** (atteindre l'élite coûte cher ; le bas n'est pas écrasé à 0).

### 4.2 Forme retenue : sigmoïde logistique recentrée et renormalisée

```
raw(P) = 1 / (1 + exp(−k · (P − P0)))
f(P)   = (raw(P) − raw(0)) / (raw(1) − raw(0))      // renormalise sur [0,1]
subScore = round(1000 × f(P))
```

**Paramètres par défaut (`sigmoid-v1`)** :

| Param | Valeur | Rôle |
|-------|--------|------|
| `k`   | 6.0    | Pente (raideur centrale ; plus grand = plus « marche d'escalier » au milieu) |
| `P0`  | 0.55   | Centre de la sigmoïde (légèrement > 0.5 → la médiane P=0.5 donne ~450, pas 500) |

> **Pourquoi `P0 = 0.55` donne médiane ≈ 450 ?** Voir table §4.3 : `f(0.5) ≈ 0.45`. Cela réalise
> exactement la cible « médiane population ≈ 450 ».

### 4.3 Table d'exemple `P → sous-score` (`sigmoid-v1`, k=6, P0=0.55)

Calcul : `raw(0)=1/(1+e^{3.3})=0.0356` ; `raw(1)=1/(1+e^{−2.7})=0.9370` ; dénominateur `=0.9014`.

| P | raw(P) | f(P) = (raw−0.0356)/0.9014 | sous-score |
|------|--------|------------|-----------|
| 0.01 | 0.0337 | −0.0021 → clamp 0 | ~0 |
| 0.10 | 0.0556 | 0.0222 | **22** |
| 0.25 | 0.1393 | 0.1151 | **115** |
| 0.50 | 0.4256 | 0.4327 | **433** |
| 0.55 | 0.5000 | 0.5152 | **515** |
| 0.75 | 0.7685 | 0.8131 | **813** |
| 0.90 | 0.9089 | 0.9690 | **969** |
| 0.99 | 0.9698 | 0.9966 | **997** |

> Médiane (P=0.50) → **433** ≈ cible 450 (réglable via `P0` ; baisser `P0` à 0.53 remonte la médiane à ~470).
> Pente raide en 0.5–0.75 (de 433 à 813) = la zone « dopamine » de progression visible. Extrêmes aplatis.
> **`f` est VERSIONNÉE** : tout changement de `k`/`P0`/forme ⇒ nouvelle `version` + recalcul historique.

---

## 5. Score d'attribut (0–1000)

### 5.1 Règle de base (§5.2 CdC)
```
attribute_score(A) = max( subScore(e) pour e ∈ efforts taguant A, age(e) ≤ 26 semaines )
```
- **Meilleur effort** parmi ceux qui taguent l'attribut `A`, dans la **fenêtre de fraîcheur 26 semaines**.
- Un effort tague **plusieurs** attributs (cf. §1/§8) : il alimente chacun d'eux.
- `unlocked(A) = true` dès qu'au moins un effort valide tague `A` dans la fenêtre.
  Attribut non débloqué ⇒ **exclu** du calcul de l'Index (pas compté comme 0).

### 5.2 Fraîcheur & no-drop (verrous)
- **`isStale(A) = true`** si le meilleur effort qui détermine `attribute_score(A)` a un âge entre
  ~8–12 semaines et 26 semaines → affiche « à rafraîchir » + invitation douce. **Le score reste affiché.**
- **Au-delà de 26 semaines** : l'effort sort de la fenêtre. Pour respecter « le score ne baisse
  jamais brutalement », l'implémentation **conserve la dernière valeur connue** comme `attribute_score`
  mais marque `isStale = true` (fortement) et `confidence` dégradée, **jusqu'à ce qu'un nouvel effort
  remplace**. On n'efface jamais un attribut débloqué.
- **No-drop intra-fenêtre** : un nouvel effort **moins bon** ne fait jamais baisser l'attribut
  (on prend le `max`). Un re-test « raté » ne coûte rien → on encourage le re-test sans peur.

### 5.3 Cas du proxy Force sans matériel
- Sans matériel, **aucun WOD ne mesure la Force lourde** (1RM). On dérive `force` depuis le
  **proxy bodyweight** : WOD 12 (max pompes strictes) tague `force` avec `isEstimated = true`.
- `attribute_score(force)` issu uniquement du proxy ⇒ l'attribut porte `isEstimated = true`,
  affiché « estimé » dans le radar et dans la `confidence` de l'Index.
- Dès qu'un WOD avec charge (Grace, Jackie) est logué, **le test chargé fait autorité** : il
  définit `force` et le **proxy pompes ne peut jamais le surclasser** (proxy plafonné au niveau du
  test chargé, ou ignoré pour `force` dès qu'un test chargé existe). `isEstimated = true` **ssi la
  valeur retenue** provient du proxy. *(Décision **D2** — voir `decisions-log.md`.)*

---

## 6. HYBRID INDEX

### 6.1 Formule (§5.2 CdC)
```
HYBRID_INDEX = Σ_{A ∈ débloqués} ( w_A · attribute_score(A) ) / Σ_{A ∈ débloqués} w_A
```
- Moyenne pondérée **sur les attributs débloqués uniquement** (un attribut verrouillé ne tire pas vers le bas).
- Résultat 0–1000, arrondi entier.

### 6.2 Jeux de poids `w_A` par objectif (`weights-v1`)

Ordre des attributs : `engine · vitesse · force · puissance · enduranceMusculaire · hybride`.

| Objectif | engine | vitesse | force | puissance | endMusc | hybride |
|----------|:------:|:-------:|:-----:|:---------:|:-------:|:-------:|
| **HYROX** (améliorer mon temps HYROX) | 1.5 | 1.0 | 0.7 | 1.0 | 1.3 | 1.5 |
| **Force CrossFit** (devenir plus fort) | 0.8 | 0.8 | 1.5 | 1.5 | 1.2 | 1.0 |
| **Partout** (progresser partout) | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

> HYROX surpondère `engine` + `hybride` (+ `endMusc`) ; Force CrossFit surpondère `force` + `puissance` ;
> Partout = poids égaux. Les poids sont **versionnés** (`weights-v1`). Changer l'objectif **ne modifie
> jamais les sous-scores**, seulement l'agrégation → l'Index est recalculé instantanément, l'historique
> reste cohérent par `(objectif, version)`.

### 6.3 Règle « provisoire »
`isProvisional = true` tant que la **couverture** est insuffisante :
- **Couverture OK** si `(nb attributs débloqués ≥ 4)` **OU** `(nb efforts valides loggés ≥ 3)`.
- Sinon l'Index est affiché avec le label **« provisoire »** + invitation à compléter.
- `radarCoverage = nb_attributs_débloqués / 6`. `isEstimated = true` si au moins un attribut entrant
  dans l'Index est estimé (proxy Force).

### 6.4 Percentile de l'Index
On maintient une **distribution de l'Index par sexe** (bootstrap : simulation Monte-Carlo des
sous-scores à partir des distributions §2, puis empirique dès que la communauté grandit).
`index_percentile = P_index(HYBRID_INDEX, S)` → message « meilleur que X % des {hommes|femmes} ».
Modèle initial : **normale** `Index ~ N(µ_idx, σ_idx)` avec, par construction de `f` (médiane→~450),
`µ_idx ≈ 450`, `σ_idx ≈ 140` (à recalibrer empiriquement ; `confidence: public` au départ).

---

## 7. Index projeté

Pour le ciblage d'axe (« +X pts si cet axe atteint Y ») :

```
projected_index(A → Y) = ( Σ_{B∈débloqués, B≠A} w_B·score(B)  +  w_A·Y ) / Σ_{B∈débloqués} w_B
```
- `Y` = sous-score cible pour l'attribut `A` (ex. amener Force au niveau d'Engine : `Y = score(engine)`).
- Si `A` n'est **pas encore débloqué**, on l'inclut au dénominateur lors de la projection
  (`Σ` recalculé avec `A`), pour montrer le gain réel de débloquer l'axe.
- Gain affiché : `Δ = projected_index − HYBRID_INDEX` (et le rang/palier que ça ferait atteindre).

---

## 8. Mapping mouvements → attributs (référence)

Table utilisée pour (a) vérifier la couverture des benchmarks, (b) estimer les WODs **custom**
(modèle §6.3 CdC `Σ coeff_mouvement × charge_relative × volume`).

| Mouvement / modalité | engine | vitesse | force | puissance | endMusc | hybride |
|----------------------|:------:|:-------:|:-----:|:---------:|:-------:|:-------:|
| Course longue (≥3 km) | ●● | | | | | ● |
| Course courte / sprint (≤1 km) | ● | ●● | | ● | | |
| Rameur 2 km | ●● | | | | ● | |
| Rameur sprint (≤500 m) | ● | ● | | ● | | |
| Clean & jerk / snatch (lourd) | | | ●● | ●● | | |
| Thruster (modéré) | | | ● | ●● | ●● | |
| Wall ball | | | | ●● | ●● | |
| KB swing | | | ● | ●● | ● | ● |
| Pompes strictes | | | ●●(proxy) | ●● | | |
| Tractions | | | ● | ● | ●● | |
| Air squats | | | | ● | ●● | |
| Sit-ups / core | | | | | ●● | |
| Burpees | ● | | | ● | ●● | ●● |
| Burpee broad jump | ● | ● | | ●● | ● | ● |
| Fentes (volume) | | | ● | | ●● | ● |
| Enchaînement course+station (Helen/PFT) | ●● | | | ● | ● | ●● |

`●●` = contribution principale (le WOD tague l'attribut) ; `●` = secondaire (poids moindre dans le
modèle custom). **Couverture des 6 attributs** : engine (1,4,5,6,9,10,11,14) · vitesse (11) ·
force (3,4,12) · puissance (1,2,3,4,7,13,14) · endMusc (1,2,4,6,7,8,12,13,15) · hybride (1,6,9,14).
Côté sans matériel : engine(9,10,11,14) · vitesse(11) · force(12 proxy) · puissance(13,14) ·
endMusc(12,13,15) · hybride(9,14). **Les 6 sont couverts des deux côtés.**

---

## 9. Worked examples (chaîne bout-en-bout)

### Exemple A — Homme, objectif « Partout », 3 efforts

1. **Grace** `R = 4:30 = 270 s`. Distrib H log-normale (µ_arith 203, σ 94 → `σ_ln≈0.43`,
   `µ_ln = ln(203)−0.43²/2 ≈ 5.222`). `z = (ln270 − 5.222)/0.43 = (5.598−5.222)/0.43 = 0.874`.
   `P = 1 − Φ(0.874) = 1 − 0.809 = 0.191`. → `f(0.191)`: raw=1/(1+e^{−6(0.191−0.55)})=1/(1+e^{2.154})=0.1041 ;
   `f=(0.1041−0.0356)/0.9014=0.076` → **sous-score 76**. Tague `puissance`, `force`.
2. **5 km** `R = 24:00 = 1440 s`. PointTable H : entre P=0.50(1878) et P=0.90(1326) →
   interpolation : `P = 0.50 + (1878−1440)/(1878−1326)·0.40 = 0.50 + 438/552·0.40 = 0.50+0.317=0.817`.
   `f(0.817)`: raw=1/(1+e^{−6(0.267)})=1/(1+e^{−1.602})=0.832 ; `f=(0.832−0.0356)/0.9014=0.884` → **884**. Tague `engine`.
3. **Max pompes** `R = 40`. Normale H (µ25,σ11) : `z=(40−25)/11=1.364` ; `P=Φ(1.364)=0.914`.
   `f(0.914)`: raw=1/(1+e^{−6(0.364)})=1/(1+e^{−2.184})=0.899 ; `f=(0.899−0.0356)/0.9014=0.958` → **958**.
   Tague `force`(proxy, isEstimated), `enduranceMusculaire`.

**Attributs** (max par tag, fenêtre fraîche) :
- engine = 884 (5 km) · puissance = 76 (Grace).
- **force = 76** : Grace est un test **avec charge** → il **fait autorité** (décision **D2**). Le
  proxy pompes (958) **ne peut pas le surclasser** et est plafonné/ignoré pour `force`.
  → **force = 76, isEstimated = false** (la valeur retenue vient d'un test chargé réel).
- enduranceMusculaire = 958 (pompes — mesure légitime d'endurance au poids de corps, non estimée).
- Débloqués : engine, force, puissance, enduranceMusculaire = **4/6** → couverture OK, **non provisoire**.

**Index « Partout »** (poids 1) sur 4 attributs débloqués :
`(884 + 76 + 76 + 958)/4 = 1994/4 = 499` → **HYBRID INDEX ≈ 499 (OR)**.
Percentile Index (N(450,140)) : `z=(499−450)/140=0.35` → `Φ=0.637` → « meilleur que 64 % des hommes ».
> Sans le correctif **D2**, le proxy pompes aurait gonflé l'Index à **719 (Platine)** : la règle
> « le test chargé fait autorité » préserve la crédibilité du score (dopamine honnête).

### Exemple B — Femme, objectif « HYROX », 3 efforts

1. **2000 m row** `R = 8:00 = 480 s`. Log-normale F médiane 510, σ_ln 0.085 (`µ_ln=ln510=6.234`).
   `z=(ln480−6.234)/0.085=(6.174−6.234)/0.085=−0.706` ; `P=1−Φ(−0.706)=1−0.240=0.760`.
   `f(0.760)`: raw=1/(1+e^{−6(0.210)})=1/(1+e^{−1.26})=0.779 ; `f=(0.779−0.0356)/0.9014=0.825` → **825**. Tague `engine`.
2. **Benchmark Zéro** `R = 15:00 = 900 s`. PointTable F : entre P=0.50(960) et P=0.75(810) →
   `P=0.50+(960−900)/(960−810)·0.25=0.50+60/150·0.25=0.50+0.10=0.60`.
   `f(0.60)`: raw=1/(1+e^{−6(0.05)})=1/(1+e^{−0.30})=0.574 ; `f=(0.574−0.0356)/0.9014=0.597` → **597**.
   Tague `engine`, `enduranceMusculaire`, `hybride`.
3. **Max pompes** `R = 18`. Normale F (µ12,σ7) : `z=(18−12)/7=0.857` ; `P=Φ(0.857)=0.804`.
   `f(0.804)`: raw=1/(1+e^{−6(0.254)})=1/(1+e^{−1.524})=0.821 ; `f=(0.821−0.0356)/0.9014=0.871` → **871**.
   Tague `force`(proxy,isEstimated), `enduranceMusculaire`.

**Attributs** : engine = max(825 row, 597 BZ) = 825 · enduranceMusculaire = max(597, 871) = 871 ·
hybride = 597 · force = 871 (proxy, **isEstimated=true** — aucun test charge). Débloqués = 4/6 → non provisoire.

**Index « HYROX »** poids {engine 1.5, force 0.7, endMusc 1.3, hybride 1.5} (les 4 débloqués) :
`num = 1.5·825 + 0.7·871 + 1.3·871 + 1.5·597 = 1237.5 + 609.7 + 1132.3 + 895.5 = 3875`.
`den = 1.5+0.7+1.3+1.5 = 5.0`. → `3875/5.0 = 775` → **HYBRID INDEX ≈ 775 (DIAMANT)**, `isEstimated=true` (Force proxy).
Percentile (N(450,140)) : `z=(775−450)/140=2.32` → « meilleure que 99 % des femmes ».

> Les deux exemples montrent la chaîne complète et la **bonne sensibilité au sexe** (mêmes reps de
> pompes ⇒ percentiles très différents H vs F, conformément au dimorphisme sourcé §reference-data).

---

## 10. Tests à écrire (couverture élevée — non négociable)

### Fonction percentile `P`
- **Monotonie time** : pour deux temps `R1 < R2` (même WOD/sexe) ⇒ `P(R1) > P(R2)`.
- **Monotonie reps** : `R1 > R2` ⇒ `P(R1) > P(R2)`.
- **Bornes** : `P ∈ [0.001, 0.999]` toujours ; jamais NaN ; `R = hardMin` et `R = hardMax` valides.
- **Sexe** : même `R` donne `P` différent H vs F pour les WODs à fort dimorphisme (pompes, Grace) ;
  vérifier `P_F(pompes=18) > P_H(pompes=18)`.
- **PointTable** : `P` aux nœuds = valeur du nœud ; monotone entre nœuds ; extrapolation clampée.
- **Log-normal** : `P(médiane) ≈ 0.5` ; cohérence `µ_ln/σ_ln` reconstruits depuis µ/σ arithmétiques.

### Courbe `f`
- **Bornes** : `f(0)=0`, `f(1)=1`, `subScore ∈ [0,1000]` entier.
- **Monotonie stricte** : `P1<P2 ⇒ f(P1)≤f(P2)`.
- **Cibles** : `subScore(P=0.5) ∈ [420,460]` (médiane ~450) ; pente centrale > pente extrême.
- **Versionnage** : changer `k`/`P0` change la `version` et déclenche recalcul historique.

### Score d'attribut
- **Max** : ajouter un effort moins bon ne fait **pas** baisser l'attribut (no-drop).
- **Multi-tag** : un effort alimente tous ses attributs.
- **Fraîcheur** : effort > 26 sem ⇒ `isStale`, mais score conservé (jamais effacé) ; < 8 sem ⇒ frais.
- **Unlocked** : attribut sans effort ⇒ `unlocked=false`, exclu de l'Index (pas compté 0).
- **Proxy Force (D2)** : pompes seules ⇒ `force.isEstimated=true` ; ajout d'un test chargé (Grace/
  Jackie) ⇒ `force` prend la valeur du test chargé (proxy **plafonné, jamais surclassé**), `isEstimated=false`.

### HYBRID INDEX
- **Pondération** : 3 jeux de poids donnent 3 Index différents sur les mêmes sous-scores.
- **Débloqués seulement** : un attribut verrouillé n'entre pas au dénominateur.
- **Provisoire** : `<4` attributs ET `<3` efforts ⇒ `isProvisional=true` ; bascule à `false` au seuil.
- **No-drop global** : un re-test raté ne baisse jamais l'Index.
- **Percentile Index** : monotone, ∈ [0,1], cohérent par sexe.
- **Projeté** : `projected_index(A→score(A))` = Index courant (identité) ; `Y > score(A)` ⇒ projeté > courant.

### Anti-triche (§5.5)
- `R < hardMin` ou `R > hardMax` ⇒ refusé/`isFlagged`, exclu classement & Index.
- Saut de perf > +30% en 7 jours ⇒ flag (non comptabilisé pour l'élite/percentile communautaire).

---

## Résumé (10–15 lignes) & alertes

Cette spec définit les 15 WODs benchmarks (8 avec / 7 sans matériel) avec mouvements, charges Rx
H/F, `scoreType`, attributs tagués et **bornes physiologiques par sexe** pour l'anti-triche. La
chaîne de notation est entièrement paramétrée et **versionnée** : `R → P(R,WOD,S) → f(P) →
sous-score 0–1000 → attribut (max sur fenêtre 26 sem) → HYBRID INDEX (moyenne pondérée par objectif)`.
Trois familles de distributions par sexe sont posées (log-normale, normale tronquée, table de points
monotone), chacune ancrée sur `reference-data-sources.md` avec source + niveau de confiance. La courbe
`f = sigmoid-v1` (k=6, P0=0.55) réalise la médiane≈450, des gains rapides au milieu et lents aux
extrêmes (table P→sous-score fournie). Trois jeux de poids concrets (HYROX / Force CrossFit / Partout)
sont chiffrés. Deux worked examples (H et F) prouvent que la chaîne tient bout-en-bout, y compris la
normalisation par sexe. Les verrous sont respectés : no-drop, fenêtre 26 sem, pas de fatigue, proxy
Force `isEstimated`.

**Alertes / limites de données :**
1. **Confiance faible** sur 3 WODs (Benchmark Zéro #9, Burpees 7 min #14, Air squats 2 min #13) :
   distributions ESTIMÉES → **recalibrage communautaire prioritaire** (`N_min` proposé = 200/sexe).
2. **Côté femmes** de Fran/Jackie/Karen extrapolé (+10–25%) faute de σ sourcés par sexe → confiance medium/low.
3. **Concept2 logbook** = population auto-sélectionnée (compétiteurs) : médianes 2 km volontairement
   ralenties vs le classement brut ; à raffiner via la pagination complète ou Held et al.
4. **PFT HYROX** est un format propriétaire (≠ HYROX officiel) : les distributions HYROX réelles
   ne s'appliquent qu'approximativement → recalibrer si distances/charges divergent.
5. **Force proxy — TRANCHÉ (décision D2, `decisions-log.md`)** : quand un test Force réel (Grace/
   Jackie) existe, il **fait autorité** ; le proxy pompes ne peut pas le surclasser (plafonné/ignoré
   pour `force`). `isEstimated = true` **ssi** la valeur retenue vient du proxy. Option (a) retenue
   (le proxy ne doit pas surévaluer la Force lourde). Exemple A mis à jour en conséquence (Index 499).
6. `µ_idx/σ_idx` de la distribution d'Index (450/140) sont des valeurs de départ par construction de
   `f` ; à remplacer par la distribution empirique dès la communauté constituée.
