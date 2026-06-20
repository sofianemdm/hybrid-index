# Plan d'implémentation — WOD Engine & Communauté (synthèse des 4 experts)

Source : `docs/spec-wod-engine-communaute.md` + specs sport-science / architecte / ui-ux / gamification (20 juin).

## Décisions arbitrées (verrouillées pour cette extension)
- **DW1** — Les **WODs custom comptent dans l'HYBRID INDEX** à **confiance réduite** (`estimated`)
  jusqu'à calibration communautaire (N≥30/sexe), avec **plafonnement de percentile** tant qu'estimé
  (paramètre `scoringVersion.fParams`). No-drop préservé. *(lève le report « Phase 2 »)*
- **DW2** — Bibliothèque **`Movement` dans le schéma `scoring.*`** (autorité score-service) ;
  l'`api` n'en expose qu'une projection `MovementSummary` (jamais les débits/poids internes).
- **DW3** — `Wod.id` : slug fixe conservé pour les 15 officiels (seed), **`cuid()` par défaut** pour
  les WODs communautaires. Un custom = un `Wod` (`isCustom`, `source=community`, `createdById`).
- **DW4 (Rx/Scaled)** — Le créateur fixe les **charges Rx par sexe**. À l'exécution : `WodResult`
  stocke les **charges utilisées** + un flag **`rxCompliant`**. Le **leaderboard par WOD est scindé
  Rx / Scaled** (et par sexe) ; un scaled est noté honnêtement mais n'apparaît pas au classement Rx.
- **DW5** — Leaderboard par WOD via **sorted sets Redis** `lb:wod:{wodId}:{sex}:{rx|scaled}` (TTL sur
  community peu actifs) + **repli Postgres** (index partiel `WHERE review='ok'`).
- **DW6** — Le **réseau social (feed, kudos, défis) entre au périmètre** (incréments E/F) — c'est la
  demande produit. Réactions 100 % positives, pas de classement de popularité, garde-fous santé.
- **DW7** — Navigation cible **5 onglets + FAB central** : Accueil · WOD · (➕ Ajouter) · Communauté ·
  Classement. « Progrès » accessible depuis l'Accueil. Le builder = flow modal du FAB (segments
  Référence / Communauté / Construire), pas un 6e onglet.

## Données expertes à intégrer (vivent dans le code)
- **Records / 3 paliers (champion/intermédiaire/occasionnel) par sexe** des 15 WODs → score-service.
- **Bibliothèque ~36 mouvements** (débits par niveau/sexe, tags d'attributs, exposant de fatigue,
  bornes physio) → `scoring.movement` (seed).
- **Moteur d'estimation** (coût/mouvement × charge × fatigue × format → `pointTable` synthétique →
  courbe f existante) → score-service.
- **8 badges sociaux + 6 déclencheurs de notif** → données engagement.

## Incréments (thin slice, build/test/commit/revue chacun)
- **A — Records & leaderboard par WOD** : paliers des 15 WODs (score-service) ; onglet WOD (catalogue
  + fiche) ; `GET /v1/wods`, `/v1/wods/:id`, `/v1/wods/:id/leaderboard` (Postgres, Redis optionnel).
  *Pas de migration.*
- **B — Bibliothèque mouvements + moteur d'estimation** : `scoring.movement` + seed + `POST
  /v1/score/estimate` + contrats + `/movements` + `/wods/:id/estimate`. Critère d'acceptation :
  reproduire les médianes des 15 WODs à ±8 %.
- **C — Builder + WODs communautaires** : évolutions `Wod` (custom/community, Rx, format, blocs) +
  `POST/PATCH/DELETE /wods` + builder Flutter + Rx/Scaled.
- **D — Calibration communautaire** : `resultCount` + job bascule `estimated→community` + nouvelle
  `scoringVersion`/distribution + recompute.
- **E — Communauté (feed & kudos)** : `FeedEvent` + `Reaction` + `/feed` + follow + émission d'events.
- **F — Recherche + comparaison + défis** : `/explore`, `/compare`, `Challenge` + notifs.

## Garde-fous (transverses)
Bornes physio par mouvement (rejet 422) ; estimé étiqueté + confiance réduite + plafond percentile ;
review='ok' pour entrer au classement/Index ; rate-limit création ; tout versionné (scoringVersion).
