# Bibliothèque de séances par attribut — spec de tri & mapping des poids

> Source d'autorité : agent sport-science (26 juin 2026). Pour l'UI « Séances » (1 bouton par
> attribut) et le filtre matériel. Données dérivées de `apps/api/src/modules/coach/sessions.data.ts`
> (tags `primaryAttribute` / `secondaryAttributes`, source sport-science) + la séance signature
> `weekly-forgeron` (cf. `seance-de-la-semaine.md`).

## 1. Les 6 attributs (libellés UI)

| Clé interne | Bouton UI |
|---|---|
| `engine` | **Cardio** |
| `speed` | **Vitesse** |
| `strength` | **Force** |
| `power` | **Puissance** |
| `muscular_endurance` | **Endurance** |
| `hybrid` | **Hybride** |

## 2. Règle de tri (écran d'un attribut A)

1. **Inclure** toutes les séances dont le poids sur A est > 0. Comme **chaque** séance a un **poids
   plancher = 0.10 sur tous les attributs**, toutes les séances sont théoriquement éligibles, mais
   en pratique on **n'affiche que celles où A est primaire ou secondaire** (poids ≥ 0.35) en tête,
   et on peut masquer le « bruit » à 0.10 (voir variante d'affichage ci-dessous).
2. **Trier par `poids[A]` décroissant.** En tête : les séances où A est **primaire** (1.0), puis
   les secondaires (0.60 → 0.45 → 0.35), puis le plancher (0.10).
3. **Départage** (à poids égal), dans l'ordre : intensité décroissante (high > medium > low) →
   durée croissante → ordre alphabétique du nom. Stable et déterministe.
4. **Filtre matériel** (état global de l'app) :
   - **« Sans matériel »** ⇒ ne montrer que les séances `requiresEquipment = false`.
   - **« Équipé »** ⇒ montrer **toutes** les séances (avec et sans matériel).
5. **L'attribut compte toujours un minimum** : le plancher 0.10 garantit qu'aucun attribut n'est
   jamais à zéro pour une séance donnée (utile si l'UI veut afficher un mini-radar par séance ou
   éviter les divisions par zéro). Il ne fait PAS remonter une séance hors-sujet en tête (0.10
   reste tout en bas du tri).

### Variante d'affichage recommandée
Dans l'écran d'un attribut A, n'afficher que les séances avec `poids[A] ≥ 0.35` (primaire +
secondaires), triées décroissant. Le plancher 0.10 sert au calcul/scoring, pas à peupler la liste.

## 3. Barème de dérivation des poids (reproductible)

Pour chaque séance, à partir de ses tags :
- **Attribut primaire** → **1.00**
- **1er attribut secondaire** → **0.60** · **2e** → **0.45** · **3e** → **0.35** (ordre = celui de
  `secondaryAttributes` dans `sessions.data.ts`, qui reflète l'importance sport-science)
- **Tout autre attribut** → **0.10** (plancher minimum garanti)

Exception : `weekly-forgeron` porte des poids **calibrés à la main** (séance signature, cf.
`seance-de-la-semaine.md`) et non le barème automatique.

> Implémentation suggérée : stocker ces poids en dérivé (fonction `attributeWeights(session)`) ou
> en table figée. Tant que `sessions.data.ts` reste la source des tags, la fonction suffit ;
> dupliquer le tableau ci-dessous seulement si l'UI a besoin d'un accès statique.

## 4. Tableau séance × 6 attributs (poids) + matériel

Colonnes : **Cardio**=engine · **Vit.**=speed · **Force**=strength · **Puis.**=power ·
**End.**=muscular_endurance · **Hyb.**=hybrid. **Mat.** = matériel (✗ = sans / ⚙ = équipé).
**P** marque l'attribut primaire de la séance.

### Séance de la semaine

| id | Nom | Cardio | Vit. | Force | Puis. | End. | Hyb. | Mat. |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `weekly-forgeron` | Le Forgeron | 0.90 | 0.30 | 0.15 | 0.40 | 0.80 | **1.00 P** | ✗ |

### Cardio (engine) — primaires

| id | Nom | Cardio | Vit. | Force | Puis. | End. | Hyb. | Mat. |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `engine-zone2-run-40` | Sortie Zone 2 — 40 min | **1.00 P** | 0.60 | 0.10 | 0.10 | 0.10 | 0.10 | ✗ |
| `engine-run-5x800` | Intervalles 5×800 m | **1.00 P** | 0.60 | 0.10 | 0.10 | 0.10 | 0.10 | ✗ |
| `engine-row-30min` | Rameur continu 30 min | **1.00 P** | 0.10 | 0.10 | 0.10 | 0.10 | 0.60 | ⚙ |
| `engine-bike-erg-intervals` | BikeErg 8×2 min | **1.00 P** | 0.10 | 0.10 | 0.60 | 0.10 | 0.10 | ⚙ |
| `engine-burpee-emom-20` | EMOM 20 min — Burpees | **1.00 P** | 0.10 | 0.10 | 0.10 | 0.60 | 0.45 | ✗ |
| `engine-shuttle-run-pyramide` | Pyramide de navettes | **1.00 P** | 0.60 | 0.10 | 0.10 | 0.10 | 0.10 | ✗ |
| `engine-stairs-30` | Montée d'escaliers 30 min | **1.00 P** | 0.10 | 0.10 | 0.10 | 0.60 | 0.10 | ✗ |
| `engine-running-tempo-25` | Tempo run 25 min | **1.00 P** | 0.60 | 0.10 | 0.10 | 0.10 | 0.10 | ✗ |
| `engine-ski-erg-5x500` | SkiErg 5×500 m | **1.00 P** | 0.10 | 0.10 | 0.10 | 0.60 | 0.45 | ⚙ |

### Vitesse (speed) — primaires

| id | Nom | Cardio | Vit. | Force | Puis. | End. | Hyb. | Mat. |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `speed-sprints-10x100` | 10×100 m sprint | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.10 | 0.10 | ✗ |
| `speed-flying-30s` | Sprints lancés 30 m | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.10 | 0.10 | ✗ |
| `speed-hill-sprints` | Sprints en côte 8× | 0.10 | **1.00 P** | 0.45 | 0.60 | 0.10 | 0.10 | ✗ |
| `speed-ladder-agility` | Échelle d'agilité & pieds vifs | 0.10 | **1.00 P** | 0.10 | 0.10 | 0.10 | 0.60 | ✗ |
| `speed-row-sprints-250` | Rameur 8×250 m | 0.45 | **1.00 P** | 0.10 | 0.60 | 0.10 | 0.10 | ⚙ |
| `speed-tabata-highknees` | Tabata montées de genoux | 0.60 | **1.00 P** | 0.10 | 0.10 | 0.10 | 0.10 | ✗ |
| `speed-bike-sprints` | Sprints vélo 10×15 s | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.10 | 0.10 | ⚙ |
| `speed-shuttle-5-10-5` | Test agilité 5-10-5 | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.10 | 0.45 | ✗ |
| `speed-jump-rope-speed` | Corde à sauter vitesse | 0.60 | **1.00 P** | 0.10 | 0.10 | 0.45 | 0.10 | ⚙ |

### Force (strength) — primaires

| id | Nom | Cardio | Vit. | Force | Puis. | End. | Hyb. | Mat. |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `strength-back-squat-5x5` | Back Squat 5×5 | 0.10 | 0.10 | **1.00 P** | 0.60 | 0.10 | 0.10 | ⚙ |
| `strength-deadlift-5x3` | Soulevé de terre 5×3 | 0.10 | 0.10 | **1.00 P** | 0.60 | 0.10 | 0.10 | ⚙ |
| `strength-press-5x5` | Développé militaire 5×5 | 0.10 | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.10 | ⚙ |
| `strength-bench-5x5` | Développé couché 5×5 | 0.10 | 0.10 | **1.00 P** | 0.60 | 0.10 | 0.10 | ⚙ |
| `strength-pistol-progression` | Progression pistol squat | 0.10 | 0.10 | **1.00 P** | 0.60 | 0.10 | 0.45 | ✗ |
| `strength-pushup-progression` | Pompes lestées / déclinées | 0.10 | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.10 | ✗ |
| `strength-pullup-weighted` | Tractions lestées 6×4 | 0.10 | 0.10 | **1.00 P** | 0.60 | 0.10 | 0.10 | ⚙ |
| `strength-bulgarian-split` | Fentes bulgares lourdes | 0.10 | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.45 | ⚙ |
| `strength-isometric-wall-core` | Isométrie force — gainage | 0.10 | 0.10 | **1.00 P** | 0.10 | 0.60 | 0.10 | ✗ |

### Puissance (power) — primaires

| id | Nom | Cardio | Vit. | Force | Puis. | End. | Hyb. | Mat. |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `power-box-jumps-5x5` | Box jumps 6×5 | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.10 | 0.10 | ⚙ |
| `power-broad-jumps` | Sauts en longueur 6×4 | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.10 | 0.10 | ✗ |
| `power-kb-swings-emom` | EMOM kettlebell swings | 0.60 | 0.10 | 0.10 | **1.00 P** | 0.10 | 0.45 | ⚙ |
| `power-clean-pull-5x3` | Power clean 5×3 | 0.10 | 0.45 | 0.60 | **1.00 P** | 0.10 | 0.10 | ⚙ |
| `power-medball-throws` | Lancers de med-ball | 0.10 | 0.10 | 0.10 | **1.00 P** | 0.10 | 0.60 | ⚙ |
| `power-plyo-squat-jumps` | Squat jumps pliométriques | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.45 | 0.10 | ✗ |
| `power-thruster-emom` | EMOM thrusters | 0.10 | 0.10 | 0.10 | **1.00 P** | 0.60 | 0.45 | ⚙ |
| `power-burpee-broad-jump` | Burpee broad jumps | 0.60 | 0.10 | 0.10 | **1.00 P** | 0.10 | 0.45 | ✗ |
| `power-tuck-jumps` | Tuck jumps & sauts groupés | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.10 | 0.10 | ✗ |

### Endurance (muscular_endurance) — primaires

| id | Nom | Cardio | Vit. | Force | Puis. | End. | Hyb. | Mat. |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `musend-pushups-amrap` | AMRAP pompes — 10 min | 0.10 | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.10 | ✗ |
| `musend-bodyweight-circuit` | Circuit poids du corps 4 tours | 0.60 | 0.10 | 0.10 | 0.10 | **1.00 P** | 0.45 | ✗ |
| `musend-situps-emom` | EMOM abdos 15 min | 0.10 | 0.10 | 0.10 | 0.10 | **1.00 P** | 0.60 | ✗ |
| `musend-walking-lunges` | Fentes marchées longue distance | 0.10 | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.10 | ✗ |
| `musend-wallballs-amrap` | AMRAP wall balls | 0.45 | 0.10 | 0.10 | 0.60 | **1.00 P** | 0.10 | ⚙ |
| `musend-row-intervals-long` | Rameur 6×500 m endurance | 0.60 | 0.10 | 0.10 | 0.10 | **1.00 P** | 0.45 | ⚙ |
| `musend-kb-complex` | Complexe kettlebell | 0.10 | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.45 | ⚙ |
| `musend-plank-complex` | Circuit gainage dynamique | 0.10 | 0.10 | 0.10 | 0.10 | **1.00 P** | 0.60 | ✗ |
| `musend-step-ups-loaded` | Step-ups chargés | 0.45 | 0.10 | 0.60 | 0.10 | **1.00 P** | 0.10 | ⚙ |

### Hybride (hybrid) — primaires

| id | Nom | Cardio | Vit. | Force | Puis. | End. | Hyb. | Mat. |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `hybrid-hyrox-sim-half` | Simulation demi-HYROX | 0.60 | 0.10 | 0.10 | 0.10 | 0.45 | **1.00 P** | ⚙ |
| `hybrid-run-row-couplet` | Couplet course / rameur | 0.60 | 0.45 | 0.10 | 0.10 | 0.10 | **1.00 P** | ⚙ |
| `hybrid-bodyweight-metcon` | Metcon poids du corps « Cindy-like » | 0.45 | 0.10 | 0.10 | 0.10 | 0.60 | **1.00 P** | ✗ |
| `hybrid-run-burpee-ladder` | Course + burpees en échelle | 0.60 | 0.10 | 0.10 | 0.45 | 0.10 | **1.00 P** | ✗ |
| `hybrid-dt-style` | Complexe haltères « DT-like » | 0.10 | 0.10 | 0.60 | 0.45 | 0.10 | **1.00 P** | ⚙ |
| `hybrid-sled-run-intervals` | Traîneau + course intervalles | 0.45 | 0.10 | 0.60 | 0.10 | 0.10 | **1.00 P** | ⚙ |
| `hybrid-emom-mixed-30` | EMOM mixte 30 min | 0.60 | 0.10 | 0.10 | 0.35 | 0.45 | **1.00 P** | ⚙ |
| `hybrid-chipper-bodyweight` | Chipper poids du corps | 0.45 | 0.10 | 0.10 | 0.10 | 0.60 | **1.00 P** | ✗ |
| `hybrid-tabata-fullbody` | Tabata full-body 4 blocs | 0.60 | 0.10 | 0.10 | 0.45 | 0.35 | **1.00 P** | ✗ |

## 5. Récapitulatif par attribut (séances en tête de liste, primaires + meilleurs secondaires)

> Pour info produit : combien de séances « comptent fort » (poids ≥ 0.45) par attribut, et la
> répartition matériel. Aide à équilibrer le catalogue.

| Attribut | Séances primaires | dont sans matériel | Séances où poids ≥ 0.45 (prim.+sec.) |
|---|:--:|:--:|:--:|
| Cardio (engine) | 9 | 6 | ~20 |
| Vitesse (speed) | 9 | 7 | ~13 |
| Force (strength) | 9 | 3 | ~14 |
| Puissance (power) | 9 | 5 | ~16 |
| Endurance (musc.) | 9 | 5 | ~22 |
| Hybride | 9 (+1 Forgeron) | 4 (+1) | ~18 |

Chaque attribut a **au moins 9 séances primaires** dont **au moins 3 sans matériel** → l'écran
« Sans matériel » n'est jamais vide pour aucun attribut.

## 6. Notes & points de décision produit

1. **Source unique des poids** : les poids ci-dessus dérivent mécaniquement des tags de
   `sessions.data.ts` (sauf `weekly-forgeron`). Recommandation : implémenter une fonction
   `attributeWeights(session)` plutôt que recopier le tableau, pour éviter la divergence.
2. **Plancher 0.10** : valeur de confort (jamais zéro). Si le produit veut que le tri ne montre que
   primaire+secondaires, le plancher reste invisible (poids < 0.35).
3. **Le coach actuel** (`coach.service.ts`) ne filtre que sur `primaryAttribute`. Pour l'écran
   « toutes les séances qui touchent A, triées par poids », il faudra **étendre le filtre aux
   secondaires** (et appliquer le tri ci-dessus). C'est un travail d'API/UI de la session
   principale ; la présente spec fournit les poids et la règle.
4. **`weekly-forgeron`** apparaît en tête de l'écran **Hybride** (poids 1.00) et bien placé en
   **Cardio** (0.90) et **Endurance** (0.80).
5. Poids = **estimations expertes** dérivées des tags sport-science ; à affiner si la communauté
   révèle des contributions différentes. Confiance **medium**.
