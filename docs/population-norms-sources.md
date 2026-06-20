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
