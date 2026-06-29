# Normes de population générale — `popnorm-v1`

> Source de vérité des chiffres derrière le message **« tu fais partie des X % des humains les plus
> en forme »**. Distinct de la distribution **compétitive** (qui produit l'Index, le rang, le
> classement). Implémenté dans `packages/scoring-core/src/population-norms.ts`.

## Principe

- **Deux distributions, jamais mélangées.** La *compétitive* compare l'utilisateur aux autres
  pratiquants (population de l'app) → score / rang. La *population générale* le compare à
  l'adulte tout-venant (sédentaires inclus) → un seul message valorisant.
- **Même entrée.** Les deux partent du sous-score 0–1000 déjà calculé. La population n'est qu'une
  **2ᵉ fonction de mapping** branchée en sortie : `subScore → percentile population`. On ne
  recalcule jamais un effort.
- **Pourquoi c'est toujours valorisant.** Le sous-score est ancré sur la **médiane compétitive ≈ 450**.
  Or un pratiquant médian de CrossFit/Hyrox est déjà bien au-dessus de l'adulte médian → un
  sous-score de 450 mappe déjà vers ~top 35 % de la population. Le plancher est structurellement haut.
- **Confiance : `estimate`.** Chaque palier est ancré sur une norme publiée, mais l'agrégation
  reste un modèle. Le mot « estimé » et la source doivent rester visibles dans l'UI.

## Méthode de calibrage

Pour chaque attribut et chaque sexe : on prend un repère physique sourcé (ex. « 20 pompes »), on
lit son **percentile population** dans la norme publiée, et on l'aligne sur le **sous-score** que
cette performance produit déjà dans la chaîne compétitive. → un nœud `{subScore, popP}`. Plusieurs
repères → une table monotone, exploitée par le `PointTableModel` + `percentile()` existants
(nœuds `{p: popP, r: subScore}`, `dir = +1`).

## Sources normatives

| Domaine | Source | Attribut ancré |
|---|---|---|
| VO2max par âge/sexe | **ACSM Guidelines** (FRIEND registry), **Cooper Institute** | `engine` |
| Temps de 5 km population | **RunRepeat** (médiane H ~28–31 min, F ~34–36 min) | `engine` / `speed` |
| Pompes (à l'échec) | **ACSM push-up norms**, **Canadian Standardized Test of Fitness (CSTF)**, **US Army APFT/ACFT** | `muscular_endurance` |
| Sit-ups / gainage | **APFT / CSTF** | `muscular_endurance` |
| Force relative (squat/DL × poids de corps), grip | **ExRx.net strength standards**, **NSCA**, **Bohannon 2019 (grip)** | `strength` |
| Puissance (saut vertical, sprint) | **NSCA vertical jump norms**, **Mackenzie/Patterson sprint tables** | `power` / `speed` |
| Inactivité physique (plancher) | **OMS 2022** (~27,5 % d'adultes insuffisamment actifs), **Guthold et al., Lancet GH 2018** | bas de toutes les tables |

## Limites & honnêteté (à respecter en UX)

1. **Âge.** `popnorm-v1` utilise une **référence adulte ~30-39 ans** pour tous. L'app connaît la
   date de naissance, mais l'ajustement fin par tranche d'âge (`<30 / 30-49 / 50+`) est documenté
   comme **évolution v1.1** : un même sous-score classe *plus haut* chez les plus âgés, donc la v1
   est **conservatrice** pour eux (on sous-promet, jamais l'inverse). À formuler « estimé pour un
   adulte de référence ».
2. **Biais des panels normatifs.** Pompes/sit-ups souvent militaires (déjà en forme) → nos top %
   sont plutôt **conservateurs** vs la vraie moyenne sédentaire. Coureurs 5k auto-sélectionnés →
   compensé par le plancher OMS (≈ 27,5 % n'achèveraient pas un 5k).
3. **Formulation.** Toujours « **estimé** : top X % des humains (normes ACSM/OMS/APFT) ». Jamais de
   décimale sous 1 %. Sous la médiane → bande « en construction » formulée en distance à franchir,
   jamais « tu es dans le bas ».
4. **Ne jamais fusionner** le percentile population et le percentile app dans une même phrase
   ambiguë.

## Tables (popnorm-v1)

Voir `packages/scoring-core/src/population-norms.ts` (`POP_NORMS_V1`). Format par ligne :
`[sousScore, percentilePopulation]`. Agrégation Index = moyenne pondérée **no-drop** des
percentiles population par attribut, avec les **mêmes poids** que l'Index (cohérence « Option B »).

Bandes d'affichage : `1 / 2 / 5 / 10 / 20 / 30 / 50 %` (palier atteint), puis « en construction »
sous la médiane.

---

## `popnorm-v2` — correctif d'agrégation (29 juin 2026)

### Le bug observé

Le message « top X % des humains » utilisait une **moyenne pondérée** des percentiles population
par attribut (mêmes poids que l'Index). Un athlète **élite sur 1-2 systèmes** mais non entraîné
ailleurs était écrasé. Cas réel (`sofiane`, H, *all_round*), sous-scores /1000 :

| Attribut | sub-score | percentile pop (v2) |
|---|---|---|
| engine | 992 | ~0.999 |
| speed | 992 | ~0.999 |
| muscular_endurance | 813 | ~0.979 |
| hybrid | 813 | ~0.981 |
| strength | 137 | ~0.19 |
| power | 137 | ~0.11 |

Moyenne pondérée (v1) = **~0.69 → « top 35 % »**. Faux : vs la population GÉNÉRALE (massivement
sédentaire — OMS 2022, ~27,5 % d'adultes insuffisamment actifs, et la médiane ne court pas 3 km
*du tout*), courir 3 km en 11:30 place dans une **petite élite (~top 5-10 %)**, qu'on sache faire
un squat lourd ou non. Le défaut était **l'agrégation**, pas les tables (qui notaient déjà
correctement le cardio élite à ~0.99).

### La méthode v2 — « moyenne top-lourde gardée »

Raisonnement physiologique : « être en forme vs la population générale » n'est **pas une moyenne**
de tous les systèmes — c'est dominé par tes **meilleurs marqueurs**. Un sédentaire n'a *aucun*
marqueur élevé ; dès qu'un adulte possède un attribut réellement élite, il a franchi un cap que
~90-95 % des gens n'atteignent jamais, indépendamment de ses lacunes. **La rareté se mesure par le
haut.**

On combine deux moyennes des percentiles par attribut (pondérées par les poids de l'Index) :

- `Mwa` = moyenne pondérée classique (= comportement v1).
- `Mp` = **moyenne de puissance** (Hölder) d'exposant **P = 5** : `Mp = (Σ wᵢ·pᵢ^P / Σ wᵢ)^(1/P)`.
  P > 1 surpondère les attributs élevés (inégalité des moyennes : `M_p` croît avec `p`, `p→∞ → max`).
- Mélange piloté par un **gate de cohérence** `g = clamp01((maxᵢ pᵢ − 0,55) / (0,85 − 0,55))` :
  `pIndex = (1 − g)·Mwa + g·Mp`.

Effet :
- **Débutant** (aucun attribut au-dessus de ~top 50 % de la population) → `g ≈ 0` → `Mwa` →
  reste à la médiane (« en construction »). L'effet top-lourd **ne le propulse pas**.
- **Profil à point(s) fort(s)** (au moins un attribut ≥ ~top 15 %) → `g ≈ 1` → `Mp` → la rareté
  de ses meilleurs marqueurs ressort.
- **Athlète complet** → `Mp ≈ Mwa`, tous deux hauts → top 1-3 %.

### Recalibrage des tables (milieu de plage)

v1 mappait le pratiquant **médian de l'app** (sous-score ≈ 450) vers ~top 15-17 %, trop généreux
une fois combiné à l'agrégation top-lourde. v2 réaligne la bande 350-650 sur l'intention
documentée plus haut : **450 ≈ top 32-35 %**, **600 ≈ top 12-15 %**. Le **plancher** (sédentaires,
OMS 2022) et le **haut** de table (cardio/force élite ≈ 0,99) sont **conservés depuis v1** : un
attribut réellement élite ressort toujours à ~top 1 %. Aucune source n'est contredite ; on resserre
seulement l'interpolation du milieu pour que l'honnêteté du bas/median tienne.

### Cibles de calibration (verrouillées dans `population-norms.test.ts`)

| Profil | sub-scores | percentile pop v1 | percentile pop **v2** |
|---|---|---|---|
| sofiane (cardio élite, force nulle) | engine/speed 992, ME/hybrid 813, strength/power 137 | ~0,69 → top 35 % | **~0,91 → top ~9 %** |
| débutant générique | tous 150-300 | ~0,50 → top 50 % | **~0,40 → « en construction »** |
| athlète complet | tous 700-900 | ~0,96 → top 4 % | **~0,97 → top ~3 %** |
| profil moyen équilibré | tous ~500 | ~0,89 → top 11 % | **~0,73 → top ~27 %** |

Confiance : `estimate` (les ancres sont sourcées ; l'agrégation top-lourde est un modèle assumé,
documenté ici). La chaîne **compétitive** (Index, rang, percentile vs les autres utilisateurs)
n'est **pas** touchée par ce correctif.
