# Estimation « pro » — ce qui a été LIVRÉ

> Compagnon d'implémentation de [`plan-estimation-pro.md`](./plan-estimation-pro.md) (la SPEC).
> Ce fichier décrit l'état RÉEL du code après livraison des incréments 0 → 4.
> Date : 2026-06-30.
>
> **GARDE-FOU CENTRAL (non négociable)** : l'ESTIMATION est SÉPARÉE de la NOTATION. Aucune ligne de
> `computeIndex`, `scoreResult`, `subScoreFromPercentile`, ni des distributions `bySex.model`
> utilisées pour NOTER un vrai résultat n'a changé. Les 15 benchmarks restent la référence de
> notation. Seul le chemin de PRÉDICTION de temps a évolué.

---

## Incréments livrés

### Inc. 0 — Affichage (mobile) — *livré*
- `wod_detail_screen.dart` : `_predictionCard()` se masque (`SizedBox.shrink`) dès qu'un vrai
  résultat existe (`myBestRaw != null`). À la place, le bloc « Toi » porte une ligne comparative
  « ton temps vs estimation niveau » gardée par un seuil d'écart (> 8 %, fonction pure
  `wodBeatsEstimate`, `wod_format.dart`). Sinon (`myBestRaw == null`) : carte « Temps estimé pour
  toi ».

### Inc. 1 — Moteur extrait + blueprints — *livré*
- `apps/score-service/src/score/wod-time-engine.ts` : mécanique de temps PAR MOUVEMENT extraite
  (cadence × charge × fatigue × coupures × transitions × dégradation inter-tours). Mode `level`
  iso-comportement (création de WOD custom inchangée).
- `apps/score-service/src/wods/wod-blueprints.data.ts` : décomposition canonique des benchmarks
  décomposables en `blocks` typés (`movementId` + reps numériques par tour + `loadKg` par sexe).

### Inc. 2 — Capacité par mouvement + pénalité de charge — *livré*
- Mode `athlete` du moteur : capacité spécifique par mouvement via `movement.attributes` pondérés
  (B.2) → la FORCE entre AUTOMATIQUEMENT sur les mouvements chargés, même hors `targetAttributes`.
- Pénalité de charge relative `loadMult(x)`, `x = loadKg / 1RM_estimé(force)` (B.3) +
  `effectiveMaxSet` (plus de coupures sous charge lourde). C'est le correctif « 40 kg trop lourd ».
- `predictResult` (`scoring.service.ts`) : blueprint → moteur mode athlète → estimation, **bornée**
  par la distribution population (garde-fou `[hardMin, hardMax]` ∩ `[q01, q99]`). La distribution
  ne GÉNÈRE plus l'estimation ; elle la BORNE.
- WODs SANS blueprint (course pure, max-reps, 1RM) → **repli population** historique conservé.

### Inc. 3 — Fourchette + contrat de bout en bout — *livré (cette tâche)*
Contrat `{ low, mid, high } + confidence` propagé de la source jusqu'à l'écran :

| Couche | Élément | Détail |
|---|---|---|
| **contracts** | `PredictResultResponse` (`packages/contracts/src/internal/score.ts`) | + `predictedLow?`, `predictedHigh?` (int nullable), `confidence?: "low"\|"medium"\|"high"`. `predictedRaw` reste le **mid** (rétro-compat aller-retour). Champs OPTIONNELS → absents = pas de fourchette. |
| **score-service** | `wod-time-engine.ts` | `predictionConfidence(coverage, chargedBlocks)`, `SPREAD_BY_CONFIDENCE` (high ±8 % / medium ±14 % / low ±22 %), `blueprintCoverage(blocks, unlockedAttrs)`. |
| **score-service** | `predictResult()` (`scoring.service.ts`) | branche blueprint : calcule couverture (attributs débloqués) + nb de blocs chargés → confiance → `low/high = clamp(mid·(1∓spread), bornes)`. Repli population : renvoie le **point seul** (pas de fourchette). |
| **api** | `wods.service.prediction()` + score-client | passe-plat : la réponse du score-service (validée par zod du contrat étendu) remonte telle quelle ; aucun DTO ne filtre les nouveaux champs. |
| **mobile** | `WodPrediction` (`models.dart`) | + `predictedLow`, `predictedHigh`, `confidence`, getter `hasRange`. |
| **mobile** | `_predictionCard()` (`wod_detail_screen.dart`) | affiche `« ~9:00 - 11:00 »` quand `hasRange`, sinon **fallback** sur le point `« ~X »`. Libellé de confiance sous la fourchette. Toujours masqué si `myBestRaw != null` (Inc. 0). |
| **i18n** | `app_fr.arb` / `app_en.arb` (+3 générés) | `wodPredictionConfidenceHigh/Medium/Low`. |

**Sémantique des bornes** : pour un `time` (dir −1), `low` = temps OPTIMISTE (plus rapide),
`high` = pessimiste. Pour `reps`/`load`/`distance`, `low` < `high` (moins → plus). L'affichage
`low - high` lit naturellement dans les deux cas.

### Inc. 4 — Doc + dépréciation — *livré (cette tâche)*
- Ce document.
- `wod.types.ts` : `targetAttributes` documenté comme **AFFICHAGE / RADAR / MAPPING COACH +
  repli population uniquement** — PLUS le déterminant de la prédiction des benchmarks décomposables.

---

## `targetAttributes` — statut après dépréciation

`targetAttributes` n'est PLUS la source de la prédiction des benchmarks décomposables. Usages
LÉGITIMES restants (à NE PAS retirer) :
1. **Affichage / radar** : `scoring.service.ts` (`attributesAffected`, `tags` du reveal), API
   (`detail`, sérialisation).
2. **Mapping attribut → WOD du coach** : `wods.service.ts` (recommandation de séances ciblant un
   attribut faible).
3. **Repli population de `predictResult`** : pour les WODs SANS blueprint (course pure, max-reps,
   1RM), où la décomposition mouvement-par-mouvement n'existe pas, on garde la prédiction
   historique (moyenne des sous-scores cibles débloqués → percentile → quantile du modèle).

> Garde-fou : ne JAMAIS réintroduire `targetAttributes` comme déterminant principal de la
> prédiction d'un benchmark décomposable (régression de l'ancien bug « force ignorée », facteur ×2
> sur le temps de Fran).

---

## Vérification

```
cd apps/score-service ; npx jest                    # 115 tests verts (golden + predict + scoring)
cd apps/api           ; npx tsc --noEmit ; npx jest --runInBand   # tsc OK, 296 tests verts
cd apps/mobile        ; flutter analyze ; flutter test            # 0 erreur (2 infos pré-existantes), 65 tests verts
```

Tests notables :
- `score-service/test/predict.e2e.spec.ts` : fourchette `low ≤ mid ≤ high` + confiance sur Fran ;
  repli population (course) → point seul sans fourchette.
- `score-service/test/estimate.golden.spec.ts` : golden tests des 4 profils (élite / régulier /
  soso 9-11 min / débutant) — figés, toute régression future casse AVANT l'utilisateur.
- `mobile/test/wod_prediction_range_test.dart` : parsing `{low,mid,high}+confidence` + fallback
  point seul (`hasRange`).
