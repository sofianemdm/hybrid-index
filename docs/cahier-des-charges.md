# HYBRID INDEX — Cahier des charges AAA (v6 · réécriture pro)

> **Pitch :** *La seule app qui transforme la condition physique hybride en un seul score comparable — le **HYBRID INDEX** — qui devient ton niveau de personnage. Tu notes chaque WOD contre le niveau des pros, tu grimpes dans le classement mondial par sexe, et tu vises toujours plus haut. Avec ou sans matériel. Tout est public.*
>
> **Question signature :** *« T'as combien à ton Hybrid Index ? »*
>
> *Document auto-suffisant : un designer ou un développeur doit pouvoir construire sans poser de question.*

---

## 1. Vision, positionnement & avantage défendable

### Le problème
Les athlètes hybrides (CrossFit, HYROX, runners qui soulèvent) jonglent entre plusieurs apps, sans jamais savoir **« où je me situe »** sur une échelle unique et comparable. Les apps existantes font chacune *une* chose : tracking (Strava), programmation (Edge, ROXFIT), charge d'entraînement (TrainingPeaks), mobilité (GOWOD).

### Notre proposition unique
Réunir les **trois** ingrédients qui créent une obsession saine :
1. **Un score unique, normalisé par sexe et comparable** (le Hybrid Index) → tout le monde sur la même échelle.
2. **Une mécanique RPG** (niveau, rangs, radar, avatar évolutif, rival) → l'envie de monter.
3. **Un classement 100 % public** → la comparaison sociale, premier moteur de motivation chez les sportifs.

### Pourquoi on gagne (avantage défendable)
- **Catégorie nouvelle :** personne ne propose *un score hybride unique + classement public + progression RPG*. On ne se bat pas sur le tracking ou la programmation : on crée la catégorie « score de référence ».
- **Effet de réseau (le vrai fossé) :** chaque nouvel utilisateur (a) rend les **percentiles plus précis**, (b) ajoute un **rival/concurrent** potentiel, (c) remplit les **classements par WOD**. Plus l'app grandit, plus elle est précise et motivante — donc plus dure à déloger.
- **Accessibilité totale :** utilisable **sans matériel ni box** → marché 10× plus large que les apps « box-centric ».
- **Viralité native :** chaque exploit produit une carte partageable ; chaque défi recrute un ami.

### Anti-vision (ce qu'on ne fait PAS)
Pas un énième tracker. Pas un programme d'entraînement rigide. Pas une app qui culpabilise. **On mesure, on classe, on motive à progresser.**

---

## 2. Décisions verrouillées (non négociables)

| Décision | Choix |
|---|---|
| Nom de l'app **et** du score | **HYBRID INDEX** |
| Normalisation du score | **par sexe uniquement** (jamais d'âge, jamais de poids) |
| Plateformes | iOS **et** Android (base unique) |
| Prix | **100 % gratuit** (pour l'instant) |
| Données | **Déclarées** (non vérifiées, pour l'instant) |
| Sans matériel ni box | **App 100 % utilisable sans rien** |
| Question matériel | **« avec ou sans matériel ? »** (préférence persistante) |
| « 3 entraînements suffisent » | **~3 efforts → Index complet** |
| Temps de course (onboarding) | **conseillé, non obligatoire** (skippable) |
| Avatar | création en **30 s max** |
| Supprimés (ne PAS réintroduire) | quêtes, saisons, score de fatigue, catégories de poids |
| Ligues | **2 uniquement : Hommes + Femmes**, tous les athlètes, **classées par Hybrid Index** |
| Classement box / amis | **après 200 utilisateurs** (hors MVP) |
| WODs de référence | **15** (8 avec matériel, 7 sans), avec **les temps de tous** |
| Ciblage d'un axe | choisir un attribut → WODs spécifiques |
| Confidentialité | **Tout est public** |
| Ton | **positif / dopaminergique**, orienté progression |

**Architecture unificatrice :** un seul barème **0→1000** → (1) note d'un effort vs élite par sexe → (2) regroupée par qualité = les **6 attributs du radar** → (3) agrégée = le **HYBRID INDEX**.

---

## 3. Principes de conception (la doctrine produit)

1. **Time-to-value immédiat** : un chiffre et un « waouh » en moins de 60 s, pour 100 % des inscrits.
2. **Chaque action a une conséquence visible** : tout effort logué fait bouger un chiffre, une jauge ou un rang.
3. **Dopamine honnête** : on célèbre fort les vraies étapes ; on ne ment jamais sur le niveau. La valeur sociale de l'app *dépend* de la crédibilité du « top 5 % ».
4. **Objectifs proximaux** : toujours une prochaine marche atteignable (rival à 7 pts, +47 pts avant Platine).
5. **Engagement sain, pas addiction toxique** : on récompense la régularité et la récupération, jamais le surentraînement. Les dark patterns détruisent la rétention long terme et sont proscrits.
6. **Le score ne baisse jamais brutalement** : on protège l'ego (meilleur effort retenu), tout en encourageant le re-test par la *fraîcheur*, pas par la punition.
7. **Beau et fluide** : animations, haptique, son ; finition de jeu vidéo.

---

## 4. Le modèle d'engagement (le cœur addictif)

### 4.1 La boucle d'habitude (Hooked)
**Déclencheur** (notif cadrée / streak / séance suggérée / rival qui bouge) → **Action** (faire + logger un WOD) → **Récompense variable** (note, percentile, place gagnée, attribut qui monte, rival dépassé, badge) → **Investissement** (radar, historique, rang, badges, avatar → on a quelque chose à défendre) → déclencheur suivant.

### 4.2 Lecture Octalysis (les ressorts activés)
- **Accomplissement** : Index, rangs, badges, barre de progression.
- **Appartenance/comparaison sociale** : classements publics, rival, kudos.
- **Rareté/impatience** : paliers de percentile (top 1 %), benchmarks à compléter.
- **Imprévisibilité** : reveal animé du score (on ne connaît le résultat qu'à la fin).
- **Sens/empowerment** : « deviens un meilleur athlète », progression mesurable.
> On évite volontairement les ressorts « négatifs » toxiques (peur de perte agressive, FOMO punitif).

### 4.3 Les 7 leviers qui poussent à « viser plus haut »
1. **RIVAL** ⭐ — l'app désigne en permanence **l'athlète actif juste au-dessus de toi** dans ta ligue : *« Bats Julien (412) — il n'est qu'à 7 points. »* Duel personnel et atteignable. Le dépasser → célébration + nouveau rival. (Logique détaillée §11.4.)
2. **Barre « prochain rang »** — toujours visible : *« Encore 47 pts avant PLATINE. »* (gradient d'objectif).
3. **Index projeté** ⭐ — *« Amène ta Force au niveau de ton Engine → Index ~580 (PLATINE). »* Chiffre la récompense de travailler sa faiblesse → moteur du ciblage d'axe.
4. **Battre le pro** — sur chaque WOD : *« 66 % du niveau élite — il te manque 1:40 pour 80 %. »*
5. **Paliers de percentile** — célébrations marquantes : top 25 / 10 / 5 / 1 %.
6. **PR & déblocages** — record personnel, attribut débloqué, montée de rang = moment dopaminergique (anim + confettis + haptique + son).
7. **Badges & collection** — compléter des WODs, des séries, des défis (§12).

### 4.4 L'endgame (rétention des experts — point critique)
Une fois en Diamant/Élite, le rival se raréfie. On maintient l'obsession par :
- **« Le Grand Chelem »** : battre le **pro reference** sur les 15 WODs (badge prestige).
- **Top-100 mondial par sexe** + **top-100 par WOD** (le seul classement « absolu »).
- **« % vers le record du monde »** affiché comme cible ultime.
- **Cadence de re-test** : chasser ses propres PR sur les benchmarks fondateurs.
- **Statut d'ambassadeur** (cadre/aura exclusifs) pour le top, qui devient moteur de communauté.

### 4.5 Rétention par horizon
| Horizon | Ce qui fait revenir |
|---|---|
| **J1** | Le reveal de l'Index + « complète ton Index » (déblocage des attributs). |
| **J2–J7** | Séance suggérée du jour, streak naissant, premier rival, premières cartes à partager. |
| **J7–J30** | Récap hebdo, montée de rang, ciblage d'axe + Index projeté, défis d'amis. |
| **J30+** | Classements, endgame, communauté/box (post-200), cadence de re-test. |

### 4.6 Le streak intelligent (sain)
Récompense la **régularité**, pas le volume. Un **repos planifié maintient la série** (1 « jour de repos » utilisable/semaine, configurable). Jamais de notification culpabilisante.

---

## 5. Le système de score : HYBRID INDEX & radar

### 5.1 Le radar (le diagnostic) — 6 attributs
Chaque attribut : score **0–1000** + percentile par sexe + état (verrouillé/débloqué) + indicateur de fraîcheur.

| Attribut | Définition | Mesuré AVEC matériel | Mesuré SANS matériel |
|---|---|---|---|
| **Engine** | Endurance aérobie | 2000 m row, runs longs, ski | Runs (5 km), burpees longue durée |
| **Vitesse** | Explosivité de course | Sprints | 1 km, sprints |
| **Force** | Force max | Grace, Jackie (charges) | **Proxy bodyweight** (max pompes) — *estimation* |
| **Puissance** | Force-vitesse | Wall balls (Karen), cleans | Squat jumps, burpees |
| **Endurance musc.** | Volume / gymnastique | Fran, Cindy, tractions | Pompes, squats, sit-ups |
| **Hybride** | Enchaîner course + stations | PFT, Helen | Benchmark Zéro, test burpees |

> **Radar vs Index :** le **radar = le détail** (6 jauges, pour se diagnostiquer) ; le **Hybrid Index = le résumé** (1 chiffre, pour se classer). L'Index est calculé à partir du radar. Sans matériel, la **Force** est un proxy (flag `isEstimated`).

### 5.2 La chaîne de calcul (concrète et constructible)

**Étape 1 — Sous-score d'un effort (0–1000).**
Pour un résultat `R` (temps/reps/charge/distance) d'un athlète de sexe `S` sur un WOD donné :
1. Calculer le **percentile** `P ∈ [0,1]` de `R` dans la **distribution de référence sexe `S`** de ce WOD.
2. Mapper `P → sous-score` via une courbe monotone **calibrée** `f` :
   `sous_score = 1000 × f(P)`
   - `f` est calibrée pour que : médiane population ≈ **450**, gains **rapides au milieu** (dopamine débutant), **lents aux extrêmes** (haut difficile). Courbe par défaut (à affiner) : sigmoïde douce centrée sur la médiane. *(La forme exacte de `f` est un paramètre de calibration, versionné.)*

**Étape 2 — Score d'un attribut (0–1000).**
`attribute_score(A) = meilleur sous-score parmi les efforts taguant A` dans la fenêtre de fraîcheur (par défaut 26 semaines).
- Conséquence : **le score ne baisse jamais** sur un mauvais jour (on garde le meilleur).
- `unlocked(A) = true` dès ≥ 1 effort qualifiant.

**Étape 3 — HYBRID INDEX (0–1000).**
```
HYBRID INDEX = Σ (w_A × attribute_score_A) / Σ w_A   // sur attributs débloqués
```
- `w_A` dépend de l'**objectif** : *HYROX* → surpondère Engine + Hybride ; *Force CrossFit* → Force + Puissance ; *Partout* → poids égaux.
- **Provisoire** tant que la couverture < seuil (≥ 4 attributs sur 6 débloqués **ou** règle des 3 efforts atteinte). Affiché « provisoire » + invitation à compléter.
- **Percentile de l'Index** dans la distribution sexe `S` → « meilleur que X % ».

### 5.3 Cold-start & calibration des données (chantier critique)
- **Bootstrap** des distributions par sexe à partir de **données publiques** : distributions de temps de course (parkrun, marathons), classements Concept2 (row), bases de temps de WODs CrossFit connus, leaderboards PFT HYROX, normes publiques pompes/sit-ups.
- **Auto-amélioration** : dès `N ≥ seuil` résultats déclarés par WOD/sexe, recalcul des percentiles sur les données réelles de la communauté.
- **Indicateur de confiance** affiché : « calibré sur données publiques » → « calibré sur la communauté (n=…) ». Honnêteté = crédibilité.

### 5.4 Fraîcheur (re-test sans score de fatigue, sans baisse)
- Chaque effort a un **âge**. Si un benchmark clé dépasse ~8–12 semaines : **invitation douce** à le refaire + petit indicateur « à rafraîchir » sur l'attribut concerné.
- **Le score ne diminue jamais automatiquement.** On encourage par l'envie (PR potentiel), pas par la punition. *(Respecte les verrous « pas de score de fatigue » et « ne baisse jamais brutalement ».)*

### 5.5 Anti-triche minimal (en attendant la vérification)
Données déclarées → on ne peut pas garantir l'intégrité, mais on limite les abus évidents :
- **Bornes physiologiques** : un résultat hors plage plausible (par sexe/WOD) est refusé ou marqué « à vérifier » et **exclu des classements**.
- **Détection d'anomalie** : saut de perf impossible (ex. +30 % en 7 jours) → flag + non comptabilisé pour l'élite.
- **Champ `source`** (`declared` / `verified`) prêt pour brancher montres et résultats officiels (Phase 3).

---

## 6. La notation des WODs

### 6.1 Flux de saisie
Matériel (prérempli selon la préférence, surchargeable) → **choisir un WOD** (bibliothèque filtrée matériel, ou **custom**) → **type** (*For Time / AMRAP / EMOM / Chipper / Force / Intervalle*) → **mouvements, reps, charges optionnelles** (bodyweight géré) → **résultat** (temps / tours-reps / charge / distance) → **calcul** → **écran résultat**.

### 6.2 Le reveal du résultat (récompense variable, à soigner)
Séquence : (1) « Calcul en cours… » (suspense court) → (2) **la note monte en s'incrémentant** → (3) **positionnement** : *« Pros : ~7:30. Ton 11:20 = 66 % du niveau élite — top 19 % des hommes. 🔥 »* → (4) **conséquences** : attribut(s) qui montent (anim), Index mis à jour, rival/rang impactés, badge éventuel → (5) **CTA partage** + **CTA prochaine séance**.

### 6.3 Référence « pro » — deux cas
- **WOD de référence (précis)** : distributions réelles par sexe jusqu'à l'élite (les 15 WODs). **Priorité data.**
- **WOD custom (estimation)** : modèle de difficulté `Σ (coefficient_mouvement × charge_relative × volume) + modèle de cadence` → temps élite estimé. **Affiché comme estimation** (fourchette + label). S'améliore avec les données.

### 6.4 Cas limites
- **WOD sans référence encore** : afficher la note relative à la communauté (si dispo) ou « référence en cours de calibration » ; jamais de faux chiffre.
- **Résultat incohérent** : message clair + correction ; non comptabilisé tant qu'invalide.
- **Mode guidé** : pour les benchmarks (Benchmark Zéro, PFT…), proposer un **chrono + compteur de reps intégré** → réduit la friction et fiabilise la saisie.

---

## 7. Les 15 WODs de référence (les temps de tous, par sexe)

15 benchmarks standardisés. Pour **chacun** : un **classement par sexe avec tous les athlètes**, + ton rang, + l'écart au rival. Score = la métrique indiquée.

### 8 WODs AVEC matériel
| # | WOD | Type / Score | Attributs | Matériel |
|---|---|---|---|---|
| 1 | **PFT HYROX** (1000 m run · 50 burpee broad jumps · 100 fentes · 1000 m row · 30 pompes HR · 100 wall balls) | For Time | Engine, End. musc, Puissance, Hybride | Rameur, wall ball |
| 2 | **Fran** (21-15-9 thrusters 43/29 kg + tractions) | For Time | End. musc, Puissance | Barre, barre traction |
| 3 | **Grace** (30 clean & jerk 61/43 kg) | For Time | Puissance, Force | Barre |
| 4 | **Jackie** (1000 m row · 50 thrusters 20/15 kg · 30 tractions) | For Time | Engine, End. musc, Puissance, Force | Rameur, barre, barre traction |
| 5 | **2000 m Rameur** (Concept2) | Temps | Engine | Rameur |
| 6 | **Helen** (3 tours : 400 m run · 21 KB swings 24/16 kg · 12 tractions) | For Time | Engine, End. musc, Hybride | Kettlebell, barre traction |
| 7 | **Karen** (150 wall balls 9/6 kg) | For Time | Puissance, End. musc | Wall ball |
| 8 | **Cindy** (AMRAP 20 min : 5 tractions · 10 pompes · 15 air squats) | AMRAP (tours) | End. musc, Engine | Barre de traction |

### 7 WODs SANS matériel
| # | WOD | Type / Score | Attributs |
|---|---|---|---|
| 9 | **Benchmark Zéro** (1 km run · 30 pompes · 30 air squats · 1 km run) — *signature* | For Time | Engine, End. musc, Hybride |
| 10 | **5 km Course** | Temps | Engine |
| 11 | **1 km Course** | Temps | Vitesse, Engine |
| 12 | **Max pompes** (strict, à l'échec) | Reps | Force (proxy), End. musc |
| 13 | **Max air squats en 2 min** | Reps | End. musc, Puissance |
| 14 | **Test burpees 7 min** (max burpees) | Reps | Engine, End. musc, Puissance, Hybride |
| 15 | **Max sit-ups en 2 min** | Reps | End. musc (gainage/core) |

> Couverture des 6 attributs assurée des deux côtés. **Benchmarks fondateurs** de l'onboarding : **Benchmark Zéro** (sans matériel) et **PFT HYROX** (avec). La bibliothèque s'étend après le MVP.
> **Angle mort assumé :** sans matériel, la **Puissance explosive pure** repose surtout sur les burpees (pas de test de saut). Acceptable au lancement ; à compléter plus tard si besoin.

---

## 8. L'onboarding — écran par écran (« waouh » < 60 s)

| # | Écran | Contenu | Friction / règle |
|---|---|---|---|
| 1 | **Accroche** | « Découvre ton Hybrid Index. » → *Commencer* | 1 tap |
| 2 | **Avatar (≤ 30 s)** | Nom · Sexe (= normalisation) · Couleur de peau · Cheveux · Barbe (masquable). Aperçu **temps réel**. | Tactile, 0 clavier sauf nom |
| 3 | **Objectif** | *Améliorer mon temps HYROX* / *Devenir plus fort en CrossFit* / *Progresser partout* | 1 tap |
| 4 | **Avec ou sans matériel ?** | *Sans matériel* / *Avec matériel* / *Ça dépend* | 1 tap, préférence persistante |
| 5 | **Temps de course (conseillé)** | 1 / 5 / 10 km + temps → Index provisoire en 10 s. **Bouton Passer.** | Non obligatoire |
| 5bis | **Auto-évaluation (fallback)** ⭐ | *Si l'utilisateur passe la course :* 3 taps (niveau de course estimé · pompes max approx · expérience) → **Index provisoire ESTIMÉ** clairement étiqueté. | Garantit un chiffre pour 100 % des inscrits |
| 6 | **LE REVEAL** | Confettis, chiffre qui monte : *« Ton HYBRID INDEX : 247 — déjà meilleur que 73 % de la population ! »* + radar (Engine + Vitesse remplis, reste verrouillé). | Le moment clé |
| 7 | **« Complète ton Index »** | Selon matériel : **Benchmark Zéro** (+ test bodyweight) ou **PFT HYROX** (conseillé). Mode **guidé** dispo (chrono + compteur). | Rien d'obligatoire ; 3 efforts suffisent |

> Tout effort réel **remplace** l'estimation et fiabilise l'Index. L'estimation reste marquée jusqu'au premier benchmark.

---

## 9. L'avatar & l'écran de personnage (le hub)

### 9.1 Avatar
- **Sprites 2D en couches** (corps teinté + cheveux + barbe + cosmétiques). Léger, instantané, identité visuelle forte.
- **Évolue avec l'Index** : montées de rang = tenues, accessoires, **cadres**, **auras**. **Tout se gagne, rien ne s'achète** (déblocages liés aux **paliers d'Index** et aux **badges**).

### 9.2 Rangs (paliers du Hybrid Index)
Rookie (0–150) · Bronze (150–300) · Argent (300–450) · Or (450–600) · Platine (600–750) · Diamant (750–900) · Élite (900–1000). Chaque passage = grande célébration + déblocage cosmétique. **Élite** affiche un cadre prestige.

### 9.3 Écran d'accueil (hub) — contenu
Avatar + cadre de rang · **Hybrid Index** + percentile · **barre « prochain rang »** · **bloc rival** (« bats X, +7 pts ») · **radar** · **streak** · **dernier WOD noté** · **séance suggérée du jour** · accès rapides *Ajouter un WOD* / *Explorer*.

---

## 10. Le moteur de recommandation d'entraînement

### 10.1 Deux modes
- **Automatique** : lit le radar → repère l'attribut au **plus grand déficit pondéré** `(w_objectif × (max−score))` → propose une séance ciblée (filtrée matériel + niveau).
- **Manuel — choisir un axe** ⭐ : sur le radar, taper un attribut → **« Améliorer cet axe »** → liste de WODs/séances pour cet axe (filtrés matériel + niveau), couplée à l'**Index projeté** (« +X pts si cet axe atteint Y »). Chaque séance réalisée est **notée** → l'axe monte → boucle visible.

### 10.2 Règles de l'algorithme (MVP, à base de règles)
1. Cibler l'attribut au plus grand déficit pondéré.
2. Choisir une séance taguée pour cet attribut, **compatible matériel + niveau**.
3. **Variété** : ne pas répéter le même attribut principal 2 séances d'affilée.
4. **Garde-fou anti-surentraînement** (sans score de fatigue) : si ≥ N séances « dures » sur les Y derniers jours (règle de fréquence simple sur les efforts logués), proposer une séance **légère / skill / mobilité** ou **du repos**.
5. Toujours offrir **« Passer / J'ai fait autre chose »**.

### 10.3 Bibliothèque de séances (contenu)
Chaque séance = `{attributs ciblés, niveau, durée, matériel, mouvements}`. **Taille minimale MVP : ~60 séances** (6 attributs × 2 modes matériel × ~3 niveaux). IA générative en V2 (explications, personnalisation fine).

---

## 11. Les ligues & le classement

### 11.1 MVP : 2 ligues
**Ligue Hommes** + **Ligue Femmes**, **tous les athlètes**, **classées par Hybrid Index**. Pas de poules, pas de saisons, pas de reset.

### 11.2 Anti-démotivation du débutant (sans sous-ligues)
- Mettre en avant **percentile + progression** (« meilleur que 73 % », « +250 places ce mois-ci », « PR ! ») **plutôt que le rang brut**.
- **Système de rival** (ci-dessous) = duel local et atteignable.

### 11.3 Après 200 utilisateurs : classement par box / amis
Sous-ensembles des 2 ligues. La comparaison devient locale (encore plus motivante) et les **box deviennent un canal d'acquisition**.

### 11.4 Logique du rival (spécifiée)
- **Rival = l'athlète actif de ta ligue ayant le plus petit Index strictement supérieur au tien.**
- **« Actif »** = ≥ 1 effort logué dans les 30 derniers jours (cible réelle et battable).
- **Recalcul** : à chaque variation d'Index + une fois/jour.
- **Cas limites :**
  - *N°1 de la ligue* (personne au-dessus) → afficher « Tu es n°1 — défends ta place » + cible **record du monde / pro**.
  - *< 2 athlètes actifs* (tout début) → rival désactivé, fallback sur « battre le pro » + tes propres PR.
  - *Rival inactif/parti* → réassignation au suivant actif.
- **Dépassement** → carte de célébration + nouveau rival + push optionnel au dépassé (« reprends ta place », positif, plafonné).

---

## 12. Système de badges & trophées

Affichés dans une **salle des trophées** (profil public). Catégories :
| Catégorie | Exemples |
|---|---|
| **Progression** | Montées de rang (Bronze→Élite) ; paliers de percentile (top 25/10/5/1 %). |
| **Collection** | Compléter un WOD ; **« Grand Chelem »** (les 15) ; tous les WODs sans matériel / avec matériel. |
| **Performance** | Battre le **pro** sur un WOD ; PR sur un WOD ; sub-X sur le PFT. |
| **Régularité** | Streaks 7 / 30 / 100 jours ; N WODs logués. |
| **Social** | Premier défi envoyé ; battre un ami ; recruter un rival. |

Chaque déblocage = animation + carte partageable. Les badges rares débloquent des cosmétiques d'avatar.

---

## 13. Social & viralité (pour devenir n°1)

- **Tout public** : profils, Hybrid Index, radar, historiques de WODs, PR, badges.
- **Explorer / Feed** : parcourir les athlètes, filtrer (sexe, rang, matériel) ; feed des personnes suivies.
- **Réactions (kudos)** ⭐ : 💪🔥👏 sur les résultats/PR des autres (à la Strava) → connexion sociale + retours. *(Commentaires : Phase 2, avec modération.)*
- **Classements** : 2 ligues (H/F) par Index + **15 classements par WOD** + (post-200) box/amis.
- **Comparaison directe** : **radars superposés** (toi vs n'importe qui).
- **Cartes partageables (moteur d'acquisition n°1)** ⭐ — types : *reveal d'Index*, *PR sur WOD*, *montée de rang*, *palier de percentile*, *« j'ai battu le pro »*, *victoire de défi*. Chaque carte = avatar + Index + badge + visuel léché, prête pour les stories. **À soigner énormément (c'est le K-factor).**
- **Défier un ami** ⭐ — flux complet : *générer un lien défi sur un WOD → l'ami installe/ouvre → réalise le WOD (mode guidé) → carte de résultat tête-à-tête*. **Boucle virale d'invitation.**
- **Recrute ton rival** : inviter quelqu'un explicitement comme rival (gamifie le parrainage).

> Données déclarées pour l'instant ; champ `source` prévu pour la vérification (Phase 3).

---

## 14. Notifications & ré-engagement (cadrées, zéro dark pattern)

| Notification | Déclencheur | Ton |
|---|---|---|
| Rival t'a dépassé | Le rival ou un proche passe devant | « Reprends ta place » (motivant, pas culpabilisant) |
| Tu as dépassé ton rival | Dépassement | Célébration |
| Séance suggérée | 1×/jour max, si pas d'activité loguée | Informative |
| Récap hebdo | 1×/semaine | Positive (progrès de la semaine) |
| Ami actif / PR d'un ami | Action sociale d'un suivi | « Va voir / réagis » |
| Proche d'un rang | Index proche d'un palier | « Encore X pts avant Platine » |
| Défi reçu / résultat de défi | Défi | Neutre/excitant |

**Règles :** plafond global (ex. ≤ 1–2/jour), **toutes configurables**, **jamais** de honte de streak ni de FOMO punitif. Quiet hours par défaut.

---

## 15. Architecture technique & stack

| Brique | Recommandation |
|---|---|
| Mobile (iOS + Android) | **Flutter** (feel « jeu », animations). Alt : React Native. |
| Backend | Node.js (NestJS) ou Go |
| Base de données | PostgreSQL |
| Classements temps réel | Redis (*sorted sets* : 2 ligues H/F + 15 leaderboards de WOD) |
| Cache / sessions | Redis |
| Auth | Email + **Apple** (obligatoire iOS) + Google |
| **Service Score** (Index + notation WOD) | Microservice séparé, **versionné** (recalcul de l'historique quand `f`/poids changent) |
| Bibliothèque WODs + distributions | Référentiel curé + filtre matériel + tags + distributions par sexe |
| **Logging hors-ligne** ⭐ | File locale + synchro différée (salles à mauvais réseau) |
| Génération des cartes de partage | Service de rendu d'images (templates) |
| Notifications push | Firebase Cloud Messaging |
| Analytics produit | PostHog / Amplitude / Mixpanel (funnels, rétention, cohortes) |
| Avatars | Sprites 2D en couches (assets + teintes) |
| Observabilité | Logs + erreurs (Sentry) + métriques |

---

## 16. Modèle de données (entités principales)

- **User** : `id`, `email`, auth, `createdAt`, `consents` (RGPD), `ageVerified`
- **Avatar** : `sex`, `skinTone`, `hairStyle`, `hairColor`, `beardStyle`, `unlockedCosmetics[]`, `equippedCosmetics`
- **Profile** (public) : `displayName`, `goal`, `rank`, `equipmentPreference` (none/equipped/both), `visibility`
- **HybridIndex** : `value`, `percentile`, `isProvisional`, `isEstimated`, `radarCoverage`, `projectedValue`, `confidenceLevel`, `history[]`
- **AttributeScores** : pour chaque attribut (`engine`, `vitesse`, `force`+`isEstimated`, `puissance`, `enduranceMusculaire`, `hybride`) → `score`, `percentile`, `unlocked`, `lastUpdated`, `isStale`
- **Wod** : `name`, `isBenchmark`, `type`, `requiresEquipment`, `targetAttributes[]`, `scoreType` (time/reps/load/distance), `movements[]` (mouvement, reps, charge optionnelle), `referenceDistributionId`
- **ReferenceDistribution** : `wodId`, `sex`, `source` (public/community), `n`, `percentileCurve`, `proReference`
- **WodResult** : `userId`, `wodId`, `result`, `subScore`, `percentile`, `attributesAffected[]`, `source` (declared/verified), `isFlagged`, `timestamp`, `public`
- **League** : **2** (`men`, `women`), classement par `HybridIndex`
- **Rival** : `userId`, `rivalUserId`, `recomputedAt`
- **Challenge** : `fromUser`, `toUser`, `wodId`, `status`, `results[]`
- **Reaction** : `fromUser`, `targetType` (wodResult/badge/rankUp), `targetId`, `emoji`
- **Badge** : `id`, `category`, `condition`, `rarity`, `cosmeticUnlock`
- **UserBadge** : `userId`, `badgeId`, `unlockedAt`
- **Follow** : `followerId`, `followeeId`
- **NotificationPrefs** : par type, on/off + quiet hours

*(Plus de Quest, Season, pools/tiers de ligue.)*

---

## 17. Liste exhaustive des écrans + états (vide / chargement / erreur)

| # | Écran | Rôle | Vide | Chargement | Erreur |
|---|---|---|---|---|---|
| 1 | **Onboarding** | Avatar → objectif → matériel → course/estimation → reveal → benchmarks | — | spinner court entre étapes | « réessaie » sur échec calcul |
| 2 | **Accueil / personnage** | Hub (Index, rival, rang, radar, streak, séance du jour) | Index provisoire + « complète ton Index » | skeleton du hub | bannière hors-ligne + données en cache |
| 3 | **Ajouter un WOD** | Saisie (matériel → biblio/custom → type → reps/charges → résultat) | — | — | validation inline des champs |
| 4 | **Résultat de WOD** | Note + référence pros + conséquences + partage | — | « calcul… » (suspense) | « impossible de calculer, résultat enregistré, score en attente » |
| 5 | **WODs de référence (les 15)** | Liste + statut (fait/à faire) + accès classements | « aucun fait — commence par le Benchmark Zéro » | skeleton liste | retry |
| 6 | **Détail d'un WOD / classement** | Temps de tous (par sexe) + ton rang + écart rival | « sois le premier à le poster ! » | skeleton classement | retry |
| 7 | **Détail de l'Index** | Courbe de progression, percentile, **Index projeté** | « pas encore d'historique » | skeleton graphe | retry |
| 8 | **Détail du radar** | 6 attributs + **« Améliorer cet axe »** → WODs ciblés | attributs verrouillés expliqués | skeleton | retry |
| 9 | **Ligue (H/F)** | Classement par Index + rival mis en avant | « ligue en construction » (si < 2) | skeleton | retry |
| 10 | **Explorer / Feed** | Parcourir/filtrer + feed des suivis | « suis des athlètes pour voir leur activité » | skeleton cartes | retry |
| 11 | **Profil public** (soi + autres) | Avatar, Index, radar, historique, badges | « pas encore de WOD » | skeleton | retry |
| 12 | **Comparaison** | Radars superposés | « choisis un athlète » | skeleton | retry |
| 13 | **Défier un ami** | Créer/voir un défi | « aucun défi en cours » | — | lien invalide → message |
| 14 | **Salle des trophées** | Badges débloqués/à débloquer | « débloque ton premier badge » | skeleton | retry |
| 15 | **Réglages** | Préférence matériel, notifs, confidentialité, compte, **export/suppression données (RGPD)** | — | — | — |
| 16 | **Édition avatar** | Modifier l'apparence + équiper cosmétiques | — | — | — |
| 17 | **Carte de partage** | Générer/partager une carte | — | « génération… » | retry |

---

## 18. Sécurité, vie privée & conformité (à ne pas négliger)

> **Note de chef de produit :** « Tout public » + données liées à la santé/perf + base européenne = un vrai sujet juridique. **À valider avec un juriste** (ceci n'est pas un avis légal).
- **RGPD** : base légale (consentement explicite à la publication publique), droit d'accès/rectification/**suppression**, export des données, registre des traitements, DPO si nécessaire.
- **Âge** : **age-gating** à l'inscription ; politique pour mineurs (un profil public d'un mineur sportif est sensible). Définir un âge minimum.
- **Modération** : signalement de contenu/profil, blocage, masquage ; pas de **localisation précise** publique (ville max).
- **Sécurité** : auth robuste, chiffrement en transit/au repos, limitation de débit, protection anti-scraping des classements.
- **Réversibilité** : pouvoir passer un profil en privé plus tard (le « tout public » verrouillé est un défaut produit, pas une impossibilité technique — prévoir le champ `visibility`).

---

## 19. Roadmap

### Phase 0 — Calibration & contenu (en parallèle, avant/pendant MVP)
Construire les **distributions par sexe** (bootstrap données publiques) pour les 15 WODs ; rédiger la **bibliothèque de ~60 séances** ; définir la courbe `f`.

### Phase 1 — MVP « thin slice » (≈ 3–4 mois) — recentré
**Le minimum pour prouver la rétention :** onboarding (avatar + matériel + course/estimation + reveal) · **Benchmark Zéro + PFT** (mode guidé) · **notation des 15 WODs** (bodyweight géré) · radar + Index (Force en proxy, confiance affichée) · **ciblage d'axe + Index projeté** · **2 ligues H/F + rival** · profils publics + Explorer · **cartes partageables** · **logging hors-ligne** · réglages RGPD de base.
> *Coupes assumées du MVP :* WODs custom, kudos, défis, badges complets → repoussés en Phase 2 si le temps manque. Mieux vaut une thin slice excellente.
**Objectif :** 50–100 vrais utilisateurs (1 box pilote + 1 groupe « sans matériel »), **rétention J7 mesurable**.

### Phase 2 — Boucle complète & viralité (≈ 3 mois)
WODs custom (estimation) · **défier un ami** · **kudos** · **badges & trophées** · **classement box/amis (>200 users)** · récap hebdo + notifs intelligentes · reco auto affinée.
**Objectif :** rétention **J30 > 30 %**, **K-factor > 0,5**.

### Phase 3 — Échelle & confiance (6 mois+)
**Vérification** (montres : Apple/Garmin/COROS ; résultats HYROX officiels) · coach **IA** conversationnel · endgame mondial enrichi · scoring CrossFit approfondi · partenariats box · **modèle économique**.

---

## 20. Risques & angles morts (honnête)

| Risque | Gravité | Mitigation |
|---|---|---|
| **Données déclarées → triche** (classements par WOD = forte incitation) | Élevée | Bornes physio + détection d'anomalie + exclusion des classements ; vérification en Phase 3. Le classement n'est « crédible » qu'après vérification. |
| **Cold-start des percentiles** (« meilleur que X % » fictif au début) | Élevée | Bootstrap données publiques + **indicateur de confiance** ; recalcul communautaire dès n suffisant. |
| **RGPD / mineurs / « tout public »** | Élevée | Section §18 ; juriste ; age-gating ; modération ; champ `visibility` prévu. |
| **Endgame faible → churn des experts** | Moyenne | §4.4 (Grand Chelem, top-100, % record, ambassadeurs). |
| **MVP sur-dimensionné** | Moyenne | « Thin slice » §19 ; coupes assumées. |
| **Pas de modèle économique** (coûts d'infra ↑ avec users) | Moyenne | Compatible « gratuit pour l'instant » ; piste premium/box en Phase 3. |
| **Force sans matériel = proxy** | Faible | Proxy bodyweight + `isEstimated`. |
| **Cold-start social** | Moyenne | Box pilote + groupes « sans matériel » ; cartes partageables dès J1. |
| **Surentraînement / engagement malsain** | Moyenne | Streak sain + garde-fou anti-surentraînement dans la reco ; notifs non culpabilisantes. |

---

## 21. Métriques de succès

- **North star (engagement)** : athlètes actifs hebdo ayant logué **≥ 1 WOD noté**.
- **Mission (progression)** : médiane d'amélioration du **Hybrid Index / utilisateur actif / mois**.
- **Acquisition (viralité)** : taux de partage des cartes + **K-factor** (défis/parrainages → inscriptions).
- **Activation** : % complétant l'onboarding (> 80 %) ; **% atteignant l'Index complet (~3 efforts)**.
- **Rétention** : J1 / J7 / **J30** (juge de paix) ; courbes de cohortes.
- **Profondeur** : WODs/utilisateur/semaine ; **% utilisant le ciblage d'axe** ; **% dépassant leur rival/mois** ; % ayant débloqué les 6 attributs.
- **Garde-fous (à surveiller)** : taux de résultats flaggés (triche) ; % d'utilisateurs en surfréquence (santé) ; opt-out de notifications.

---

## 22. Glossaire

- **Hybrid Index** : score global 0–1000, normalisé par sexe. Nom de l'app **et** du score.
- **Radar** : les 6 attributs détaillés (Engine, Vitesse, Force, Puissance, Endurance musc., Hybride).
- **WOD** : « Workout of the Day », un entraînement. *For Time* = chronométré. *AMRAP* = max de tours en temps donné. *EMOM* = à la minute.
- **PFT** : Physical Fitness Test HYROX, benchmark hybride standardisé.
- **Benchmark Zéro** : test signature sans matériel (1 km · 30 pompes · 30 squats · 1 km).
- **Rival** : l'athlète actif juste au-dessus de toi dans ta ligue.
- **Index projeté** : Index simulé si un attribut atteignait un niveau cible.
- **Pro reference** : niveau élite estimé sur un WOD, cible à atteindre.

---

*HYBRID INDEX — v6 (réécriture qualité AAA). Document de travail à faire évoluer.*
