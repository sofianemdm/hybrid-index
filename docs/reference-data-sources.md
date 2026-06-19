# Données de référence pour la calibration des distributions — HYBRID INDEX

> **But du document.** Rassembler les meilleures données publiques disponibles pour ancrer,
> PAR SEXE, une distribution de performance sur chacun des 15 WODs de référence. Ces points
> serviront à l'expert `sport-science` à définir la chaîne de notation (mapping perf → score 0–100,
> normalisé par sexe). **Recherche web réalisée le 2026-06-19.**
>
> **Convention de lecture.** Pour les WODs « For Time », un temps PLUS BAS = meilleur.
> Pour les WODs en reps/tours, PLUS HAUT = meilleur. Les colonnes percentiles décrivent la
> POPULATION pratiquante (= meilleure que la population générale ; voir Méthodologie & limites).
>
> **Honnêteté.** Tout chiffre non sourcé est marqué `[ESTIMATION]` avec son raisonnement.
> Aucun chiffre n'est inventé sans ce marquage.

---

## Synthèse rapide (cibles élite et médianes par sexe)

| # | WOD | Unité | Élite H | Médiane H | Élite F | Médiane F | Confiance globale |
|---|-----|-------|---------|-----------|---------|-----------|-------------------|
| 1 | PFT HYROX | temps | ~52–58 min | ~1h20–1h30 | ~56–65 min | ~1h35–1h45 | Moyenne |
| 2 | Fran | mm:ss | <2:20 | ~5:30 | <3:00 | ~6:30 | Moyenne |
| 3 | Grace | mm:ss | <2:00 | 3:23 | <2:30 | 3:56 | Élevée (moy. H/F sourcée) |
| 4 | Jackie | mm:ss | <6:00 | ~9:00 | <7:00 | ~10:30 | Faible/Moyenne |
| 5 | 2000 m Rameur | mm:ss.s | <6:10 | ~7:30 | <7:15 | ~8:30 | Moyenne (logbook biaisé) |
| 6 | Helen | mm:ss | <7:30 | 9:50 | <9:00 | 11:14 | Élevée (moy. H/F sourcée) |
| 7 | Karen | mm:ss | <4:30 | ~9:00 | <5:30 | ~10:00 | Moyenne |
| 8 | Cindy | tours | 22–25 | ~16 | 18–22 | ~13 | Moyenne |
| 9 | Benchmark Zéro | mm:ss | ~9:00 `[EST]` | ~13:30 `[EST]` | ~10:30 `[EST]` | ~16:00 `[EST]` | Faible (estimé) |
| 10 | 5 km course | mm:ss | <17:30 | ~28–31 min | <19:30 | ~33–36 min | Élevée |
| 11 | 1 km course | mm:ss | <3:00 | ~5:00 | <3:30 | ~6:00 | Moyenne |
| 12 | Max pompes strictes | reps | 60+ | ~25 | 35+ | ~12 | Élevée (ACSM/APFT) |
| 13 | Air squats 2 min | reps | ~80+ | ~50 `[EST]` | ~75+ | ~45 `[EST]` | Faible/Moyenne |
| 14 | Burpees 7 min | reps | ~120+ | ~70 `[EST]` | ~105+ | ~60 `[EST]` | Faible (estimé) |
| 15 | Sit-ups 2 min | reps | 80+ | ~50 | 80+ | ~45 | Élevée (APFT) |

---

## AVEC MATÉRIEL

### 1) PFT HYROX (course + 8 stations, For Time)

| Sexe | Élite/Pro | ~90e pct | Médiane (~50e) | ~10e (débutant) | Source(s) + URL | Confiance | Échantillon |
|------|-----------|----------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | Pro <58:00 ; Open <1:05:00 ; **WR 53:15** | ~1:10–1:15 | Open ~1:20–1:30 ; toutes divisions ~1:40 | >2:00 | HyroxInsider ; Hyroxy | Moyenne | « plusieurs saisons », N non précisé |
| Femmes | Pro <1:05:00 ; Open <1:18:00 ; **WR 56:23** | ~1:22–1:28 | Open ~1:35–1:45 ; toutes divisions ~1:54 | >2:15 | HyroxInsider ; Hyroxy | Moyenne | id. |

- Sources : HyroxInsider — https://hyroxinsider.com/hyrox-average-finishing-time/ ; Hyroxy — https://hyroxy.com/hyrox-times/
- Note : l'app utilise un PFT inspiré HYROX (course + stations). Les vraies données HYROX = 8 km course + 8 stations ; à recalibrer si le format de l'app diffère en distance/charge.

### 2) Fran (21-15-9 thrusters 43/29 kg + tractions, For Time)

| Sexe | Élite | Avancé (~90e) | Médiane (~50e) | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | <2:00–2:20 | 4:00–4:40 | ~5:20–6:00 | 9:00–11:00 | Przilla ; Coachweb | Moyenne | N non précisé (échelles de niveau) |
| Femmes | <2:30–3:00 `[EST décalage H→F ~+25 %]` | ~4:30–5:30 `[EST]` | ~6:00–6:30 `[EST]` | 11:00–13:00 `[EST]` | Przilla (table H seulement) | Faible/Moyenne | — |

- Sources : Przilla — https://przilla.app/wod/fran ; Coach (Coachweb) — https://www.coachweb.com/fitness/full-body-workouts/workout-fran-in-crossfit
- Note : poids Rx « officiels » CrossFit = 43/29 kg (95/65 lb). La table par niveau est donnée surtout pour les hommes ; les valeurs femmes sont extrapolées par décalage proportionnel ~+25 % (cohérent avec l'écart H/F observé sur Grace et Helen).

### 3) Grace (30 clean & jerk 61/43 kg, For Time) — **donnée la plus solide**

| Sexe | Élite | Avancé (~90e) | Médiane / moyenne | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------------|--------------------|------------------|-----------------|-----------|-------------|
| Hommes | <2:00 (WR ~1:02) | ~1:50 (moy − 1 σ) | **moy 3:23, σ 1:34** | ~4:57 (moy + 1 σ) | Cebul.la ; Rhapsody | Élevée | grand jeu beyondthewhiteboard (N non chiffré) |
| Femmes | <2:30 | ~2:18 (moy − 1 σ) | **moy 3:56, σ 1:38** | ~5:34 (moy + 1 σ) | Cebul.la ; Rhapsody | Élevée | id. |

- Sources : Cebul.la — https://cebul.la/whats-a-good-grace-crossfit-time/ (moyenne + écart-type par sexe) ; Rhapsody — https://rhapsodyfitness.com/benchmark-grace/
- Note : moyenne et écart-type sourcés explicitement PAR SEXE → permet de poser une loi quasi-normale directement. Poids Rx = 61/43 kg (135/95 lb).

### 4) Jackie (1000 m row + 50 thrusters 20/15 kg + 30 tractions, For Time)

| Sexe | Élite | Avancé (~90e) | Médiane (~50e) | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | <6:00–6:30 | ~7:30 `[EST]` | ~9:00 `[EST]` | ~13:00 `[EST]` | WODStar ; Rhapsody | Faible/Moyenne | échelles de coaching, pas de stats |
| Femmes | <7:00 `[EST]` | ~8:30 `[EST]` | ~10:30 `[EST]` | ~15:00 `[EST]` | WODStar | Faible | — |

- Sources : WODStar — https://wodstar.com/uncategorized/jackie-wod/ ; Rhapsody — https://rhapsodyfitness.com/benchmark-jackie/
- Note : seules les bornes élite sont à peu près sourcées (sub-6 à sub-6:30 H). Médianes et percentiles sont des estimations dérivées du profil de Helen/Fran (charge légère, fort cardio). À affiner.

### 5) 2000 m Rameur Concept2 (temps)

| Sexe | Élite | ~90e pct | Médiane (~50e) | ~10e (débutant) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | **Top logbook 2024 : 5:40.6** ; élite réaliste <6:10 | ~6:40 | ~7:20–7:40 | ~8:30+ | Concept2 Logbook 2024 (M) | Moyenne | **9 690 entrées classées** (top du classement) |
| Femmes | **Top logbook 2024 : 6:45.2** ; élite réaliste <7:15 | ~7:50 | ~8:20–8:40 | ~9:40+ | Concept2 Logbook 2024 (F) | Moyenne | **2 304 entrées classées** |

- Sources : Concept2 Logbook 2024 — https://log.concept2.com/rankings/2024/rower/2000?gender=M et ...?gender=F
- Note importante : le logbook = population auto-sélectionnée et **classée volontairement** (compétiteurs). Les temps « top » sont des records, pas l'élite « courante ». Les percentiles ci-dessus sont des **estimations** positionnées plus lentes que le classement brut pour refléter une population « pratiquante générale ». Pour des percentiles exacts, exploiter la pagination du logbook (194 pages × 50 H) ou l'étude de référence (Held et al., percentiles 2000 m, rameurs 14–70 ans — ResearchGate : https://www.researchgate.net/publication/326688743).

### 6) Helen (3 rounds : 400 m run + 21 KB swings 24/16 kg + 12 tractions, For Time) — **donnée solide**

| Sexe | Élite | Avancé (~90e) | Médiane / moyenne | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------------|--------------------|------------------|-----------------|-----------|-------------|
| Hommes | <7:13 (régional) ; ~8:10 (FL98) | ~8:10 | **moy 9:50** | ~12:00+ | Cebul.la ; CrossFit.com | Élevée | grand jeu beyondthewhiteboard |
| Femmes | <8:30 `[EST]` | ~9:30 `[EST]` | **moy 11:14** | ~13:30+ | Cebul.la | Élevée (moy.) / Moyenne (pct) | id. |

- Sources : Cebul.la — https://cebul.la/whats-a-good-helen-crossfit-time/ (moyennes H/F) ; CrossFit.com — https://www.crossfit.com/helen
- Note : moyennes sourcées par sexe. Écart-type non publié → percentiles approximés par analogie avec Grace (σ ≈ 1:30–1:45).

### 7) Karen (150 wall balls 9/6 kg, For Time)

| Sexe | Élite | Avancé (~90e) | Médiane (~50e) | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | <4:00 (plancher ~4:20) | 6:00–7:00 | ~9:00–10:00 | >14:00 | WODtimecalculator ; Rhapsody | Moyenne | échelles de niveau, N non précisé |
| Femmes | <5:00 `[EST]` | ~7:00–8:00 `[EST]` | ~10:00–11:00 `[EST]` | >15:00 `[EST]` | id. | Faible/Moyenne | — |

- Sources : WODtimecalculator — https://www.wodtimecalculator.com/blog/karen/ ; Rhapsody — https://rhapsodyfitness.com/benchmark-karen/
- Note : les bornes données (élite ~4:00, avancé 6–7, moyen ~10, déb. <14) ne sont pas ségrégées par sexe dans la source. Charge légère (9/6 kg) → écart H/F modéré ; femmes estimées ~+10–15 %.

### 8) Cindy (AMRAP 20 min : 5 tractions / 10 pompes / 15 air squats — score = tours)

| Sexe | Élite | Avancé (~90e) | Médiane (~50e) | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | 22–25+ tours | 18–20 | ~16 | 6–8 | Marathonhandbook/Fitnessvolt ; Przilla | Moyenne | données CrossFit Open 2024 (agrégées) |
| Femmes | 18–22 tours | 15–17 | ~13 | 5–7 | id. | Moyenne | id. |

- Sources : Fitness Volt — https://fitnessvolt.com/20-minute-cindy-workout/ ; Przilla — https://przilla.app/wod/cindy
- Note : sources divergentes sur l'élite (20–22 « réaliste » vs 25–30 « théorique L10 »). On retient 22–25 H / 18–22 F comme borne élite crédible. Score = tours (+ reps de fraction si besoin de granularité).

---

## SANS MATÉRIEL

### 9) Benchmark Zéro (1 km run + 30 pompes + 30 air squats + 1 km run, For Time) — **aucune donnée publique, ESTIMATION raisonnée**

Construction par somme des composantes mesurables (voir WODs 11, 12, 13) + un buffer de transition/fatigue.

| Sexe | Élite `[EST]` | Médiane (~50e) `[EST]` | Débutant (~10e) `[EST]` | Confiance |
|------|---------------|--------------------------|---------------------------|-----------|
| Hommes | ~9:00 | ~13:30 | ~20:00+ | Faible |
| Femmes | ~10:30 | ~16:00 | ~23:00+ | Faible |

**Raisonnement (médiane hommes) :** 2 × 1 km à allure médiane (~5:00/km → 10:00 pour 2 km) + 30 pompes (~1:00–1:30) + 30 air squats (~0:45) + transitions/fatigue (~1:15) ≈ **13:30**.
**Élite hommes :** 2 × 1 km à ~3:30/km (7:00) + pompes/squats quasi unbroken (~1:20) + transitions (~0:40) ≈ **9:00**.
**Femmes :** mêmes composantes décalées (course ~6:00/km médiane ; pompes plus limitantes → +60–90 s).
À VALIDER en collectant des temps réels dès les premiers utilisateurs (calibrage prioritaire car WOD propriétaire).

### 10) 5 km course (temps) — **donnée solide (gros échantillon)**

| Sexe | Élite (~1e–top) | Top 10% | Médiane (~50e) | ~10e lent (90e) | Source(s) + URL | Confiance | Échantillon |
|------|------------------|---------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | 17:49 (1er pct) ; sub-17:30 élite | 22:06 | **31:18** (moy 35:22) | 53:22 | RunRepeat (US 5K stats) | Élevée | grand N (agrégat courses US) |
| Femmes | 19:29 (1er pct) ; sub-19:30 élite | 25:16 | **36:24** (moy 41:21) | 56:31 | RunRepeat | Élevée | id. |

- Sources : RunRepeat — https://runrepeat.com/the-us-5k-stats-page (percentiles 1/10/50/90 par sexe) ; complément distribution running level — https://runninglevel.com/running-times/5k-times
- Note : médianes « course chronométrée » (un peu plus rapides que parkrun, qui inclut beaucoup de marcheurs). Pour une population plus large, décaler la médiane vers ~+2–3 min.

### 11) 1 km course (temps)

| Sexe | Élite | ~90e pct | Médiane (~50e) | ~10e (débutant) | Source(s) + URL | Confiance | Échantillon |
|------|-------|----------|----------------|------------------|-----------------|-----------|-------------|
| Hommes | <3:00 | ~3:45 | ~5:00 (≈ allure mile 6:38 → ~4:07/km « bon ») | ~6:30–7:30 | RunningLevel (mile) ; Marathon Handbook | Moyenne | dérivé tables mile |
| Femmes | <3:30 | ~4:20 | ~6:00 (≈ allure mile 7:44 → ~4:48/km « bon ») | ~7:30–8:30 | id. | Moyenne | id. |

- Sources : Running Level — https://runninglevel.com/running-times/1-mile-times ; Marathon Handbook — https://marathonhandbook.com/whats-a-good-mile-time/
- Note : pas de table 1 km par sexe directement publiée ; valeurs dérivées des tables mile (1,609 km) et de la médiane 5 km. Le 1 km médian « pratiquant » est nettement plus rapide à l'allure que le 5 km (effort court).

### 12) Max pompes strictes à l'échec (reps) — **donnée solide (ACSM + APFT)**

| Sexe | Élite (~99e) | Excellent (~90e) | Moyenne (~50e) | Faible (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|---------------|-------------------|-----------------|----------------|-----------------|-----------|-------------|
| Hommes 20–29 | 60+ (max APFT 77) | >47 | 17–29 (~25) | 4–9 | TopEndSports (ACSM) ; Military.com (APFT) | Élevée | normes ACSM standardisées |
| Hommes 30–39 | 50+ | >41 | 13–24 | 2–7 | id. | Élevée | id. |
| Femmes 20–29 (strict) | 35+ | >32 | 9–13 (~12) | 1–4 | TopEndSports (ACSM) | Élevée | id. |
| Femmes 30–39 (strict) | 32+ | >28 | 7–12 | 1–2 | id. | Élevée | id. |

- Sources : Top End Sports / normes ACSM — https://www.topendsports.com/testing/tests/home-pushup.htm ; APFT (max 77 H / 100 F en version genrée, mais sur pompes « assistées » comptées différemment) — https://www.military.com/military-fitness/army-fitness-requirements/army-physical-fitness-test-score-chart
- Note : les pompes STRICTES (poitrine au sol, corps gainé) donnent des chiffres plus bas que les pompes APFT. On retient les normes ACSM (technique stricte) comme référence principale. L'écart H/F est ici réel et fort (≈ ×2) → la normalisation par sexe est indispensable.

### 13) Max air squats en 2 min (reps)

| Sexe | Élite (~99e) | Excellent (~90e) | Médiane (~50e) | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|---------------|-------------------|-----------------|------------------|-----------------|-----------|-------------|
| Hommes | ~85+ `[EST]` | ~70 `[EST]` | ~50 `[EST]` | ~30 `[EST]` | TopEndSports (squat test, 1 min) extrapolé | Faible/Moyenne | norme 1 min, pas 2 min |
| Femmes | ~80+ `[EST]` | ~65 `[EST]` | ~45 `[EST]` | ~28 `[EST]` | id. | Faible/Moyenne | id. |

- Sources : Top End Sports squat test — https://www.topendsports.com/testing/tests/home-squat.htm (« excellent » H 20–29 ≥35, moy 27–29 ; F ≥30 / 21–23 — sur test 1 min ou à l'échec)
- Raisonnement : la norme publique est sur ~1 min (H « excellent » ≥35). Sur 2 min, la cadence baisse mais le total grimpe ; on extrapole ×~2 avec décrément de fatigue → médiane ~50 H / ~45 F. **Écart H/F faible** (mouvement au poids de corps, peu discriminant). À calibrer sur données réelles.

### 14) Test burpees 7 min (max reps) — **ESTIMATION (bornes hautes sourcées)**

| Sexe | Élite (~99e) `[EST]` | Avancé (~90e) `[EST]` | Médiane (~50e) `[EST]` | Débutant (~10e) `[EST]` | Source(s) + URL | Confiance | Échantillon |
|------|------------------------|-------------------------|--------------------------|---------------------------|-----------------|-----------|-------------|
| Hommes | ~120–130 | ~95 | ~70 | ~40 | Bornes : Guinness 1 min H = 50 ; 1 h H = 949 | Faible | records (bornes seulement) |
| Femmes | ~105–115 | ~85 | ~60 | ~35 | Bornes : Guinness 1 min F = 44 ; 1 h F = 716 | Faible | records (bornes seulement) |

- Sources (bornes) : Guinness « most burpees in one minute » — male 50 (https://www.guinnessworldrecords.com/world-records/112069-most-burpees-in-one-minute-male), female 44 (https://www.guinnessworldrecords.com/world-records/102699-most-burpees-in-one-minute-female) ; 1 h male 949 / female 716.
- Raisonnement : le test « CrossFit » classique « 7 min burpees » vise souvent **100+ = très bon**, **~70–80 = solide moyenne pratiquant**. Borne haute encadrée par : record 1 min ≈ 50 (insoutenable 7 min) et cadence 1 h (949/60 ≈ 16/min mais soutenue) → une élite « 7 min » plausible ~18/min × 7 ≈ 126. Écart H/F modéré (mouvement au poids de corps, fort composante cardio). **Calibrage réel prioritaire.**

### 15) Max sit-ups en 2 min (reps) — **donnée solide (APFT)**

| Sexe | Élite (~99e) | Excellent (~90e) | Médiane (~50e) | Débutant (~10e) | Source(s) + URL | Confiance | Échantillon |
|------|---------------|-------------------|-----------------|------------------|-----------------|-----------|-------------|
| Hommes 17–21 | 82 (max APFT) | ~70 | ~50 | ~30 | Military.com (APFT sit-up) | Élevée | barème standardisé Army |
| Femmes 17–21 | 82 (max APFT) | ~70 | ~45 | ~28 | id. | Élevée | id. |

- Sources : Military.com APFT sit-up — https://www.military.com/military-fitness/army-fitness-requirements/army-pft-sit-up-score-chart
- Note : **l'APFT applique le MÊME barème sit-ups aux deux sexes** (max 100 pts = 82 reps en 2 min ; min 60 pts = 59 reps 17–21). L'écart H/F réel sur les sit-ups est faible → on garde un barème quasi identique, médiane femmes légèrement abaissée par prudence. Les percentiles intermédiaires sont interpolés depuis le barème de points (60–100 pts).

---

## Méthodologie & limites

**1. Nature des « percentiles ».** Sauf 5 km (RunRepeat) et Grace/Helen (moyenne + σ sourcées),
la plupart des « niveaux » proviennent d'échelles de coaching (Przilla, WODtimecalculator, Rhapsody)
et non d'une vraie distribution statistique. Ils donnent des ANCRAGES, pas des percentiles exacts.

**2. Biais d'auto-sélection.**
- *Concept2 logbook* : seuls les rameurs qui DÉCIDENT de classer leur temps y figurent → population
  bien plus rapide que la population générale. Les « top times » (5:40 H / 6:45 F) sont des records,
  à ne PAS confondre avec la médiane.
- *Leaderboards CrossFit / beyondthewhiteboard* : pratiquants réguliers → médianes plus rapides que
  le grand public débutant.
- *Courses 5 km (RunRepeat)* : inscrits payants → plus entraînés que parkrun (qui inclut marcheurs).

**3. Barèmes militaires (APFT/ACSM) : ce qu'ils valent.**
- APFT pompes : barème historiquement genré (max 77 H / 100 F) mais sur une technique « assistée »
  comptée différemment des pompes strictes → on privilégie ACSM (strict) pour les pompes.
- APFT sit-ups : barème IDENTIQUE H/F → confirme un faible dimorphisme sur cet exercice.
- ACFT actuel : gender-neutral, plank au lieu de sit-ups → moins utile ici ; on garde l'APFT.

**4. Données extrapolées / estimées (à valider en priorité avec données réelles utilisateurs) :**
- **Benchmark Zéro (#9)** : 100 % estimé (WOD propriétaire) — somme des composantes + buffer.
- **Burpees 7 min (#14)** : seules les bornes Guinness sont sourcées ; la distribution est estimée.
- **Air squats 2 min (#13)** : norme publique sur 1 min, extrapolée à 2 min.
- **Côté femmes de Fran/Jackie/Karen** : tables souvent publiées pour hommes ; femmes décalées
  proportionnellement (~+10 à +25 % selon la part de charge externe vs poids de corps).
- **1 km course (#11)** : dérivé des tables mile + médiane 5 km (pas de table 1 km par sexe directe).

**5. Dimorphisme sexuel — implication pour la normalisation PAR SEXE (décision verrouillée).**
- Fort écart H/F : pompes strictes (≈ ×2), exercices à charge externe lourde (Grace, Fran).
- Écart modéré : course (5 km ~+15 %, mile ~+16 %), wall balls, Helen (~+14 %).
- Écart faible : sit-ups (barème identique), air squats, burpees (mouvements au poids de corps).
  → La normalisation par sexe est CRITIQUE sur les WODs à charge externe, secondaire (mais conservée
  pour cohérence) sur les WODs au poids de corps.

**6. Prochaines étapes recommandées pour `sport-science` :**
- Exploiter la pagination complète du Concept2 logbook (194 pages H / ~46 pages F) pour extraire de
  vrais percentiles 2 km par sexe.
- Récupérer les écarts-types beyondthewhiteboard pour Fran/Jackie/Karen/Cindy (comme Grace/Helen)
  afin de poser des lois normales par sexe partout.
- Mettre en place une collecte interne des temps Benchmark Zéro + burpees 7 min dès les premiers
  utilisateurs (les deux WODs les moins ancrés).

---

## Index des sources (URL)

- HYROX : https://hyroxinsider.com/hyrox-average-finishing-time/ · https://hyroxy.com/hyrox-times/
- Fran : https://przilla.app/wod/fran · https://www.coachweb.com/fitness/full-body-workouts/workout-fran-in-crossfit
- Grace : https://cebul.la/whats-a-good-grace-crossfit-time/ · https://rhapsodyfitness.com/benchmark-grace/
- Jackie : https://wodstar.com/uncategorized/jackie-wod/ · https://rhapsodyfitness.com/benchmark-jackie/
- Rameur 2k : https://log.concept2.com/rankings/2024/rower/2000?gender=M · ...?gender=F · https://www.researchgate.net/publication/326688743
- Helen : https://cebul.la/whats-a-good-helen-crossfit-time/ · https://www.crossfit.com/helen
- Karen : https://www.wodtimecalculator.com/blog/karen/ · https://rhapsodyfitness.com/benchmark-karen/
- Cindy : https://fitnessvolt.com/20-minute-cindy-workout/ · https://przilla.app/wod/cindy
- 5 km : https://runrepeat.com/the-us-5k-stats-page · https://runninglevel.com/running-times/5k-times
- 1 km / mile : https://runninglevel.com/running-times/1-mile-times · https://marathonhandbook.com/whats-a-good-mile-time/
- Pompes (ACSM/APFT) : https://www.topendsports.com/testing/tests/home-pushup.htm · https://www.military.com/military-fitness/army-fitness-requirements/army-physical-fitness-test-score-chart
- Air squats : https://www.topendsports.com/testing/tests/home-squat.htm
- Burpees (Guinness) : https://www.guinnessworldrecords.com/world-records/112069-most-burpees-in-one-minute-male · .../102699-most-burpees-in-one-minute-female
- Sit-ups (APFT) : https://www.military.com/military-fitness/army-fitness-requirements/army-pft-sit-up-score-chart
