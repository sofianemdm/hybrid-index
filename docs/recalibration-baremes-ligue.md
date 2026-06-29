# Recalibration des barèmes — 5 WODs de la Ligue mensuelle (29/06/2026)

Autorité : sport-science. Périmètre STRICT : les 5 WODs `isBenchmark:false` de la Ligue
(`league_*`). Aucun des 15 benchmarks de l'Index ni la logique de scoring n'ont été touchés.

## Pourquoi
Les barèmes étaient des placeholders volontairement bas. Or `predictResult` (GET
`/v1/wods/:id/prediction`) lit le **modèle de distribution** de `wods.data.ts`
(`quantile(p, model)`), pas les paliers affichés. Une médiane/un champion trop mous
compressaient la queue haute : un bon athlète (attributs P85+) se voyait prédire un résultat
médiocre. On a donc :
1. fixé la **médiane du modèle = pratiquant régulier réaliste** (intermédiaire) ;
2. fixé le **champion = élite hybride crédible** (≈P95-98) ;
3. ajusté σ pour une queue cohérente (débutant qui termine ≈P10-15, jamais écrasé) ;
4. réaligné `WOD_LEVELS` (paliers affichés) sur ces points : inter = médiane, champion ≈ P95-98,
   occasionnel ≈ P10-15.

Convention : `time` → plus bas = meilleur ; `reps` → plus haut = meilleur.

## Valeurs avant → après (champion / intermédiaire / occasionnel)

### La Flèche — `league_sprint_ladder` (VITESSE, time, échelle 1500 m)
- Modèle médiane M 480→**450 s**, F 540→**510 s** ; σ 0.31→**0.30**. proReference M 290→**270**, F 335→**310**.
- Paliers M : 290/480/720 → **270/450/630** ; F : 335/540/810 → **310/510/720**.
- Raisonnement : 1500 m d'intervalles (100-200-300-400-300-200-100) avec micro-récup. Régulier
  ~7:30 (M) / ~8:30 (F) à allure de seuil fractionnée ; élite ~4:30 (M, ~5,5 m/s net) / ~5:10 (F) ;
  débutant qui termine ~10:30 / ~12:00. hardMin abaissé 270→250 (M) / 310→290 (F) pour rester < proRef.

### Le Moteur — `league_engine_12` (ENDURANCE, reps, AMRAP 12')
- Modèle µ M 115→**140**, F 80→**100** ; σ M 45→**42**, F 30→**32**. proReference M 210→**215**, F 130→**160**.
- Paliers M : 210/115/65 → **215/140/75** ; F : 130/80/45 → **160/100/52**.
- Raisonnement : tour « 400 m + 20 air squats + 15 burpees » ≈ 2:45-3:15. Régulier ≈ 4 tours = 140
  reps (M) / ~3 tours = 100 (F, course plus lente) ; élite ≈ 6 tours = 215/160 ; débutant ≈ 2 tours
  = 70-75/52. L'ancienne médiane 115 (M) sous-évaluait le pratiquant régulier (≈3,3 tours seulement).

### Le Pilier — `league_grind_squats` (FORCE-ENDURANCE, reps, AMRAP 12')
- Modèle µ inchangé M **320**, F 230→**235** ; σ M 125→**110**, F 90→**82**. proReference M 560→**540**, F **400→415**.
- Paliers M : 520/320/180 → **540/320/160** ; F : 330/230/130 → **415/235/120**.
- Raisonnement : tour 106 reps (40 fentes + 30 squats + 20 sit-ups + 16 pistols) borné par les
  pistols (~3:30-4:00/tour). Régulier ≈ 3 tours = 320 (M) / ~2,2 tours = 235 (F) ; élite ≈ 5 tours =
  540/415 ; débutant ≈ 1,5 tour = 160/120. σ resserré (0.35·µ) pour éviter une queue haute irréaliste.
  Le champion F était sous-calibré (330, soit P87 seulement) → porté à 415 (vrai niveau élite).

### La Détente — `league_power_amrap` (PUISSANCE, reps, AMRAP 12')
- Modèle µ M 175→**170**, F **105** ; σ M 72→**62**, F 42→**40**. proReference M 380→**330**, F **210→200**.
- Paliers M : 360/175/100 → **330/170/95** ; F : 195/105/60 → **200/105/58**.
- Raisonnement : 55 reps/tour 100 % explosif (30 squat jumps + 25 burpee broad jumps), forte
  dégradation, ~3:30-4:00/tour. Régulier ≈ 3 tours = 170 (M) / ~2 tours = 105 (F) ; élite ≈ 6 tours =
  330/200 ; débutant ≈ 1,7 tour = 95/58. L'ancien proReference 380 (M) tombait au-delà de P99,99
  (modèle saturé) → ramené à 330 (P0.995), seuil élite atteignable.

### Le Chaos — `league_hybrid_chipper` (HYBRIDE, time, chipper cap 15')
- Modèle médiane M **720 s**, F 780→**790 s** ; σ M **0.30**, F **0.28**. proReference M 400→**430**, F **460→470**.
- Paliers M : 400/720/1020 → **430/720/1020** ; F : 460/780/1080 → **470/790/1080**.
- Raisonnement : chipper long (course + gym + explosif). Régulier ~12:00 (M) / ~13:10 (F) sous le
  cap ; élite ~7:10 (M, 430 s) / ~7:50 (F, 470 s) ; débutant proche du cap (~17:00 → ramené à
  1020/1080 s). Ancien champion 400 s (M) trop optimiste (P0.97) ; 430 s reste élite, plus crédible.

## Garde-fous (test/wods.data.spec.ts) — INCHANGÉS
Toutes les bornes de test restent en place :
- monotonie champion > inter > occ (sens du scoreType) ;
- champion ≥ P84, intermédiaire ∈ [P42, P58], occasionnel ∈ [P05, P30] ;
- proReference > P80 (cible élite).
Aucune borne n'a été affaiblie : les nouvelles valeurs passent les bandes existantes telles quelles.
