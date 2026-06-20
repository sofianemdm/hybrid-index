# HYBRID INDEX — Journal des décisions arbitrées

> Source d'autorité pour les arbitrages tranchés par l'humain qui complètent ou précisent
> le cahier des charges. À respecter lors de l'implémentation. Ne contredit jamais les
> « Décisions verrouillées » du cahier ; les précise.

---

## 2026-06-19 — Arbitrages post-specs fondatrices

### D1 — Périmètre & ordre du MVP « thin slice » (Phase 1)
Tranche verticale d'abord (logguer → noter → reveal de bout en bout), puis élargissement au
social. Découpage en 9 incréments livrables et testables (0→8). Voir `mvp-plan-phase1.md`.
Coupes assumées (Phase 2) : WODs custom, kudos, défis, badges complets.

### D2 — Attribut Force : le test chargé fait autorité (résout B2/B3)
Quand un athlète possède **à la fois** un test de Force chargé réel (Grace, Jackie…) **et** un
proxy bodyweight (max pompes), l'attribut **Force** est calculé ainsi :
- Le **test chargé réel fait autorité**. Le proxy pompes **ne peut jamais surclasser** un test
  chargé réel (proxy plafonné au niveau du test réel, ou ignoré pour `force` dès qu'un test
  chargé existe).
- `isEstimated = true` **si et seulement si** la **valeur numérique retenue** provient d'un
  effort proxy/estimé — indépendamment de l'existence d'autres tests.
- **Impact :** corrige la règle « max brut » de `sport-science-scoring.md §5.3` et l'incohérence
  `isEstimated` entre les worked examples A/B. À implémenter dans `scoring-v1` **avant** d'écrire
  les tests du Service Score (incrément 1), pour ne pas entériner le bug.

### D3 — Péremption 26 semaines : no-drop absolu (résout I1)
Quand le meilleur effort d'un attribut sort de la fenêtre de fraîcheur (26 sem.) sans re-test :
- On **conserve la dernière valeur connue** jusqu'à remplacement par un meilleur effort.
- Hors fenêtre, on marque uniquement `isStale = true` (indicateur « à rafraîchir »).
- **Le score ne baisse JAMAIS** automatiquement. La fenêtre de fraîcheur ne sert qu'à
  l'indicateur `isStale` et à l'invitation douce au re-test, pas à une décroissance.
- **Impact :** lève la contradiction entre `architecture.md §A1` (décroissance par péremption) et
  `sport-science-scoring.md §5.2`. La lecture **sport-science (no-drop absolu)** prévaut.

### D4 — Âge minimum 13 ans + mineurs « tout public »
- Âge minimum à l'inscription : **13 ans** (age-gating).
- L'onboarding **doit collecter date de naissance + consentement explicite à la publication
  publique** avant la création du profil/le reveal (corrige l'absence signalée dans
  `design-system.md` ; le modèle de données le prévoit déjà : `app.user.date_of_birth` CHECK ≥ 13,
  `consents` jsonb).
- Les profils de mineurs (13-17 ans) sont **publics comme les autres** (application stricte de la
  décision verrouillée « tout public »).
- ⚠️ **Réserve légale (non tranchée techniquement) :** la publication de profils de mineurs
  sportifs reste juridiquement sensible (RGPD §18). **À faire valider par un juriste avant le
  lancement public.** Le champ `visibility` reste disponible pour durcir la politique si besoin.

### D5 — Bibliothèque de séances de reco : ~60 dès le MVP
La bibliothèque complète (~60 séances = 6 attributs × 2 modes matériel × ~3 niveaux) est un
livrable de l'incrément 4, à rédiger par `sport-science`. Chaque séance :
`{attributs ciblés, niveau, durée, matériel, mouvements}`.

### D6 — Entité `Streak` à ajouter au schéma (MVP)
`gamification.md §10` exige une entité `Streak` (current, best, weeklyGoal, freezeTokens,
freezeTokensRefreshedAt, plannedRest, lastWeekEvaluated) absente de `architecture.md §3`. Le
streak étant **MVP** (incrément 8), ajouter la table `app.streak` (+ préciser
`notification_prefs.dailyCap` / `lastSentAt` par type) lors de l'incrément concerné.

---

### D7 — Vocabulaire des enums : anglais (snake_case)
Les identifiants techniques des enums métier sont en **anglais snake_case**, source de vérité dans
`packages/contracts` et alignés sur `architecture.md §3.1` (→ OpenAPI → client Dart → enums Postgres) :
- `AttributeKey` : `engine, speed, strength, power, muscular_endurance, hybrid`
- `WodType` : `for_time, amrap, emom, chipper, strength, interval`
- `Goal` : `hyrox, crossfit_strength, all_round`
- `Rank` : `rookie, bronze, silver, gold, platinum, diamond, elite` (libellés FR Rookie/Bronze/Argent/Or/Platine/Diamant/Élite via i18n)
- (`ScoreType, Sex, EquipmentPref, Visibility, ResultSource, DistributionSource` déjà neutres.)
Les **libellés utilisateur restent en français** via i18n. Les docs `sport-science-scoring.md` /
`gamification.md` peuvent garder les termes FR en prose ; la correspondance FR↔clé est documentée
dans `packages/contracts/src/enums/index.ts`. *(Résout l'alerte I1 de la revue de l'incrément 0.)*

### D8 — Erratum table §4.3 (courbe f) : la formule fait foi
La table illustrative §4.3 de `sport-science-scoring.md` contenait des valeurs erronées
(P=0.10→22 au lieu de 30 ; 0.25→115 au lieu de 118 ; 0.90→969 au lieu de 949 ; etc.). La **formule**
`f(P)` (sigmoid-v1) est la source de vérité (déterministe, versionnée) ; le worked example A l'applique
correctement. Table corrigée + implémentation `@hybrid-index/scoring-core` testée sur les valeurs exactes.
*(Découvert en codant l'incrément 1.)*

### D9 — Un test chargé réel fait autorité même périmé (précise D2 + D3)
Cas limite : seul test de Force chargé (Grace) **hors fenêtre 26 sem** + proxy pompes **frais**.
Décision : la **mesure réelle fait autorité même périmée** — le proxy ne peut jamais la surclasser
(D2). On conserve la valeur réelle (no-drop, D3) et on marque `isStale` (invitation au re-test).
On ne retombe sur une estimation que s'il n'existe **aucune** mesure réelle. Implémenté dans
`scoring-core/attribute.ts` + testé. **Seuil `isStale` (M4)** : la spec dit « ~8–12 sem » ; on retient
**10 semaines** (`STALE_WEEKS`).

### D10 — Onboarding « reveal » : périmètre thin-slice
Le calcul du reveal (`POST /v1/onboarding/estimate`) est implémenté **sans persistance** (calcul pur
api → score-service) pour garantir le « waouh < 60 s ». Réductions assumées vs cahier §8, à compléter :
- **5bis** : on capte `estimatedPushups` (+ `course` optionnelle). « Niveau de course estimé » et
  « expérience » (les 2 autres taps du 5bis) ne sont **pas encore** dans `OnboardingEstimateRequest`.
- **Course** : seuls `run_1k`/`run_5k` existent au registre ; **`run_10k` à ajouter** (le cahier §8
  évoque 1/5/10 km).
- La **création de compte** (User/Profile/Avatar + age-gating 13 + consentement) reste à faire
  (incrément 2 suite, nécessite Postgres).

---

### Points importants encore ouverts (non bloquants — à trancher avant lancement public)
- **Streak — wording :** mécanique hebdomadaire vs libellés badges « 7/30/100 jours » (decision designer/produit).
- **No-drop dur au recalcul de version (`f`/poids) :** `max(ancien, nouveau)` peut figer des Index
  surévalués ; stratégie ramp/lissage + communication à arrêter avant le 1ᵉʳ recompute en prod.
- **`sex` verrouillé après onboarding :** interdiction stricte ou recalcul complet ? (sensible).
- **Indicateur de confiance obligatoire** sur les 3 WODs à données estimées (Benchmark Zéro,
  burpees 7 min, air squats 2 min) — dont le benchmark signature sans matériel.

---

## Nuit du 19→20 juin 2026 — boucle complète persistée + app Flutter Web

### D11 — Auth MVP : email + mot de passe + JWT (OAuth différé)
La stack verrouillée prévoit email **+ Apple + Google**. Apple/Google exigent des identifiants
externes (client IDs, clés) impossibles à configurer en autonomie. On implémente donc **email +
mot de passe (bcrypt) + JWT** — déjà dans la stack, donc **additif et non contradictoire**. OAuth à
brancher avec l'humain. `JWT_SECRET` **obligatoire en production** (refus de démarrer avec le secret
de dev). Age-gating 13+ (D4) appliqué à l'inscription.

### D12 — Classement via Redis sorted sets, Postgres source de vérité
Conforme à la décision verrouillée « classements via sorted sets ». Le rang/position passe par un
**ZSET Redis** (`leaderboard:{sex}`), avec **repli Postgres** si Redis indisponible. La détermination
de l'**athlète au-dessus (rival)** est faite **via Postgres** (jointure profil = uniquement de vrais
comptes) pour éviter toute divergence Redis/Postgres (entrée orpheline → référence vers compte
supprimé). Resync Redis←Postgres disponible en script.

### D13 — Persistance de score : autorité = score-service, recalcul no-drop côté API interdit
L'`api` ne recalcule **jamais** un score à la main : à chaque log de WOD, elle renvoie **tous** les
efforts persistés au score-service (`computeProfile`) qui applique le no-drop (D3). L'`api` ne fait
que **persister** le résultat (`HybridIndex` + `AttributeScore`, version `scoring-v1` = UUID seedé).
**Limite connue** : le contrat radar ne porte pas encore de percentile par attribut → stocké comme
approximation `score/1000` (au lieu de 0), à remplacer quand le contrat l'exposera.

### D15 — Course à distance libre : normalisation Riegel
L'utilisateur saisit n'importe quelle distance + son temps. Le score-service normalise via la
formule de Riegel (exposant **1.06**) vers un équivalent 5 km, puis score `engine` (sport-science
20 juin). Plage 400 m–42,2 km ; bornes anti-triche par **allure** (156/171 s·km⁻¹ plancher,
720 plafond) ; tag `speed` ajouté si ≤ 1 km. La distance est persistée (`wod_result.distance_meters`).
Ajout aussi de `max_air_squats` (une série, à l'échec). Objectifs : HYROX / CrossFit / Condition
physique. Matériel : Sans / Équipé (Équipé ⊇ Sans).

### D16 — Index projeté (Coach) : simulation via la fonction officielle
La projection d'Index réutilise `hybridIndex` (autorité, versionnée), en simulant la montée de
l'attribut ciblé à `min(1000, max(meilleur attribut, score+100))`. Jamais de recalcul parallèle,
jamais décroissant. 54 séances mappées aux 6 attributs (sport-science), filtrées par matériel.

### D17 — Engagement : streak hebdo + badges + notifications
Streak ISO-hebdo (semaine validée ≥ weeklyGoal=3, jetons de gel anti double-protection, régen
+1/4 sem actives, repos planifié) ; 18 badges (conditions évaluées serveur ; **Top X% attribués
seulement si ligue ≥ 100 users** pour rester crédibles) ; 10 déclencheurs de notification (envoi
**push FCM différé** — credentials externes). RGPD : export (sans hash) + suppression (cascade +
retrait Redis). 2 champs Streak ajoutés (`last_outcome`, `validated_active_weeks`).

### D18 — Avatar vectoriel (sans assets)
Faute d'assets sprites, l'avatar est **dessiné en CustomPaint** (peau/cheveux/barbe paramétrables
+ cadre de rang). Indices persistés dans `Avatar`. Les cosmétiques débloqués par badges existent
en données (`cosmeticUnlock`) mais ne sont pas encore équipables (à brancher avec contrôle d'équité).

### D14 — Démo navigateur : app Flutter lancée en Web
Pour être **essayable demain matin sans téléphone/émulateur**, l'app Flutter est lancée en **Web**
(`flutter run -d chrome`). C'est **le vrai code produit** (base unique iOS+Android) ; le Web est une
cible de démo. Écrans livrés : auth, onboarding (aperçu live), révélation animée, accueil (Index +
radar + rival), classement H/F, log WOD. CORS activé côté api (obligatoire pour le navigateur).

## 2026-06-20 — Pivot « preuve sociale honnête » (incréments G1→G6)

### D19 — Suppression du rival et des défis, remplacés par une preuve sociale à deux populations
**Contexte.** Le fondateur juge le rival et les défis trop lourds / pas alignés avec l'esprit voulu,
et préfère un ressort motivationnel **honnête et toujours valorisant**.

**Décision (supersède la mention « système de rival » de la constitution et les sections rival/défis
du cahier).**
- **Retirés** : feature *rival* (modèle `Rival`, endpoint `/v1/me/rival`, carte d'accueil, notifs +
  badge `rival-slayer`) et *défis* (module `challenges`, modèle `Challenge`, écran, events feed).
  Migration `remove_challenges_rival`. La logique de **position au classement est conservée** (sert
  aux notifs de dépassement).
- **Ajouté** : **preuve sociale à deux populations**, jamais mélangées.
  - **Population générale (« humanité »)** : nouveau moteur `popnorm-v1`
    (`packages/scoring-core/src/population-norms.ts`, sources dans
    `docs/population-norms-sources.md`). Fondé sur des **normes publiées** (ACSM/Cooper, OMS,
    APFT/ACSM, ExRx/NSCA, RunRepeat). Confiance **assumée `estimate`**, étiquetée « estimé », jamais
    de décimale sous 1 %. **Toujours affichée** ; sous la médiane → message de progression.
  - **Population app** : affichée **uniquement si top 30 % ET ligue ≥ 200** (cohérent avec la décision
    verrouillée « box/amis après 200 users »). Sinon **masquée** — on n'affiche jamais un mauvais rang.
- **Notifications in-app** (le push FCM reste différé) remplaçant le ressort compétitif du rival :
  `rank-overtaken` (snapshot de position auto-acquitté à la lecture) et `wod-overtaken` (athlète
  **suivi** qui bat mon effort, fenêtre « depuis ma dernière séance »). Regroupées, plafonnées, ton
  motivant jamais culpabilisant.
- **Honnêteté** : le mobile ne reçoit/affiche que des **bandes arrondies** (top 1/2/5/10/20/30/50 %),
  jamais le percentile brut. Célébration uniquement à la **montée** de bande, jamais à la descente.

**Dette tracée (revue G6, non bloquante)** : `wod-overtaken` peut se réafficher entre deux séances
(fenêtre temporelle, pas d'acquittement par-vue dédié) ; `bandImproved` non couvert par test unitaire
dédié (extraire + tester). `attribute_score.percentile = score/1000` reste un placeholder assumé.
