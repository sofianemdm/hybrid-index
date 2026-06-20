# HYBRID INDEX — Plan MVP « thin slice » (Phase 1)

> Plan validé par l'humain (2026-06-19). Principe : **tranche verticale d'abord**
> (incréments 1→3 : *logguer → noter → reveal* de bout en bout), puis élargissement au social
> (4→8). Chaque incrément est livrable, testable, et passe par `reviewer` avant d'être « Terminé »
> (cf. Definition of Done dans `CLAUDE.md`). Décisions transverses : `decisions-log.md`.
> Coupes assumées (Phase 2) : WODs custom, kudos, défis, badges complets.

## Vue d'ensemble des incréments

| # | Incrément | Statut | Critère de test |
|---|---|---|---|
| 0 | Fondations monorepo | ✅ **Terminé** (revu) | build + typecheck + test verts, CI présente |
| 1 | Service Score (isolé, testé à fond) | ✅ **Terminé** (revu, 75 tests) | worked examples A/B reproduits, D2/D3, bornes, provisoire |
| 2 | Auth + onboarding + REVEAL | ✅ **Terminé & persisté** (revu) — auth email+JWT, age-gate D4, onboarding/complete persiste Index+radar ; app Flutter Web | e2e : inscrit → Index révélé persisté ; age-gate 403 (tests verts) |
| 3 | Notation d'un WOD + conséquences | ✅ **Terminé** (revu) — POST /v1/results → recalcul no-drop persisté, idempotence (idempotencyKey) ; bornes 422. Reste : sync offline (Drift) | e2e : log WOD → Index/radar bougent ; idempotent (test vert) |
| 4 | Radar + détail Index + ciblage d'axe (+ séances) | ✅ **Terminé** (revu) — Coach : ciblage d'axe → Index projeté (autorité score-service) + 54 séances filtrées matériel ; écran Coach | cibler un axe → Index projeté ≥ actuel (tests verts) |
| 5 | Ligues H/F + Rival | ✅ **Terminé** (revu) — classement H/F (Redis ZSET + repli PG), rival via PG, seed 80 athlètes, écran classement | classement trié + rival cohérent (tests verts) |
| 6 | Profils publics + Explorer + Comparaison | ✅ **Terminé** (revu) — GET /v1/profiles/:id public, écran profil + comparaison ; classement cliquable | voir profil/radar d'un autre athlète (test vert) |
| 7 | Cartes partageables (K-factor) | ✅ **Terminé** — carte visuelle capturée en PNG, téléchargement Web | générer/exporter l'image de sa carte |
| 8 | Réglages RGPD + notifs + streak | ✅ **Terminé** (revu) — streak hebdo + 18 badges + RGPD (export/suppression) + prefs notifs (push FCM différé) | export/suppression ; streak hebdo ; badges (tests verts) |
| + | Paramètres & Avatar évolutif | ✅ **Terminé** — PATCH profil (objectif→recalcul), éditeur d'avatar vectoriel + cadre de rang | modifier profil ; personnaliser l'avatar (tests verts) |

## État de l'incrément 0 (livré)
Monorepo pnpm/turbo · `packages/contracts` (enums Zod anglais, `rankFromIndex` testé 7/7) ·
`apps/api` NestJS (`/health`) · `apps/score-service` NestJS versionné (`/v1/score/health|version`,
`scoring-v1`) qui bootent et sont testés · scaffold Flutter (non compilé : SDK absent) ·
`docker-compose` + Dockerfiles + CI GitHub Actions. Revue `reviewer` passée (B1, I1, I2 corrigés).

Dette identifiée à traiter tôt : **I3** (codes d'erreur à aligner sur `architecture.md §4.1`,
avant sérialisation d'erreurs en inc. 2-3), **I4** (brancher ESLint réel ; aujourd'hui `lint` = stub).

---

## Incrément 1 — Service Score (le cœur) : sous-découpage

> La justesse du HYBRID INDEX est **non négociable** (CLAUDE.md règle 4). On code la logique de
> score conformément à `sport-science-scoring.md` et aux décisions **D2** (test chargé fait autorité
> sur le proxy Force), **D3** (no-drop absolu + `isStale`), versionnage **scoring-v1**.

1. **`packages/scoring-core`** (logique pure, sans infra — testable en isolation = exigence DoD) :
   - `percentile(R, distribution, scoreType)` : log-normale / normale tronquée / table de points,
     gestion du sens (temps↓ vs reps/charge/distance↑), clamp `[0.001, 0.999]`.
   - `curveF(P)` = `sigmoid-v1` (k=6, P0=0.55, renormalisée) → sous-score `[0,1000]`.
   - `subScore(R, ...)` = `curveF(percentile(...))`.
   - **Tests** : table P→sous-score de `sport-science §4/§8` (médiane P=0.5 → ~433), monotonie,
     bornes, NaN, par sexe.
2. **Agrégation attribut & Index** (toujours dans `scoring-core`) :
   - `attributeScore` = max des sous-scores sur fenêtre 26 sem (**no-drop** D3), `unlocked`,
     `isStale`, **règle proxy Force D2** (test chargé prioritaire, `isEstimated` = source retenue).
   - `hybridIndex(attributeScores, goal)` = moyenne pondérée (3 jeux de poids numériques),
     `isProvisional` (≥4/6 OU règle des 3 efforts), `percentile` via N(450,140), `radarCoverage`.
   - `projectedIndex(attr, target)`.
   - **Tests** : **worked examples A (→499 OR) & B (→775 DIAMANT)** reproduits exactement ;
     D2 (proxy plafonné) ; D3 (ajout d'un effort moins bon ne baisse rien) ; provisoire ; bornes physio.
3. **`score-service` expose le contrat interne** `/v1/score/*` (`ComputeSubScore`, `ComputeIndex`,
   `version`) en s'appuyant sur `scoring-core` ; chaque réponse porte `scoringVersionId`.
   Distributions de référence seedées depuis `sport-science-scoring.md` / `reference-data-sources.md`.
   - **Tests e2e** : endpoints renvoient des valeurs cohérentes avec les worked examples.
4. **Registre de versions & recompute** (squelette) : `ScoringVersion` (draft/active/superseded),
   no-drop dur au recalcul (à documenter, cf. point ouvert I3 du log). Recompute complet = itération
   ultérieure ; ici on pose l'API et le portage de `scoringVersionId`.

**Definition of Done inc. 1** : couverture élevée de la chaîne de score, worked examples verts,
revue `reviewer` sans alerte bloquante, aucun secret en dur.
