# Spec — « WOD Engine » & « Communauté »

> Objectif : faire passer HYBRID INDEX d'une app à 15 WODs figés à une **plateforme ouverte et
> sociale** des athlètes hybrides. Contrainte absolue : **l'intégrité et la crédibilité de
> l'HYBRID INDEX restent non négociables** — l'ouverture aux WODs personnalisés ne doit jamais
> permettre de gonfler son score.

## Décision produit (arbitrage tranché par le porteur, 20 juin)
Les **WODs personnalisés comptent dans l'HYBRID INDEX**, mais avec **confiance réduite** tant
qu'ils ne sont pas calibrés sur la communauté (cold-start → distribution réelle). Étiquetage
« estimé » obligatoire. Ceci lève le report « Phase 2 » des custom WODs.

## 1. Renommage
« Logger un WOD » → **« Ajouter un WOD »**.

## 2. Onglet « WOD »
- **Catalogue 15 WODs** : fiche + **records/top temps mondiaux réels** + paliers champion /
  intermédiaire / occasionnel + distribution par sexe.
- **Constructeur de WOD** : format (For Time, AMRAP, EMOM, Chipper, Intervalles, Tabata, Strength,
  Distance/Temps) + mouvements depuis une **bibliothèque** (pull-up, push-up, ring muscle-up,
  thruster, wall ball, burpee, run, double-under, deadlift…) + paramètres (time cap, rounds, repos).
- **Moteur d'estimation** : pour tout WOD, le score-service estime **3 références par sexe**
  (champion / intermédiaire / occasionnel) → note (sous-score 0–1000) + percentile.
- **WODs communautaires** : recherchables, « refaire ce WOD » en un tap, présents sur le profil du créateur.
- **Cold-start → calibration** : barème estimé (confiance low) jusqu'à N≥30 résultats/sexe, puis
  **distribution réelle communautaire** (confiance medium/high), versionnée.
- **Leaderboard par WOD** (par sexe, filtres matériel/rang).
- **Intégration Index** : mapping mouvements → attributs ; no-drop ; garde-fous anti-gonflage
  (confiance réduite si estimé, bornes physio, plafonnement par percentile, anti-anomalie).

## 3. Onglet « Communauté » (réseau social athlétique)
- **Feed** priorisant les athlètes suivis : PR, WODs, montées de rang/badges, défis ; **réactions** (kudos 💪🔥).
- **Recherche d'athlètes** : filtres sexe / rang / matériel (option ville, objectif).
- **Comparaison** : radars superposés (toi vs n'importe qui) + écart d'Index + comparaison par WOD commun.
- **Follow** + **Défis** (créer/suivre un défi sur un WOD, résolution + notification).

## 4. Moteur d'estimation (méthodologie cible)
Approche « coût par mouvement, composé par format » :
1. Bibliothèque de mouvements : débit de référence par niveau (champion/intermédiaire/occasionnel)
   et par sexe + tags d'attributs pondérés.
2. Décomposition du WOD (volume par mouvement selon le format).
3. Modèle de composition + fatigue (facteur de format + dégradation avec le volume) → temps/score prédit par niveau.
4. Notation : percentile du résultat réel sur l'échelle → courbe `f` → sous-score 0–1000.
5. Attributs : agrégation pondérée des tags → radar.
6. Calibration continue : estimation remplacée par la distribution réelle communautaire (versionnée).
Tout vit dans le **score-service** (autorité).

## 5. Anti-triche & crédibilité
Bornes physio par mouvement ; WODs estimés étiquetés + confiance réduite ; anti-spam/modération
légère ; badges « Top X% » et records ancrés sur des distributions réelles.

## 6. Incréments
- **A** — Records des 15 WODs + fiche + leaderboard par WOD.
- **B** — Bibliothèque de mouvements + moteur d'estimation v1 (score-service).
- **C** — WOD builder + WODs communautaires + refaire un WOD.
- **D** — Calibration communautaire (cold-start → distribution réelle).
- **E** — Communauté : follow + feed priorisé + kudos.
- **F** — Recherche + comparaison radars + défis.
