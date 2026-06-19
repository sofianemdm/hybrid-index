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

---

### Points importants encore ouverts (non bloquants — à trancher avant lancement public)
- **Streak — wording :** mécanique hebdomadaire vs libellés badges « 7/30/100 jours » (decision designer/produit).
- **No-drop dur au recalcul de version (`f`/poids) :** `max(ancien, nouveau)` peut figer des Index
  surévalués ; stratégie ramp/lissage + communication à arrêter avant le 1ᵉʳ recompute en prod.
- **`sex` verrouillé après onboarding :** interdiction stricte ou recalcul complet ? (sensible).
- **Indicateur de confiance obligatoire** sur les 3 WODs à données estimées (Benchmark Zéro,
  burpees 7 min, air squats 2 min) — dont le benchmark signature sans matériel.
