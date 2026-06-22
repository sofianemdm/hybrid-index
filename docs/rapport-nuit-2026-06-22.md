# Rapport de nuit — 22 juin 2026 (AAA : Lots A → D)

Tout le plan validé hier soir est **livré, testé et commité**. Dépôt propre.
**169 tests verts** (scoring-core 69, contracts 16, score-service 21, API 63) + build web OK à chaque étape.

## ⚠️ 2 actions pour toi avant de tester
1. **Migration appliquée cette nuit** (`avatar_pro`) → si tu repars d'une base fraîche, `npx prisma migrate deploy` (déjà appliquée sur la base locale).
2. **Relancer le seed** pour recaler bots + rangs sur les WODs recalibrés et la nouvelle échelle :
   `pnpm --filter @hybrid-index/api prisma:seed`

## Ce qui a été fait

### Lot A — Fonctionnel rapide
- **Historique sur un WOD** : section « Mes prestations » (30 dernières) sur la fiche d'une séance. `myBest` calculé sur TOUT l'historique (jamais régressif).
- **Partage natif** de la carte FIFA (réseaux sociaux, `share_plus`) ; « Télécharger » en secours.
- **Badge « Athlète confirmé »** (5 séances + 5 abonnements) + pastille ✓ sur les profils.
- **Like ❤️** sur tout le feed et les posts.

### Lot B — Crédibilité du score
- **Recalibrage** des 17 WODs (audit sport-science) : fin des temps surestimés. Les pires
  (benchmark_zero, run_5k, run_free_distance) corrigés de plusieurs minutes.
- **« Références Pro »** sur la fiche WOD : vrais temps publics sourcés (Fran : Zac Hare 1:47,
  Mat Fraser 2:07 ; Grace : Nick Bloch 0:59 ; 5 km : Cheptegei 12:35 ; etc.), comme cibles à viser.

### Lot C — Engagement
- **Défi de la semaine** : un WOD imposé qui change chaque semaine en rotation variée
  (cardio/force/hybride/HYROX/sans matériel), avec classement dédié de la semaine.
  Bannière sur l'accueil → écran défi (compte à rebours + « Faire le défi » + classement H/F).

### Lot D — Avatar pro
- **Photo de profil** (image_picker → base64 ≤ 400 Ko) OU **avatar illustré** + nouveau **fond** (8 teintes).
  La photo s'affiche partout (accueil…).

## ⛔ Décision importante (à ne pas revenir dessus)
Tu avais demandé des **faux comptes au nom d'athlètes** (Hunter, etc.) avec des temps inventés.
**Refusé** : c'est de l'usurpation d'identité (bannissement App Store/Google Play + risque juridique
+ données inventées qui faussent le score). Livré à la place : les **« Références Pro »** (mêmes
athlètes, vrais temps publics, labellisés « données publiques · non affilié », aucun compte créé).
Si tu veux de vrais comptes d'athlètes, la seule voie propre = **partenariat** avec leur accord.

## Reste différé (documenté, non bloquant)
- Avatar : accessoires (lunettes/bandeau — colonne réservée), photo sur la carte FIFA partagée.
- Références : abaisser `hardMin` du 5 km si on veut que le WR rentre dans le barème (mineur, affichage).
- Factoriser la règle « confirmed » (dupliquée badges/profil) ; test e2e dédié au filtre hebdo du défi.
- Modération lexicale à étoffer avant ouverture publique (juriste).

## Comment tester
`docker compose up -d` (Postgres+Redis) → seed → lancer score-service + api → `cd apps/mobile && flutter run -d chrome`.
Parcours : accueil (bannière Défi + avatar photo), fiche d'un WOD (énoncé, références pro, mon historique),
carte FIFA (Partager), profil d'un athlète (pastille ✓), like sur le feed.
