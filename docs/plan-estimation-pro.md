# Plan — Refonte de l'estimation de temps de WOD (modèle « pro »)

> **STATUT (2026-06-30) : LIVRÉ — Inc. 0 → 4.** Ce fichier reste la SPEC de référence ; l'état RÉEL
> du code (contrat fourchette de bout en bout, dépréciation de `targetAttributes` pour la
> prédiction) est décrit dans [`estimation-pro-implemente.md`](./estimation-pro-implemente.md).
>
> Autorité : sport-science / scoring. Statut historique : SPEC actionnable.
> Date : 2026-06-30. Cible : remplacer l'estimation « temps pour toi » des benchmarks par un
> modèle physiologique par mouvement, réaliste selon le niveau RÉEL de l'athlète.
>
> Principe directeur : **l'estimation est SÉPARÉE de la notation des résultats réels.** Toucher
> l'estimation ne doit jamais déplacer un sous-score, un Index, ni un classement. Les distributions
> de population (`bySex[sex].model`) restent la source de vérité pour NOTER un résultat saisi ;
> elles deviennent un simple **garde-fou de bornes (sanity bounds)** pour l'ESTIMATION.

---

## 0. Diagnostic confirmé (lecture du code, en chiffres)

### Le chemin de prédiction actuel
`apps/api/.../wods.service.ts:611 prediction()` → `score-client.predictResult()` →
`apps/score-service/src/score/scoring.service.ts:536 predictResult()`. Le corps (l.544-562) :

```
targets        = Set(wod.targetAttributes)                 // Fran : {muscular_endurance, power}
unlockedTarget = attributeScores ∩ targets, unlocked       // FORCE jamais incluse
userInternal   = moyenne SIMPLE de unlockedTarget          // (ME + power)/2
p              = percentileFromInternal(userInternal)       // sigmoid-v1 inverse, curve.ts:112
raw            = quantile(p, wod.bySex[sex].model)          // lognormal pop. distribution.ts:81
clamped        = clamp(raw, hardMin, hardMax)
```

### Pourquoi soso obtient 4m40 au lieu de 9m50 (facteur ~2)
- Fran `targetAttributes = [muscular_endurance, power]` (`wods.data.ts:55-58`). **La FORCE n'y est
  pas.** Le facteur limitant réel pour soso (thruster 40 kg lourd pour lui) n'entre JAMAIS dans le
  calcul.
- soso : ME = 971/1000, power = 737/1000. `userInternal = (971+737)/2 = 854/1000`.
- `percentileFromInternal(854)` ≈ **P 0.79** (sigmoid-v1 inverse, k=6, p0=0.55 ; confirmé l.112-118).
- Fran H : `lognormalFromMedian(390, 0.42)` → `quantile(0.79, …) = exp(ln 390 + 0.42·Φ⁻¹(0.79))`
  = `exp(5.966 + 0.42·0.806)` = `exp(6.305)` ≈ **548 s… clampé/arrondi** ; selon la note mémoire
  l'app affiche **~278 s (4m38)**. Quel que soit le point exact d'arrondi, l'ME=971 **tire la moyenne
  vers le haut** → percentile élevé → temps rapide. La force 661 (~60/100, le mur réel) est ignorée.
- Réel : **590 s (9m50)**. Écart ≈ ×2.

### Causes racines (3)
1. **Mauvais déterminants** : `predictResult` lit `targetAttributes` (grossier, niveau WOD) au lieu
   des `attributes` pondérés PAR MOUVEMENT, plus fins (`movements.data.ts`).
2. **Aucune pénalité de charge relative** : 40 kg est traité pareil pour un athlète à 1RM thruster
   50 kg (charge = 80 % capacité, effondrement) et pour un à 1RM 90 kg (44 %, fluide).
3. **Moyenne d'attributs** : un attribut très haut (ME 971) compense un attribut bas (force) de façon
   linéaire, alors que physiologiquement le **facteur limitant domine** (un maillon faible ralentit
   tout le WOD).

### Atout déjà présent (à réutiliser, pas réinventer)
`computeEstimate()` (`scoring.service.ts:249-387`) EST déjà un moteur par mouvement : il itère sur
`req.blocks`, lit `m.rate[level][sex]`, applique `loadMult`, `fatMult` (fatigueExponent), `breaks`
(maxSet), transitions, décroissance inter-tours. Il est utilisé pour la **création de WOD custom**
mais **pas** pour `predictResult`. **C'est le socle du nouveau moteur.**

### Le vrai blocage architectural (découvert à la lecture)
Les WODs de référence n'ont **AUCUNE décomposition structurée** exploitable par le moteur :
- `WodDefinition` (`wod.types.ts:20`) ne contient que `bySex` (modèles stats) + `targetAttributes`.
  **Pas de `blocks`.**
- La prescription lisible existe côté **API seed** : `wod-prescriptions.data.ts:57` →
  `fran.blocks = [{reps:"21-15-9", movement:"Thrusters"}, {reps:"21-15-9", movement:"Tractions"}]`,
  `fran.weights = [{movement:"Thruster", rxMale:40, rxFemale:30, …}]`. Mais c'est du **texte**
  (`reps:"21-15-9"` string, `movement:"Thrusters"` string) destiné à l'affichage — **pas** des
  `movementId` + reps numériques que `computeEstimate` consomme.

→ **Il faut créer une décomposition canonique des 15 benchmarks en `blocks` typés
(`movementId` + reps numériques + `loadKg` par sexe), source de vérité dans le score-service.**

---

## A. Problème d'affichage (correctif rapide, indépendant)

### Constat
`wod_detail_screen.dart` affiche **simultanément** :
- le vrai temps de l'utilisateur (`d.myBestRaw != null`, bloc l.333-351), ET
- la carte de prédiction `_predictionCard()` (l.265 → l.392), qui ne se masque que si
  `predictedRaw == null` (l.397).

Une fois le WOD réellement fait, l'estimation reste affichée et paraît se contredire avec le temps réel.

### Comportement cible (spécifié)
La prédiction est une **aide à la cible** ; dès qu'il y a un résultat réel, elle ne doit plus être
présentée comme une prédiction.

- **Si `d.myBestRaw != null`** : `_predictionCard()` ne s'affiche PAS comme prédiction. À la place,
  enrichir le bloc « Toi » existant (l.333) d'une ligne de comparaison **seulement si l'estimation
  niveau diffère nettement** (écart relatif > ~8 %) :
  `« Ton temps : 9:50 — estimation niveau : 6:30 (tu peux viser plus bas) »` pour un `time`
  (dir = -1), ou `« … tu es au-dessus de ton niveau estimé »` si le réel bat l'estimation.
  Si l'écart est faible, n'afficher que `« Ton temps : X »` (pas de bruit).
- **Si `d.myBestRaw == null`** : comportement actuel (carte « Temps estimé pour toi : Y », avec la
  phrase de motivation), MAIS avec **fourchette** (cf. §B.6) plutôt qu'un point.

### Implémentation
- Fichier : `apps/mobile/lib/features/wods/wod_detail_screen.dart`.
- `_predictionCard()` : early-return `SizedBox.shrink()` si `_loaded?.myBestRaw != null`
  (le widget a déjà accès au détail ; sinon passer `myBestRaw` en paramètre).
- Bloc « Toi » (l.333-351) : ajouter la ligne de comparaison, gardée par le seuil d'écart, en
  réutilisant la valeur de `_prediction` déjà chargée (l.36/48). Pas de nouvel appel réseau.
- i18n : ajouter les clés `wodDetailYourTimeVsEstimate`, `wodDetailEstimateRange`.

### Tests (widget)
- `myBestRaw != null` ⇒ pas de carte de prédiction autonome (`_predictionCard` rend `shrink`).
- `myBestRaw != null` + écart > seuil ⇒ ligne de comparaison présente.
- `myBestRaw == null` + `predictedRaw != null` ⇒ carte fourchette présente.

> Le §A ne touche NI le score-service NI l'Index. Livrable autonome, mergeable seul.

---

## B. Modèle « pro » par mouvement (le cœur)

### B.0 Vue d'ensemble
Un **seul moteur** `estimateWodTime(blocks, rounds, level|userProfile, sex)` qui :
1. décompose en (mouvement × reps × charge) ;
2. coûte chaque mouvement : `cadence de base (par attribut pertinent) × pénalité de charge relative
   × fatigue intra-série × coupures de série` ;
3. ajoute transitions + dégradation inter-tours ;
4. module par le **niveau réel de l'athlète, mouvement par mouvement** (pas un percentile global).

### B.1 Représentation du WOD en blocs canoniques (prérequis data)
Nouveau registre dans le score-service : `WOD_BLUEPRINTS: Record<wodId, WodBlueprint>`.

```ts
interface WodBlueprintBlock {
  movementId: string;                 // clé de movements.data.ts (ex. "thruster", "pull_up")
  repsPerRound: number[];             // ex. Fran = [21,15,9] ; un nombre par tour
  // charge ABSOLUE Rx par sexe (kg). Absente = poids de corps (loadFactor du mouvement).
  loadKg?: { male: number; female: number };
}
interface WodBlueprint {
  blocks: WodBlueprintBlock[];        // dans l'ordre d'exécution
  // rounds implicite = longueur de repsPerRound (couplets/triplets). Pour AMRAP/rep-WODs : voir B.7.
}
```

- Fran : `[{movementId:"thruster", repsPerRound:[21,15,9], loadKg:{male:40,female:30}},
  {movementId:"pull_up", repsPerRound:[21,15,9]}]`.
- Source de remplissage : `wod-prescriptions.data.ts` (parse des `reps:"21-15-9"` + `weights`)
  **transcrit à la main une fois** vers `movementId` (mapping nom→id), revu sport-science. On
  **NE parse PAS du texte au runtime** : on fige un blueprint typé, testé.
- Les 15 benchmarks doivent avoir un blueprint. WODs sans décomposition possible (course pure :
  `run_5k`, `row_2k`, `marathon`, `max_pushups`…) → blueprint mono-bloc trivial (1 mouvement), le
  moteur les gère nativement (déjà le cas dans `computeEstimate` pour run/row/cal).

### B.2 Capacité de l'athlète, mouvement par mouvement (remplace la moyenne globale)
Pour un mouvement `m` aux attributs pondérés `m.attributes` (ex. thruster = power 0.5 / ME 0.3 /
strength 0.2), on calcule un **score de capacité spécifique au mouvement** :

```
cap_m = Σ_a ( w_a · userScore_a )      // userScore_a ∈ [0,1000], a parcourt m.attributes
        (Σ w_a = 1 par construction des données)
```

C'est ce `cap_m` (et NON la moyenne des `targetAttributes`) qui module la cadence : ainsi la
**force entre automatiquement** dès qu'un mouvement la pondère (thruster, pull-up, deadlift…), même
si le WOD ne tague pas la force en `targetAttributes`. **Cela résout la cause racine n°1.**

Mapping `cap_m (0-1000)` → **multiplicateur de cadence** `paceMult_m ∈ [~0.35, ~1.6]`, ancré sur
les 3 niveaux existants de `m.rate` (occasional ≈ P0.15, intermediate ≈ P0.5, champion ≈ P0.98) :

```
p_m       = percentileFromInternal(cap_m)            // réutilise curve.ts:112 (cohérent avec le reste)
rate_m    = interp sur la courbe {0.15→rate.occasional, 0.5→rate.intermediate, 0.98→rate.champion}
            (interpolation log-linéaire en p, extrapolation BORNÉE aux extrêmes)
```

`rate_m` est donc la **cadence soutenable de CET athlète sur CE mouvement, à charge de référence**.
On n'introduit pas de niveau discret : on lit la cadence au percentile continu de l'athlète.

### B.3 PÉNALITÉ DE CHARGE RELATIVE (le correctif clé « 40 kg trop lourd »)
**Étape 1 — estimer le 1RM de l'athlète sur le mouvement chargé.**
Chaque mouvement de force a un `loadFactor` = charge Rx de réf en fraction du poids de corps de réf
(H 80 / F 65). On pose un **1RM de référence élite** par mouvement et on l'échelonne par le
percentile de force de l'athlète :

```
BW            = sex==='male' ? 80 : 65            // poids de réf (déjà utilisé l.265)
oneRM_elite_m = ELITE_1RM_FACTOR[m] · BW          // table calibrée (cf. B.4) — ex. thruster ≈ 1.0·BW
p_str         = percentileFromInternal(userScore_strength)
oneRM_m       = oneRM_elite_m · STR_SCALE(p_str)  // STR_SCALE(0.5)≈0.55, STR_SCALE(0.98)=1.0,
                                                  //   STR_SCALE(0.15)≈0.38 (table monotone bornée)
```

> On préfère un **1RM dérivé de la FORCE** (attribut), pas du `cap_m` du mouvement, car la charge
> max est une qualité de force pure ; la cadence (B.2), elle, dépend du mix d'attributs.

**Étape 2 — ratio charge/capacité et effondrement de cadence.**
```
x = loadKg / oneRM_m            // % de la capacité max sollicité à chaque rep
```
Multiplicateur de charge `loadMult(x)` — courbe **continue, bornée, croissante**, inspirée des
relations force-vitesse et reps-in-reserve (le temps par rep explose quand x → 1) :

```
loadMult(x) = 1                                   si x ≤ 0.35           (charge légère : neutre)
            = 1 + k1·(x − 0.35)                    si 0.35 < x ≤ 0.60    (linéaire doux, k1 ≈ 1.2)
            = 1 + k1·0.25 + k2·((x−0.60)/(0.90−x))² si 0.60 < x < 0.90   (explosion, k2 ≈ 1.6)
            = LOAD_MULT_MAX (≈ 7)                   si x ≥ 0.90           (quasi 1RM : 1 rep ≈ 1 série)
```
- `x ≤ 0.35` : neutre (cohérent avec le comportement actuel « sous-Rx = pas de bonus », l.293-295).
- Le terme `((x−0.60)/(0.90−x))²` diverge en x→0.90 → on **clampe** à `LOAD_MULT_MAX`.
- En plus du ralentissement, `loadMult` élevé **augmente le nombre de coupures** (B.5) :
  `effectiveMaxSet_m = round( maxSet_m · clamp(1.1 − x, 0.15, 1) )` → à x=0.8, on ne tient que ~2-4
  reps avant de lâcher la barre, ce qui injecte des `BREAK_SEC`. **C'est ce double effet
  (cadence ↓ ET séries ↑) qui produit le réalisme du « débutant qui galère à 40 kg ».**

> Soso/Fran : force 661 → p_str ≈ 0.59 → `oneRM_thruster ≈ 1.0·80·STR_SCALE(0.59) ≈ 80·0.62 ≈ 50 kg`.
> `x = 40/50 = 0.80`. `loadMult(0.80)` ≈ `1 + 0.30 + 1.6·((0.20)/(0.10))² = 1.30 + 1.6·4 = 7.7 → clamp 7`,
> et `effectiveMaxSet ≈ thruster.maxSet(12)·(1.1−0.8=0.30) ≈ 3-4 reps/série`. Les 45 thrusters se
> font en ~12-15 mini-séries avec repos → plusieurs minutes rien que pour les thrusters. **C'est le
> mécanisme qui amène le total vers 9-11 min.** (calibration finale en B.4.)

### B.4 Calibration (ancrer sur le réel, garde-fou population)
Constantes à fixer par sport-science : `ELITE_1RM_FACTOR[m]`, `STR_SCALE(p)`, `k1, k2,
LOAD_MULT_MAX`, et la table cadence (déjà dans `m.rate`).

**Points d'ancrage cibles (Fran H, calibrer dessus) :**
| Profil | force / power / ME (≈/100) | charge | cible attendue |
|---|---|---|---|
| Élite | ~95 / ~95 / ~95 | 40 kg | **~2:15** (proReference 135 s) |
| Régulier solide | ~60 / ~65 / ~70 | 40 kg | **~5-7 min** (médiane pop. 390 s) |
| **soso (cas réel)** | **60 / 64 / ~97** | **40 kg** | **9-11 min** (réel 9:50) |
| Débutant chargé Rx | ~40 / ~45 / ~50 | 40 kg | **12-15 min** (proche timeCap 600 s) |

Stratégie :
1. **Caler la cadence** (`m.rate`) sur l'élite et le régulier à charge LÉGÈRE (x<0.35) — ces points
   ne doivent pas bouger, ils sont déjà calibrés dans `movements.data.ts`.
2. **Caler `ELITE_1RM_FACTOR` + `STR_SCALE`** pour que le profil soso (p_str≈0.59) sorte
   `x≈0.78-0.82` sur thruster 40 kg (charge perçue lourde mais faisable), produisant 9-11 min.
3. **Caler `k1,k2,LOAD_MULT_MAX`** pour que le débutant (p_str≈0.30, x>0.95) frôle le timeCap sans
   le dépasser systématiquement.
4. **Garde-fou population (sanity bounds, PAS source primaire)** : après calcul, **clamp** le temps
   estimé dans `[bySex.hardMin, bySex.hardMax]` ET vérifier qu'il reste « plausible » p/r à la
   distribution : si l'estimation tombe hors de `[quantile(0.99,model), quantile(0.01,model)]`, on
   la ramène à la borne (jamais d'estimation absurde). La distribution **borne**, elle ne **génère**
   plus.
5. **Tests d'or (golden) figés** : une suite `estimate.golden.spec.ts` avec les 4 profils ci-dessus
   × 3-4 benchmarks (Fran, Grace, Helen, Cindy), tolérance ±15 %. Toute régression future casse ces
   tests AVANT de toucher un utilisateur.

### B.5 Réutilisation du moteur existant (ne pas réécrire la mécanique)
Le squelette de `computeEstimate` (l.280-334) est conservé. Modifications **chirurgicales** :
- `rate` (l.285) : remplacer `m.rate[level][sex]` par `rate_m` issu du **percentile de capacité du
  mouvement** (B.2) quand on prédit pour un athlète réel ; garder le mode « 3 niveaux » pour la
  création custom (cf. B.7 unification).
- `loadMult` (l.295) : remplacer la formule linéaire `1 + 0.6·max(0, loadKg/refLoad − 1)` par
  `loadMult(x)` de B.3 avec `x = loadKg / oneRM_m` (capacité de l'athlète, **pas** charge Rx de réf).
- `breaks`/`maxSet` (l.300) : utiliser `effectiveMaxSet_m` (B.3) au lieu de `maxSet ?? 12`.
- `fatMult` (l.298) : conservé tel quel (fatigue intra-série liée au volume).
- transitions (l.312, `TRANSITION=3.5`), `BREAK_SEC`, `ROUND_DECAY` : conservés (calibrés 23 juin).

### B.6 Incertitude → fourchette
La sortie de prédiction devient `{ low, mid, high }` (secondes), au lieu d'un point :
```
mid  = estimateWodTime(blueprint, userProfile, sex)
spread = SPREAD_BY_CONFIDENCE(coverage, nbChargedBlocks)   // ex. ±12 % si confiance moyenne
low  = clamp(mid·(1−spread), hardMin, hardMax)
high = clamp(mid·(1+spread), hardMin, hardMax)
```
- Contrat `PredictResultResponse` étendu : `predictedRaw` (mid, rétro-compat) + `predictedLow`,
  `predictedHigh`, `confidence: "low"|"medium"|"high"`.
- Mobile : afficher `« ~9-11 min »` (fourchette) ; `predictedRaw` seul reste dispo pour la
  cohérence aller-retour des tests. Confiance basse ⇒ fourchette plus large, libellé « estimation ».

### B.7 Unification `predictResult` ↔ `computeEstimate` (une seule source de vérité)
Extraire le cœur dans une fonction pure partagée, p.ex.
`apps/score-service/src/score/wod-time-engine.ts` :
```
estimateBlocksTime(blocks: ResolvedBlock[], opts: {
  sex, rounds,
  pace: { kind: "level", level } | { kind: "athlete", scores: AttrScores },  // B.2
  loadCapacity?: (movementId) => oneRM_kg,                                    // B.3, mode athlète
}): { seconds, attrShare }
```
- `computeEstimate` (custom WOD) appelle le moteur en mode `pace:{kind:"level"}` pour produire la
  pointTable 3 nœuds (occasional/intermediate/champion) — **comportement préservé**.
- `predictResult` (benchmark) : charge `WOD_BLUEPRINTS[wodId]`, appelle le moteur en mode
  `pace:{kind:"athlete", scores}` avec la pénalité de charge B.3, retourne `{low,mid,high}`.
- Bénéfice : **une seule mécanique** (transitions, fatigue, breaks, decay) ; corriger un bug la
  corrige partout.

---

## C. Découpage en incréments (livrables, testables)

### Inc. 0 — Affichage (§A) — *autonome, sans risque score*
- Fichiers : `wod_detail_screen.dart`, fichiers i18n `app_*.arb`.
- Tests : 3 widget tests (§A). Aucun test back touché.
- Risque : nul côté scoring. Mergeable immédiatement.

### Inc. 1 — Moteur extrait + blueprints (refactor sans changement de comportement)
- Nouveaux : `apps/score-service/src/score/wod-time-engine.ts`,
  `apps/score-service/src/wods/wod-blueprints.data.ts` (15 benchmarks).
- `computeEstimate` réécrit pour **appeler** le moteur en mode `level` → sortie identique.
- Tests verts À CONSERVER : **toute** la suite `estimate` existante (monotonie des paliers,
  bornes, finitude, AMRAP volume>0), les **15 benchmarks**, la cohérence aller-retour
  `predict.e2e.spec.ts:45`, et la **band-consistency** de la notation (inchangée).
- Risque : refactor — couvert par les tests existants. Si la sortie de `computeEstimate` bouge,
  STOP.

### Inc. 2 — Capacité par mouvement + pénalité de charge (le cœur, mode athlète)
- `wod-time-engine.ts` : ajoute le mode `pace:{kind:"athlete"}` (B.2) + `loadMult(x)` (B.3) +
  `effectiveMaxSet`.
- `predictResult` (`scoring.service.ts:536`) réécrit : blueprint → moteur mode athlète →
  `{low,mid,high}` clampé (B.4 garde-fou).
- `ELITE_1RM_FACTOR`, `STR_SCALE`, `k1,k2,LOAD_MULT_MAX` : nouvelles constantes calibrées.
- **Tests à RÉÉCRIRE (rupture intentionnelle de comportement)** dans `predict.e2e.spec.ts` :
  - l.85-99 « ignore les attributs NON cibles » → **obsolète** : la force (non-cible) DOIT désormais
    influencer Fran. Remplacer par : « augmenter la FORCE améliore le temps de Fran à charge fixe ».
  - l.102-119 « ne compte QUE les cibles débloqués » → adapter à la nouvelle logique par mouvement.
- **Nouveaux tests golden** (`estimate.golden.spec.ts`, B.4) : les 4 profils × Fran/Grace/Helen/Cindy,
  tolérance ±15 %. **Inclut le cas soso → 9-11 min.**
- Tests à GARDER verts : monotonie (meilleur niveau → meilleur temps, l.60-82 — toujours vrai),
  bornes/clamp (l.156-162), null cases (l.122-153), aller-retour (l.45 — vérifier que le clamp
  garde-fou ne casse pas la réversibilité ; sinon relâcher la tolérance du test, documenté).
- Risque : **ne pas casser la NOTATION**. `predictResult` ne touche QUE l'estimation ; vérifier
  qu'aucun chemin de `computeIndex`/`scoreResult` n'appelle le nouveau code de charge. La notation
  d'un résultat réel continue de passer par `bySex.model` (distribution.ts), inchangée.

### Inc. 3 — Fourchette + contrat (B.6)
- `packages/contracts` : étendre `PredictResultResponse` (`predictedLow/High/confidence`).
- `score-client`, `wods.service.prediction()`, `WodPrediction` (mobile) : propager.
- Mobile : afficher la fourchette dans la carte (§A, branche `myBestRaw == null`).
- Tests : contrat (zod), e2e (low ≤ mid ≤ high, bornés), widget.

### Inc. 4 — Nettoyage & doc
- Marquer `wod.targetAttributes` comme **affichage/radar uniquement** (plus utilisé pour prédire) ;
  commentaire dans `wod.types.ts`.
- Mettre à jour `docs/sport/` (chaîne de notation) : section « estimation ≠ notation ».

### Risques transverses
1. **Casser l'Index / la notation** : le nouveau code vit dans l'estimation (`predictResult` +
   moteur en mode athlète). Garde-fou : revue que `computeIndex`, `scoreResult`,
   `subScoreFromPercentile`, `bySex.model` ne sont JAMAIS modifiés. Tests Index/band-consistency
   restent verts sans changement.
2. **Monotonie des paliers** (pointTable de `computeEstimate`) : préservée par Inc.1 (refactor iso).
3. **Cohérence aller-retour** : le garde-fou de clamp (B.4) peut casser la réversibilité stricte aux
   extrêmes — accepter une tolérance documentée, ou n'appliquer le clamp qu'au-delà de
   `quantile(0.01/0.99)`.
4. **Tests intentionnellement obsolètes** (Inc.2) : ne PAS les « réparer » à l'identique — ils
   encodent l'ancien bug (force ignorée). Les réécrire selon la nouvelle intention.
5. **Blueprints faux** : un mauvais `movementId`/reps fausse tout. Mitigation : test qui vérifie que
   chaque blueprint référence des `movementId` existants et que `Σ reps` correspond au volume connu
   du benchmark.

---

## Synthèse finale

### Diagnostic confirmé (chiffres)
- soso, Fran 40 kg : force **661** (~60/100), power **737** (~64/100), ME **971** (~97/100).
- `predictResult` actuel = moyenne des SEULES cibles {ME, power} = **854/1000** → P≈**0.79** →
  `quantile(0.79, lognormal(390, 0.42))` → estimation **~4-5 min** (app : 4m40 / ~278 s).
- Réel : **9m50 (590 s)**. Écart **×2**. Cause : la **force (facteur limitant à 40 kg) est ignorée**
  et l'**ME=971 gonfle la moyenne**. Aucune pénalité de charge relative.

### 4 décisions de modélisation clés
1. **Capacité PAR MOUVEMENT** via `m.attributes` pondérés (B.2), pas la moyenne des
   `targetAttributes` du WOD → la force entre automatiquement sur les mouvements chargés.
2. **Pénalité de charge relative** `loadMult(x)`, `x = loadKg / 1RM_estimé(force)` : courbe continue
   bornée qui **explose vers x→0.90**, + réduction de `maxSet` (plus de coupures). C'est le correctif
   « 40 kg trop lourd ». 1RM dérivé de la FORCE (`ELITE_1RM_FACTOR · BW · STR_SCALE(p_str)`).
3. **Un seul moteur par mouvement** (`wod-time-engine.ts`) partagé par `predictResult` (mode
   athlète) et `computeEstimate` (mode niveau) ; la distribution de population devient un
   **garde-fou de bornes**, plus la source de l'estimation.
4. **Sortie en fourchette** `{low, mid, high}` + `confidence`, calibrée sur des golden tests
   (élite 2:15 / régulier 5-7 / soso 9-11 / débutant 12-15 min).

### Découpage
- **Inc.0** : fix affichage (mobile seul, sans risque).
- **Inc.1** : extraction moteur + 15 blueprints, **refactor iso-comportement** (tests existants
  verts).
- **Inc.2** : capacité par mouvement + pénalité de charge (cœur) ; **réécrire** 2 tests devenus
  obsolètes, **ajouter** golden tests dont le cas soso ; garder monotonie/bornes/null/Index verts.
- **Inc.3** : fourchette + contrat propagés jusqu'au mobile.
- **Inc.4** : doc + dépréciation de `targetAttributes` pour la prédiction.
- **Garde-fou n°1** : estimation ≠ notation — aucune ligne de `computeIndex`/`scoreResult`/`bySex.model`
  ne bouge.
