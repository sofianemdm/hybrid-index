# Athlete League — Stratégie de gamification de référence

> Document de stratégie produit (gamification). Source de vérité fonctionnelle : `docs/cahier-des-charges.md`.
> Modèles directeurs : Hooked (Eyal) pour la boucle d'habitude, Octalysis (Chou) pour les 8 drivers,
> et l'éthique « engagement sain » imposée par la constitution du projet.
>
> Règle d'or de ce document : **chaque idée est ancrée sur l'architecture réelle d'Athlete League**
> (Flutter 4 onglets + NestJS modules + score-service versionné + Postgres + Redis ZSET + FCM v1 + cosmétiques).
> Aucune idée générique. Chaque idée = un ticket potentiel.

---

## 0. Rappel de l'existant (briques réutilisables)

| Brique existante | Emplacement | Réutilisable pour |
|---|---|---|
| **Athlete Index** (score /100 affiché, /1000 interne, par sexe) | `score-service` + `me.dto.ts` | toute mécanique de progression / projection |
| **Radar 6 attributs**, no-drop (meilleur effort par attribut) | `score-service/scoring.service.ts` | défis ciblés, badges d'attribut, « point faible » |
| **Ligues H/F** classées par Index | `leaderboard.module.ts` + Redis ZSET | tous les classements, paliers de percentile |
| **Rival** (athlète juste au-dessus) | `profile/rival.logic.ts` (`buildRival` pur) | duels, barre « prochain rang », revanche |
| **15 WODs de référence** notés par sexe | `wods.data.ts`, `wod-references.data.ts` | WOD de la semaine, boss fights, ladders |
| **Cosmétiques / avatar évolutif** | `theme/cosmetics.dart`, `avatar_editor_screen.dart` | récompenses visuelles non-pay-to-win |
| **Badges** (catalogue) | `engagement/badges.data.ts` + `badges.service.ts` | toute la collection |
| **Streak** (régularité) | `engagement/streak.service.ts`, `widgets/streak_chip.dart` | rétention quotidienne/hebdo |
| **Notifications** (catalogue déclencheurs) | `engagement/notifications.data.ts` + FCM `push_service.dart` | tous les triggers |
| **Classement progression hebdo** | `docs/gamification/classement-progression-hebdo.md` + `progress.module.ts` | montées/descentes hebdo |
| **Endgame** (experts) | `endgame.module.ts`, `endgame_screen.dart` | systèmes long terme |
| **Social / posts / clubs / messaging / challenge** | modules `social`, `posts`, `clubs`, `challenge`, `messaging` | mécaniques sociales |
| **Anti-triche** : saut subScore >+30 % all-time & percentile ≥0.85 → review | `moderation.service.ts` | garde-fou crédibilité |
| Nav 4 onglets, `home_shell.dart`, `share_card_screen.dart` | `features/home` | points d'entrée UI |

**Boucle d'habitude cible (Hooked) :**
- **Déclencheur** : push « ton Rival t'a repris 0,4 pt » / quiet hours respectées + recap hebdo.
- **Action** : logger un WOD (≤ 60 s) ou consulter son classement.
- **Récompense variable** : gain d'Index incertain (no-drop), montée de rang, badge surprise, dépassement du Rival.
- **Investissement** : avatar customisé, historique de PR, club rejoint, défi accepté → augmente le coût de départ et arme le prochain déclencheur.

**Principes NON négociables appliqués partout :**
1. On récompense **régularité + récupération**, jamais le volume brut (anti-surentraînement).
2. **Dopamine honnête** : un « top 5 % » est toujours vrai (percentile réel ZSET). Pas de fausse flatterie.
3. **Zéro dark pattern** : pas de honte de streak, pas de FOMO punitif, quiet hours par défaut, plafonds de fréquence.

---

# A. 20 FONCTIONNALITÉS DE GAMIFICATION FORTES

### A1. Barre « Prochain Rang » vivante
1. **Nom** : Prochain Rang (Next Rank Bar).
2. **Principe** : barre de progression vers le palier supérieur (Bronze→Argent→Or→Platine→Diamant→Élite), graduée en points d'Index réels.
3. **Parcours** : onglet Home (`home_screen.dart`), sous l'`index_ring`. Tap → feuille détaillée « il te manque X pts ≈ 1 WOD endurance amélioré ».
4. **Engagement** : transforme un score abstrait en objectif tangible « presque atteint ».
5. **Psycho** : effet de gradient d'objectif (goal-gradient) + progression.
6. **Rétention** : D7/D30 — donne une raison de revenir « finir » la barre.
7. **Priorité** : indispensable.
8. **Complexité** : faible. Réutilise `rank_progress_bar.dart` (déjà présent) + percentile ZSET.
9. **Intégration** : api `leaderboard` expose `pointsToNextRank` ; Flutter `rank_progress_bar.dart` ; clé `lb:{sex}` ZSET.
10. **Risques** : frustration si le palier est trop loin → afficher la conversion en « ~N WODs » et un mini-conseil du coach, jamais juste un mur.

### A2. Index Projeté (« Et si tu battais ce WOD ? »)
1. **Nom** : Projection.
2. **Principe** : avant de logger, montrer l'Index simulé si l'athlète atteint un temps cible.
3. **Parcours** : `log_wod_screen.dart` / `wod_result_entry_screen.dart` → slider de temps cible → l'`index_ring` anime la valeur projetée (déjà amorcé : `data/projection.dart`, `projection_test.dart`).
4. **Engagement** : crée le désir AVANT l'effort ; rend l'amélioration concrète.
5. **Psycho** : anticipation de récompense (dopamine pré-récompense), progression.
6. **Rétention** : D1/D7 — motive à retenter un WOD.
7. **Priorité** : indispensable (brique déjà entamée).
8. **Complexité** : faible/moyenne. Réutilise `score-service` (appel projeté, non persistant) + `projection.dart`.
9. **Intégration** : endpoint `score-service /v1/score/project` (dry-run, ne persiste pas) ; Flutter `projection.dart`.
10. **Risques** : promettre un gain non tenu → toujours « projeté », jamais « gagné » ; pas de persistance.

### A3. Battre le Pro (Références Pro)
1. **Nom** : Defy the Pro.
2. **Principe** : sur chaque WOD, un repère « temps d'une référence pro » (données publiques sourcées, hors classement — cf. mémoire `no-fake-athlete-accounts`).
3. **Parcours** : `wod_detail_screen.dart` → ligne « Pro : 3:12 — tu es à +0:48 ». Si l'athlète passe sous le pro → animation + badge.
4. **Engagement** : étalon aspirationnel crédible, hors-ligue donc non démoralisant pour le classement.
5. **Psycho** : statut aspirationnel, progression, ego sain.
6. **Rétention** : D30 — objectif lointain qui survit aux paliers.
7. **Priorité** : très important.
8. **Complexité** : faible. Données pro déjà cadrées (Références Pro). Pas de Redis.
9. **Intégration** : table `pro_reference(wod_id, sex, time)` ; affichage `wod_detail_screen.dart`.
10. **Risques** : usurpation/illégitimité → uniquement données publiques sourcées, label « Référence », jamais un faux compte.

### A4. Paliers de Percentile (Top X %)
1. **Nom** : Tiers de Percentile.
2. **Principe** : badges de seuils réels : Top 50 / 25 / 10 / 5 / 1 %.
3. **Parcours** : Home + `public_profile_screen.dart` affichent « Top 8 % Hommes ». Franchir un seuil → célébration (`celebration.dart`).
4. **Engagement** : statut public vérifiable + objectifs intermédiaires.
5. **Psycho** : statut social, rareté, dopamine **honnête**.
6. **Rétention** : D30 — chaque seuil franchi relance.
7. **Priorité** : indispensable.
8. **Complexité** : faible. `ZRANK / ZCARD` sur `lb:{sex}`.
9. **Intégration** : `leaderboard.service` → `percentile` ; badges dans `badges.data.ts`.
10. **Risques** : crédibilité du Top 5 % = sacrée → calcul live ZSET, jamais arrondi flatteur ; masquer le badge si population < seuil statistique (cf. ligues < 200 users).

### A5. Duel de Rival hebdomadaire
1. **Nom** : Rival Duel.
2. **Principe** : le Rival (athlète juste au-dessus) devient un duel d'une semaine : qui gagne le plus d'Index sur la fenêtre ISO.
3. **Parcours** : `rival_card.dart` (Home) → « Duel cette semaine : toi +1,2 / Rival +0,8 ». Fin de semaine → résultat + revanche proposée.
4. **Engagement** : personnalise la compétition (un visage, pas une foule).
5. **Psycho** : compétition 1v1, ego, récompense variable.
6. **Rétention** : D7 — boucle hebdo naturelle.
7. **Priorité** : indispensable.
8. **Complexité** : moyenne. Réutilise `rival.logic.ts` + `iso-week.ts` + progression hebdo ZSET.
9. **Intégration** : module `challenge` ; clé `duel:{week}:{userId}` ; push « duel lancé / terminé ».
10. **Risques** : rival inactif = duel mort → si rival 0 effort sur 3 j, proposer un « sparring » avec un voisin de classement actif.

### A6. WOD de la Semaine classé
1. **Nom** : WOD of the Week (WOTW).
2. **Principe** : 1 des 15 WODs mis en avant chaque semaine, classement dédié de la semaine.
3. **Parcours** : onglet WODs (`wod_tab.dart`) bannière « WOTW » → log → classement spécifique semaine.
4. **Engagement** : focalise la communauté sur un même effort → comparabilité maximale.
5. **Psycho** : compétition, appartenance, FOMO **doux** (non punitif).
6. **Rétention** : hebdo forte.
7. **Priorité** : indispensable.
8. **Complexité** : moyenne. ZSET `wotw:{week}:{sex}` + `wods.data.ts`.
9. **Intégration** : champ `featuredWeek` côté WOD ; `progress_board_screen.dart` réutilisé.
10. **Risques** : WOTW « avec matériel » exclut les sans-matériel → alterner strictement (8 avec / 7 sans) pour garantir l'accès SANS matériel.

### A7. Points Faibles ciblés (radar exploité)
1. **Nom** : Maillon Faible.
2. **Principe** : détecte l'attribut le plus bas du radar et propose le WOD qui le ferait le plus progresser.
3. **Parcours** : Home → carte « Ton maillon faible : Endurance (42) » → bouton « Combler » → `coach_screen.dart`.
4. **Engagement** : transforme une faiblesse en quête personnalisée à fort ROI d'Index.
5. **Psycho** : progression, complétion (aversion au déséquilibre).
6. **Rétention** : D7/D30.
7. **Priorité** : très important.
8. **Complexité** : moyenne. Lit le radar (`scoring.service.ts`) + `coach.service.ts`.
9. **Intégration** : `coach` renvoie `weakestAttribute` + prescription ; UI Home + Coach.
10. **Risques** : pousser au surentraînement d'un attribut → cap : 1 reco active à la fois, respect du repos planifié (cf. streak intelligent).

### A8. PR Wall (mur des records personnels)
1. **Nom** : PR Wall.
2. **Principe** : collection des records personnels par WOD/attribut, avec date et delta.
3. **Parcours** : `history_screen.dart` → onglet PR. Chaque nouveau PR → animation `celebration.dart` + entrée datée.
4. **Engagement** : matérialise le progrès passé = investissement (Hooked).
5. **Psycho** : progression, collection, ego sain.
6. **Rétention** : D30 — capital accumulé qu'on ne veut pas « abandonner ».
7. **Priorité** : indispensable.
8. **Complexité** : faible. Dérivé des résultats existants (`results.module.ts`, no-drop).
9. **Intégration** : vue dérivée des `results` ; UI `history_screen.dart`.
10. **Risques** : aucun majeur ; veiller à ne pas survaloriser le volume (afficher PR de qualité, pas le nombre de séances).

### A9. Déblocages d'avatar liés à la performance
1. **Nom** : Forge cosmétique.
2. **Principe** : cosmétiques débloqués par accomplissements (rang, badges, PR), jamais par paiement (100 % gratuit verrouillé).
3. **Parcours** : `avatar_editor_screen.dart` → items grisés « débloqué à Or » → motivation visible.
4. **Engagement** : récompense visuelle de statut, identité personnalisée.
5. **Psycho** : collection, statut, investissement identitaire.
6. **Rétention** : D30.
7. **Priorité** : très important.
8. **Complexité** : faible. `cosmetics.dart` existe déjà (G-03/IC-03).
9. **Intégration** : table `cosmetic_unlock(user, item, source)` ; gating dans `avatar_editor_screen.dart`.
10. **Risques** : pay-to-win interdit → tout déblocage = mérite, jamais argent (décision verrouillée gratuit).

### A10. Recap Hebdomadaire (déjà amorcé)
1. **Nom** : Weekly Recap.
2. **Principe** : carte de bilan hebdo : Index +X, rang, PR, badge, duel.
3. **Parcours** : `weekly_recap_card.dart` (Home) le lundi + push recap (`recap.logic.ts` existe).
4. **Engagement** : clôture narrative + relance la semaine.
5. **Psycho** : progression, complétion, récompense variable.
6. **Rétention** : D7 pivot.
7. **Priorité** : indispensable (déjà partiellement là).
8. **Complexité** : faible. `recap.logic.ts` + `weekly_recap_card.dart`.
9. **Intégration** : `engagement` cron lundi ; push 1×/sem max.
10. **Risques** : recap négatif déprimant → ton positif, mettre en avant 1 progrès même minime, jamais « tu as régressé ».

### A11. Coach Adaptatif (séance du jour)
1. **Nom** : Coach.
2. **Principe** : propose 1 séance ciblée/jour selon radar, matériel, repos.
3. **Parcours** : onglet Coach (`coach_screen.dart`) → « Séance du jour » → log direct.
4. **Engagement** : réduit la friction de décision (« quoi faire aujourd'hui ? »).
5. **Psycho** : réduction d'effort cognitif, progression.
6. **Rétention** : D1/D7.
7. **Priorité** : indispensable (module `coach` existe).
8. **Complexité** : moyenne. `coach.service.ts` + `sessions.data.ts`.
9. **Intégration** : déjà en place ; ajouter conscience du repos.
10. **Risques** : pousser tous les jours = surentraînement → intégrer jours de repos planifiés.

### A12. Mode Sans Matériel garanti
1. **Nom** : Bodyweight Path.
2. **Principe** : parcours complet 100 % sans matériel (7 WODs) avec sa propre progression visible.
3. **Parcours** : filtre « Sans matériel » dans `wod_tab.dart` ; onboarding question matériel.
4. **Engagement** : zéro barrière d'entrée → active D1.
5. **Psycho** : accessibilité, appartenance.
6. **Rétention** : D1 surtout.
7. **Priorité** : indispensable (décision verrouillée : utilisable sans matériel).
8. **Complexité** : faible. Tag matériel déjà sur WODs.
9. **Intégration** : filtre `wods.controller.ts`.
10. **Risques** : sentiment de « sous-classe » → l'Index est par sexe et comparable quel que soit le matériel ; ne jamais étiqueter « light ».

### A13. Avatar évolutif par paliers
1. **Nom** : Avatar Tiers.
2. **Principe** : l'avatar gagne des éléments visuels à chaque palier de rang.
3. **Parcours** : `hi_avatar.dart` change visuellement quand le rang monte.
4. **Engagement** : feedback de progression incarné.
5. **Psycho** : statut, identité, progression.
6. **Rétention** : D30.
7. **Priorité** : très important.
8. **Complexité** : moyenne. `hi_avatar.dart` + `cosmetics.dart`.
9. **Intégration** : map rang→assets.
10. **Risques** : régression visuelle si Index baisse → l'avatar ne « rétrograde » jamais visuellement (no-shame).

### A14. Quêtes de progression douces — RENOMMÉES « Objectifs »
1. **Nom** : Objectifs (PAS « quêtes »).
2. **Principe** : objectifs personnels suggérés (ex. « +2 Index ce mois », « 3 WODs cette semaine »).
3. **Parcours** : carte Home « Objectifs ».
4. **Engagement** : micro-buts atteignables.
5. **Psycho** : progression, complétion.
6. **Rétention** : D7.
7. **Priorité** : optionnel.
8. **Complexité** : faible.
9. **Intégration** : `engagement` calcule, UI Home.
10. **Risques** : ⚠️ **« Quêtes » est une décision SUPPRIMÉE.** Ne livrer que sous forme d'objectifs personnels non-narratifs ; pas de système de quêtes scénarisées sans aval humain (voir encadré §Saisons/Quêtes).

### A15. Boss Fight sportif (WOD-épreuve)
1. **Nom** : Boss WOD.
2. **Principe** : un WOD « boss » mensuel à seuil (battre un temps-cible = « vaincre le boss ») — coopératif au niveau ligue.
3. **Parcours** : bannière WODs → barre collective « la ligue a vaincu le boss à 72 % ».
4. **Engagement** : objectif communautaire + perso.
5. **Psycho** : communauté, appartenance, accomplissement.
6. **Rétention** : mensuelle.
7. **Priorité** : très important.
8. **Complexité** : moyenne. ZSET + compteur ligue.
9. **Intégration** : `challenge` ; clé `boss:{month}:{sex}`.
10. **Risques** : seuil trop dur = abandon → seuil percentile (ex. médiane), pas absolu ; pas de pénalité d'échec.

### A16. Streak Intelligent (régularité + repos)
1. **Nom** : Smart Streak.
2. **Principe** : la série compte la **régularité hebdo**, pas les jours consécutifs ; le **repos planifié maintient la série**.
3. **Parcours** : `streak_chip.dart` (Home) « 6 semaines actives ». Jours de repos planifiés = vert, pas rouge.
4. **Engagement** : récompense l'habitude saine sans punir le repos.
5. **Psycho** : habitude, cohérence, engagement (Hooked investissement).
6. **Rétention** : D7/D30 pivot.
7. **Priorité** : indispensable (module `streak.service.ts` existe).
8. **Complexité** : faible/moyenne. Étendre `streak.service.ts`.
9. **Intégration** : logique « semaine active = ≥1 effort OU repos planifié déclaré ».
10. **Risques** : honte de streak interdite → pas de compteur rouge agressif ; **1 « gel » gratuit/mois** ; objectif = régularité, jamais quotidien forcé.

### A17. Carte de partage (Share Card)
1. **Nom** : Index Card.
2. **Principe** : carte type FIFA partageable (Index, rang, radar, badge).
3. **Parcours** : `share_card_screen.dart` → export image → réseaux.
4. **Engagement** : viralité + fierté.
5. **Psycho** : statut social, identité, acquisition virale.
6. **Rétention** : indirecte (acquisition) + fierté.
7. **Priorité** : très important (écran existe).
8. **Complexité** : faible. `share_card_screen.dart`.
9. **Intégration** : trigger après PR/rang.
10. **Risques** : partage de score gênant si bas → l'athlète choisit ; mise en avant d'un progrès, pas d'un classement humiliant.

### A18. Notifications éthiques (taxonomie)
1. **Nom** : Smart Nudges.
2. **Principe** : déclencheurs utiles, plafonnés, quiet hours, ton positif (détail en §I).
3. **Parcours** : `notification_settings_screen.dart` (déjà là) granularité par type.
4. **Engagement** : ramène au bon moment sans saouler.
5. **Psycho** : déclencheur externe (Hooked).
6. **Rétention** : D1/D7.
7. **Priorité** : indispensable (FCM branché).
8. **Complexité** : faible. `notifications.data.ts` + `push_service.dart`.
9. **Intégration** : voir §I.
10. **Risques** : dark patterns → plafond strict + quiet hours par défaut.

### A19. Historique-narratif (« Ton parcours »)
1. **Nom** : Timeline.
2. **Principe** : frise chronologique des jalons (premier Index, montées de rang, PR, badges).
3. **Parcours** : `history_screen.dart` → vue Timeline.
4. **Engagement** : sentiment de chemin parcouru = forte rétention émotionnelle.
5. **Psycho** : progression, investissement, sens.
6. **Rétention** : D30+.
7. **Priorité** : optionnel.
8. **Complexité** : faible. Dérive des events existants.
9. **Intégration** : `progress.module.ts`.
10. **Risques** : aucun.

### A20. Onboarding « Reveal » optimisé
1. **Nom** : The Reveal.
2. **Principe** : révéler l'Index dès ~3 efforts en ≤ 5 min avec montée animée.
3. **Parcours** : `onboarding_screen.dart` → `reveal_screen.dart` (existe) : compte à rebours + révélation `index_ring`.
4. **Engagement** : premier shot de dopamine honnête = clé du D1.
5. **Psycho** : anticipation, récompense, identité naissante.
6. **Rétention** : D1 critique.
7. **Priorité** : indispensable (existe, à polir).
8. **Complexité** : faible. `reveal_screen.dart`.
9. **Intégration** : `onboarding.service.ts` + `/v1/onboarding/estimate`.
10. **Risques** : révéler un score bas peut décourager → cadrer « point de départ » + montrer le potentiel projeté.

---

# B. 10 MÉCANIQUES DE COMPÉTITION

### B1. Ligues à divisions internes (1→10)
1. **Nom** : Divisions.
2. **Principe** : à l'intérieur des 2 ligues H/F, 10 divisions par paliers de percentile (Div 10 = débutants → Div 1 = élite). Montée/descente hebdo.
3. **Parcours** : `leaderboard_screen.dart` → sélecteur de division.
4. **Engagement** : un classement « à ta taille », jamais écrasé par les n°1.
5. **Psycho** : compétition équitable, progression, statut.
6. **Rétention** : D7/D30.
7. **Priorité** : très important.
8. **Complexité** : moyenne. Découpe ZSET `lb:{sex}` par percentile.
9. **Intégration** : `leaderboard.service` → `division` calculée. ⚠️ Voir encadré : on **n'ajoute PAS de nouvelles ligues** (reste 2) — ce sont des **divisions internes**, conformes.
10. **Risques** : ping-pong montée/descente → hystérésis (seuils d'entrée/sortie distincts).

### B2. Montée des 5 meilleurs / relégation des 5 derniers
1. **Nom** : Promotion/Relegation.
2. **Principe** : chaque semaine, les 5 meilleurs progresseurs d'une division montent, les 5 derniers descendent (sur progression hebdo, déjà spécifié).
3. **Parcours** : `progress_board_screen.dart`.
4. **Engagement** : enjeu hebdo clair.
5. **Psycho** : compétition, statut, légère pression saine.
6. **Rétention** : D7.
7. **Priorité** : indispensable (spec hebdo existe).
8. **Complexité** : moyenne. ZSET progression `prog:{week}:{sex}:{div}`.
9. **Intégration** : `progress.module.ts` (déjà cadré).
10. **Risques** : relégation = honte → cadrer « tu restes à ton Index réel, seule la division bouge » ; pas de descente sous Index baissé, basé sur progression relative.

### B3. Classement local / national / mondial
1. **Nom** : Geo Boards.
2. **Principe** : filtres géographiques du même Index.
3. **Parcours** : `leaderboard_screen.dart` → onglets Local/National/Mondial.
4. **Engagement** : « top de ma ville » = atteignable et fier.
5. **Psycho** : statut, appartenance locale.
6. **Rétention** : D30.
7. **Priorité** : très important (post-200 users).
8. **Complexité** : moyenne. ZSET par scope `lb:{sex}:{geo}`.
9. **Intégration** : champ géo opt-in (RGPD) ; ⚠️ tout public mais géo = opt-in.
10. **Risques** : vie privée → granularité ville max, opt-in, jamais d'adresse.

### B4. Duel direct (défi 1v1 choisi)
1. **Nom** : Challenge a Friend.
2. **Principe** : défier un athlète sur un WOD, fenêtre de temps, vainqueur au temps.
3. **Parcours** : `public_profile_screen.dart` → « Défier » → `challenge_screen.dart`.
4. **Engagement** : compétition personnelle volontaire.
5. **Psycho** : compétition, ego, social.
6. **Rétention** : D7.
7. **Priorité** : très important (module `challenge` existe).
8. **Complexité** : moyenne.
9. **Intégration** : `challenge.service.ts` + push.
10. **Risques** : harcèlement → invitation acceptable/refusable, blocage, modération.

### B5. WOTW Leaderboard (classement du WOD de la semaine)
1. **Nom** : WOTW Board.
2. **Principe** : classement spécifique au WOD de la semaine (voir A6).
3. **Parcours** : `progress_board_screen.dart` filtré WOTW.
4. **Engagement** : comparabilité parfaite (même effort).
5. **Psycho** : compétition, FOMO doux.
6. **Rétention** : hebdo.
7. **Priorité** : indispensable.
8. **Complexité** : moyenne. `wotw:{week}:{sex}`.
9. **Intégration** : voir A6.
10. **Risques** : un seul WOD peut exclure → alterner matériel/sans.

### B6. Boss Fight ligue (coopétition)
1. **Nom** : League Boss.
2. **Principe** : objectif collectif (voir A15) — la ligue « bat » un boss, récompense cosmétique commune.
3. **Parcours** : bannière + jauge collective.
4. **Engagement** : but commun fédérateur.
5. **Psycho** : communauté, appartenance.
6. **Rétention** : mensuelle.
7. **Priorité** : très important.
8. **Complexité** : moyenne.
9. **Intégration** : `challenge` + compteur ligue.
10. **Risques** : passager clandestin → récompense liée à participation min.

### B7. Course au Rang (sprint de fin de semaine)
1. **Nom** : Rank Rush.
2. **Principe** : dernières 48 h de la semaine, bonus de visibilité aux mouvements de classement.
3. **Parcours** : Home bannière « 36 h pour gagner ton rang ».
4. **Engagement** : pic d'activité contrôlé.
5. **Psycho** : urgence saine (pas punitive), compétition.
6. **Rétention** : D7 fin de semaine.
7. **Priorité** : optionnel.
8. **Complexité** : faible.
9. **Intégration** : `iso-week.ts` + push plafonné.
10. **Risques** : urgence = surentraînement → message « si tu es en repos, ça compte aussi » ; pas de compte à rebours anxiogène.

### B8. Sparring (adversaire d'entraînement suggéré)
1. **Nom** : Sparring Match.
2. **Principe** : quand le Rival est inactif, suggérer un voisin de classement actif comme adversaire.
3. **Parcours** : `rival_card.dart` → « Ton rival dort, affronte X ? ».
4. **Engagement** : maintient la compétition vivante.
5. **Psycho** : compétition, social.
6. **Rétention** : D7.
7. **Priorité** : très important (résout le cas limite Rival inactif).
8. **Complexité** : moyenne. `rival.logic.ts` étendu (sélection alternative).
9. **Intégration** : règle « si rival inactif 3 j → candidat actif à ±2 rangs ».
10. **Risques** : volatilité du rival → garder le rival officiel, le sparring est un bonus.

### B9. Ladder par attribut (6 mini-classements)
1. **Nom** : Attribute Ladders.
2. **Principe** : un classement par attribut du radar (meilleur en Force, en Endurance…).
3. **Parcours** : `leaderboard_screen.dart` → onglet par attribut.
4. **Engagement** : même les non-n°1 peuvent dominer une niche.
5. **Psycho** : statut de niche, accomplissement.
6. **Rétention** : D30.
7. **Priorité** : très important.
8. **Complexité** : moyenne. 6 ZSET `lb:{sex}:attr:{name}`.
9. **Intégration** : subScores du radar.
10. **Risques** : sur-spécialisation → l'Index global reste roi, les ladders sont secondaires.

### B10. Revanche (rematch) automatique
1. **Nom** : Rematch.
2. **Principe** : après un duel perdu, proposition de revanche en un tap.
3. **Parcours** : fin de duel → « Revanche ? ».
4. **Engagement** : boucle de rivalité auto-entretenue.
5. **Psycho** : ego, complétion, compétition.
6. **Rétention** : D7.
7. **Priorité** : très important.
8. **Complexité** : faible. `challenge` réutilisé.
9. **Intégration** : flag `rematch_of`.
10. **Risques** : acharnement → limite de revanches/semaine, refus possible.

---

# C. 10 RÉCOMPENSES / BADGES / TROPHÉES

> Cadre : 4 familles **Collection / Performance / Régularité / Social** (à ajouter dans `badges.data.ts`, certains manquent — cf. note « Streak Badges absents »).

### C1. Badges de Percentile (Performance)
1. **Nom** : Top Tier.
2. **Principe** : Top 50/25/10/5/1 % (voir A4).
3. **Parcours** : profil + Home.
4. **Engagement** : statut vérifiable.
5. **Psycho** : rareté, statut, honnêteté.
6. **Rétention** : D30.
7. **Priorité** : indispensable.
8. **Complexité** : faible. ZSET.
9. **Intégration** : `badges.data.ts` + `badges.service.ts`.
10. **Risques** : crédibilité sacrée → live percentile.

### C2. Badges de Régularité (Streak)
1. **Nom** : Consistency.
2. **Principe** : 4 / 12 / 26 / 52 semaines actives (PAS de jours consécutifs forcés).
3. **Parcours** : profil.
4. **Engagement** : récompense l'habitude saine.
5. **Psycho** : habitude, collection.
6. **Rétention** : D30+.
7. **Priorité** : indispensable.
8. **Complexité** : faible. `streak.service.ts`.
9. **Intégration** : **à AJOUTER dans `badges.data.ts`** (documenté mais absent).
10. **Risques** : ne jamais retirer un badge de régularité acquis (no-shame).

### C3. Badges de Collection (WOD complétés)
1. **Nom** : Completionist.
2. **Principe** : « 15/15 WODs essayés », « 8/8 avec matériel », « 7/7 sans ».
3. **Parcours** : profil + WODs.
4. **Engagement** : pousse à explorer tout le catalogue.
5. **Psycho** : collection, complétion.
6. **Rétention** : D30.
7. **Priorité** : très important.
8. **Complexité** : faible.
9. **Intégration** : `badges.service.ts` lit `results`.
10. **Risques** : pousser à logger pour cocher → 1 essai suffit, qualité non requise pour le badge collection (le badge perf gère la qualité).

### C4. Trophée « Battu le Pro » (Performance)
1. **Nom** : Pro Slayer.
2. **Principe** : passer sous le temps d'une Référence Pro (voir A3).
3. **Parcours** : célébration + profil.
4. **Engagement** : exploit rare et fier.
5. **Psycho** : rareté, statut aspirationnel.
6. **Rétention** : D30+.
7. **Priorité** : très important.
8. **Complexité** : faible.
9. **Intégration** : `badges.data.ts` + table `pro_reference`.
10. **Risques** : triche → soumis à l'anti-triche (>+30 %/percentile review).

### C5. Badge « Comeback » (Récupération récompensée)
1. **Nom** : Comeback.
2. **Principe** : revenir après une pause (≥ 2 sem) et reloguer = badge **positif** (zéro honte de pause).
3. **Parcours** : au retour, message « Content de te revoir » + badge.
4. **Engagement** : réduit la culpabilité = réactive les dormants.
5. **Psycho** : appartenance, soulagement, récupération saine.
6. **Rétention** : résurrection (anti-churn).
7. **Priorité** : indispensable (principe « engagement sain »).
8. **Complexité** : faible.
9. **Intégration** : `engagement` détecte retour ; push de bienvenue, jamais culpabilisant.
10. **Risques** : exploit (pause/retour en boucle) → 1×/trimestre.

### C6. Trophée « Équilibre Parfait » (radar plat haut)
1. **Nom** : Hybrid Master.
2. **Principe** : tous les attributs au-dessus d'un seuil (vrai athlète hybride).
3. **Parcours** : profil rare.
4. **Engagement** : récompense l'esprit même de l'app (hybride).
5. **Psycho** : accomplissement, rareté.
6. **Rétention** : endgame.
7. **Priorité** : très important.
8. **Complexité** : faible. Min des subScores.
9. **Intégration** : `badges.data.ts`.
10. **Risques** : trop dur → seuil percentile, pas absolu.

### C7. Badge social « Mentor »
1. **Nom** : Mentor.
2. **Principe** : aider X athlètes (réactions, conseils, club animé).
3. **Parcours** : social/clubs.
4. **Engagement** : valorise les contributeurs.
5. **Psycho** : communauté, statut social.
6. **Rétention** : D30 (contributeurs = piliers).
7. **Priorité** : optionnel.
8. **Complexité** : moyenne. Events `social`.
9. **Intégration** : `social` + `clubs`.
10. **Risques** : spam pour le badge → critères qualitatifs (réactions reçues, pas envoyées).

### C8. Cosmétiques de saison cosmétique (sans « saisons »)
1. **Nom** : Limited Cosmetics.
2. **Principe** : cosmétiques liés à un événement daté (ex. « Cohorte de juin »), purement esthétiques.
3. **Parcours** : avatar.
4. **Engagement** : rareté temporelle.
5. **Psycho** : rareté, collection, FOMO doux.
6. **Rétention** : récurrente.
7. **Priorité** : optionnel.
8. **Complexité** : faible. `cosmetics.dart`.
9. **Intégration** : ⚠️ **ne PAS appeler ça « saison »** (décision supprimée) — c'est un déblocage cosmétique daté, pas une remise à zéro de classement. Voir encadré.
10. **Risques** : confusion avec saisons compétitives → aucune RAZ de score.

### C9. Trophée « Iron Will » (régularité longue + repos respecté)
1. **Nom** : Iron Will.
2. **Principe** : 52 semaines actives **avec** repos planifié utilisé (preuve d'entraînement intelligent).
3. **Parcours** : profil, ultra-rare.
4. **Engagement** : sommet de la régularité saine.
5. **Psycho** : statut, accomplissement, identité.
6. **Rétention** : endgame.
7. **Priorité** : optionnel.
8. **Complexité** : faible. `streak.service.ts`.
9. **Intégration** : badge endgame.
10. **Risques** : valoriser le repos, pas le volume → condition inclut des repos.

### C10. Badges « Premier » (rareté historique)
1. **Nom** : Pioneer.
2. **Principe** : « 1000 premiers athlètes », « 1er Élite de la ligue ».
3. **Parcours** : profil.
4. **Engagement** : rareté non reproductible = fierté durable.
5. **Psycho** : rareté absolue, statut.
6. **Rétention** : ancrage long terme.
7. **Priorité** : optionnel.
8. **Complexité** : faible.
9. **Intégration** : `badges.data.ts` (flag historique).
10. **Risques** : aucun ; veiller à l'authenticité (vrai ordre d'inscription).

---

# D. 10 MÉCANIQUES SOCIALES

### D1. Réactions sur efforts (kudos)
1. **Nom** : Kudos.
2. **Principe** : réactions positives sur un WOD/PR d'un autre (que du positif, pas de dislike).
3. **Parcours** : `community_tab.dart` / `explore_screen.dart` → bouton kudos.
4. **Engagement** : reconnaissance entre pairs.
5. **Psycho** : appartenance, validation sociale.
6. **Rétention** : D7.
7. **Priorité** : très important (module `social`/`posts` existe).
8. **Complexité** : faible.
9. **Intégration** : `posts.service.ts` + push « X a kudosé ton PR ».
10. **Risques** : pas de négativité → uniquement réactions positives.

### D2. Clubs / Box (communautés)
1. **Nom** : Clubs.
2. **Principe** : rejoindre un club, voir le classement interne (post-200 users).
3. **Parcours** : `clubs_screen.dart` / `club_detail_screen.dart` (existent).
4. **Engagement** : appartenance forte, micro-classement.
5. **Psycho** : appartenance, identité de groupe.
6. **Rétention** : D30+.
7. **Priorité** : très important.
8. **Complexité** : moyenne. `clubs` module existe.
9. **Intégration** : ⚠️ classement box/amis seulement après 200 users (décision verrouillée) → activer par feature-flag de population.
10. **Risques** : clubs fantômes < 200 users → garder désactivé jusqu'au seuil.

### D3. Messagerie directe
1. **Nom** : Direct Messages.
2. **Principe** : échanges 1v1 (déjà le 1er trigger push).
3. **Parcours** : `conversations_screen.dart` / `chat_screen.dart`.
4. **Engagement** : lien social = ancrage.
5. **Psycho** : communauté, réciprocité.
6. **Rétention** : forte.
7. **Priorité** : très important (existe).
8. **Complexité** : moyenne.
9. **Intégration** : déjà branché FCM.
10. **Risques** : harcèlement → blocage, signalement (`moderation`).

### D4. Feed d'activité de la ligue
1. **Nom** : League Feed.
2. **Principe** : flux des montées de rang, PR, badges des autres.
3. **Parcours** : `community_tab.dart`.
4. **Engagement** : preuve sociale + inspiration.
5. **Psycho** : preuve sociale, FOMO doux, appartenance.
6. **Rétention** : D7.
7. **Priorité** : très important.
8. **Complexité** : moyenne. `feed-events.service.ts` existe.
9. **Intégration** : `social`.
10. **Risques** : surcharge/comparaison toxique → mettre en avant le positif et le réalisable, pas que les top.

### D5. Co-WOD (séance commune planifiée)
1. **Nom** : Co-WOD.
2. **Principe** : planifier le même WOD au même créneau avec un ami, comparer après.
3. **Parcours** : `challenge_screen.dart` mode « ensemble ».
4. **Engagement** : engagement social par rendez-vous.
5. **Psycho** : engagement réciproque (commitment), communauté.
6. **Rétention** : D7.
7. **Priorité** : optionnel.
8. **Complexité** : moyenne.
9. **Intégration** : `challenge` + push rappel.
10. **Risques** : no-show → pas de pénalité, juste reprogrammation.

### D6. Profils publics riches
1. **Nom** : Public Profile.
2. **Principe** : carte FIFA + radar + badges + PR visibles.
3. **Parcours** : `public_profile_screen.dart` (existe).
4. **Engagement** : vitrine de statut.
5. **Psycho** : statut, identité.
6. **Rétention** : indirecte.
7. **Priorité** : indispensable (existe).
8. **Complexité** : faible.
9. **Intégration** : champ `visibility` prévu (futur privé).
10. **Risques** : vie privée → `visibility` opt-out futur.

### D7. Mur de PR du club
1. **Nom** : Club PR Wall.
2. **Principe** : meilleurs PR récents du club mis en avant.
3. **Parcours** : `club_detail_screen.dart`.
4. **Engagement** : émulation locale.
5. **Psycho** : appartenance, compétition douce.
6. **Rétention** : D30.
7. **Priorité** : optionnel (post-200).
8. **Complexité** : moyenne.
9. **Intégration** : `clubs` + `results`.
10. **Risques** : voir D2 (seuil population).

### D8. Parrainage (invitations)
1. **Nom** : Bring a Friend.
2. **Principe** : inviter un ami = badge social + comparatif d'Index dès qu'il rejoint.
3. **Parcours** : `share_card_screen.dart` → lien d'invitation.
4. **Engagement** : acquisition virale + rival pré-installé.
5. **Psycho** : réciprocité, acquisition.
6. **Rétention** : forte (cohorte d'amis).
7. **Priorité** : très important.
8. **Complexité** : moyenne. Lien profond.
9. **Intégration** : ⚠️ pas de récompense monétaire (gratuit) → récompense = badge/cosmétique.
10. **Risques** : faux comptes → cap, vérification d'activité.

### D9. Défis de groupe (club vs club)
1. **Nom** : Club Clash.
2. **Principe** : deux clubs s'affrontent sur la progression hebdo cumulée.
3. **Parcours** : `clubs_screen.dart`.
4. **Engagement** : appartenance + compétition collective.
5. **Psycho** : communauté, rivalité de groupe.
6. **Rétention** : hebdo.
7. **Priorité** : optionnel (post-200).
8. **Complexité** : élevée.
9. **Intégration** : `clubs` + `progress` agrégé.
10. **Risques** : clubs déséquilibrés → matchmaking par taille.

### D10. Réactions du Coach communautaires (conseils entre pairs)
1. **Nom** : Peer Tips.
2. **Principe** : sur un WOD, les athlètes laissent des conseils techniques courts (modérés).
3. **Parcours** : `wod_detail_screen.dart` → section conseils.
4. **Engagement** : valeur d'usage + entraide.
5. **Psycho** : communauté, réciprocité, mentorat.
6. **Rétention** : D30.
7. **Priorité** : optionnel.
8. **Complexité** : moyenne. `posts` + `moderation`.
9. **Intégration** : `wods` + `moderation`.
10. **Risques** : désinformation/sécurité → modération + signalement, conseils non médicaux.

---

# E. 10 RÉTENTION QUOTIDIENNE & HEBDOMADAIRE

### E1. Séance du jour (déjà via Coach) — voir A11. **Priorité indispensable.** D1/D7. Risque surentraînement → repos intégré.

### E2. Check-in quotidien léger
1. **Nom** : Daily Check-in.
2. **Principe** : ouverture rapide montrant 1 info fraîche (rang, mouvement du rival).
3. **Parcours** : Home au lancement.
4. **Engagement** : micro-habitude sans effort.
5. **Psycho** : habitude, variabilité.
6. **Rétention** : D1.
7. **Priorité** : très important.
8. **Complexité** : faible.
9. **Intégration** : Home `home_screen.dart`.
10. **Risques** : check-in vide = ennui → toujours 1 info nouvelle, sinon rien (pas de faux badge).

### E3. Push « ton rival a bougé » (plafonné)
1. **Nom** : Rival Moved.
2. **Principe** : notif quand le rival gagne/perd de l'Index (max 1/jour).
3. **Parcours** : push → `rival_card.dart`.
4. **Engagement** : déclencheur compétitif pertinent.
5. **Psycho** : compétition, déclencheur externe.
6. **Rétention** : D7.
7. **Priorité** : indispensable.
8. **Complexité** : faible. `notifications.data.ts`.
9. **Intégration** : trigger sur recalcul Index.
10. **Risques** : spam → 1/jour max, quiet hours.

### E4. Weekly Recap — voir A10. **Indispensable.** Pivot D7.

### E5. WOD de la Semaine — voir A6. **Indispensable.** Hebdo.

### E6. Smart Streak — voir A16. **Indispensable.** Repos respecté.

### E7. Objectif hebdo personnel
1. **Nom** : Weekly Goal.
2. **Principe** : 1 objectif/semaine adapté (ex. « +1,5 Index » ou « combler endurance »).
3. **Parcours** : Home lundi.
4. **Engagement** : cap hebdomadaire clair.
5. **Psycho** : progression, complétion.
6. **Rétention** : D7.
7. **Priorité** : très important.
8. **Complexité** : faible.
9. **Intégration** : `engagement`.
10. **Risques** : objectif irréaliste → calibré sur l'historique de l'athlète.

### E8. Rappel intelligent de repos
1. **Nom** : Rest Nudge.
2. **Principe** : si l'athlète logge beaucoup, suggérer un repos (anti-surentraînement actif).
3. **Parcours** : push/coach.
4. **Engagement** : confiance (l'app pense à ta santé).
5. **Psycho** : soin, appartenance.
6. **Rétention** : D30 (durabilité).
7. **Priorité** : indispensable (principe non négociable).
8. **Complexité** : moyenne. Lit la fréquence de log.
9. **Intégration** : `coach` + `streak`.
10. **Risques** : aucun — c'est un garde-fou ; ne jamais récompenser un volume excessif.

### E9. Lundi de relance (reset hebdo positif)
1. **Nom** : Fresh Week.
2. **Principe** : chaque lundi, nouvelle fenêtre de duel/WOTW/objectif = redémarrage motivant.
3. **Parcours** : Home + push recap.
4. **Engagement** : rythme hebdomadaire.
5. **Psycho** : nouveau départ (fresh-start effect).
6. **Rétention** : D7.
7. **Priorité** : indispensable.
8. **Complexité** : faible. `iso-week.ts`.
9. **Intégration** : cron.
10. **Risques** : ⚠️ ne PAS remettre l'Index à zéro (ce serait une « saison » supprimée) — seules les fenêtres hebdo tournent.

### E10. Notification de seuil franchi (juste à temps)
1. **Nom** : Almost There.
2. **Principe** : « il te manque 0,6 pt pour Or » quand très proche d'un palier.
3. **Parcours** : push → Home.
4. **Engagement** : goal-gradient activé au pic de motivation.
5. **Psycho** : proximité d'objectif.
6. **Rétention** : D7.
7. **Priorité** : très important.
8. **Complexité** : faible.
9. **Intégration** : `leaderboard` + `notifications.data.ts`.
10. **Risques** : trop fréquent → 1/semaine max par palier, quiet hours.

---

# F. 5 SYSTÈMES DE PROGRESSION LONG TERME

### F1. Courbe de Rangs Bronze→Élite (vite au début, dur en haut)
1. **Nom** : Rank Ladder.
2. **Principe** : 6 rangs principaux. Coût en points d'Index **croissant** : Bronze→Argent facile, Diamant→Élite très dur (courbe asymptotique vers le record ~97).
3. **Parcours** : `progression_screen.dart` + `rank_badge.dart` (existent).
4. **Engagement** : montées rapides early (D1/D7), challenge durable en haut.
5. **Psycho** : progression, maîtrise, statut.
6. **Rétention** : D1 (gains faciles) → D30+ (gros morceaux).
7. **Priorité** : indispensable.
8. **Complexité** : moyenne. Map percentile→rang.
9. **Intégration** : `endgame`/`progression` + `rank_badge.dart`.
10. **Risques** : mur trop tôt = abandon → calibrer pour que la médiane (~57) atteigne Or « confortablement ».

### F2. Endgame Élite (top 1 %)
1. **Nom** : Elite Endgame.
2. **Principe** : pour le top 1 %, contenus dédiés : ladders d'attribut, Pro Slayer, classement mondial, défis entre élites.
3. **Parcours** : `endgame_screen.dart` (existe).
4. **Engagement** : empêche le plafond de verre des experts.
5. **Psycho** : maîtrise, rareté, statut absolu.
6. **Rétention** : D90+ des meilleurs (ambassadeurs).
7. **Priorité** : très important.
8. **Complexité** : moyenne. `endgame.module.ts`.
9. **Intégration** : déjà amorcé.
10. **Risques** : élite intouchable et figée → micro-objectifs (attributs, pro, mondial).

### F3. Prestige cosmétique (sans reset de score)
1. **Nom** : Prestige.
2. **Principe** : jalons cumulés (PR totaux, semaines actives) débloquent des cosmétiques de prestige — **sans jamais toucher l'Index**.
3. **Parcours** : avatar + profil.
4. **Engagement** : progression infinie parallèle au score.
5. **Psycho** : collection, statut, maîtrise.
6. **Rétention** : long terme.
7. **Priorité** : optionnel.
8. **Complexité** : moyenne. `cosmetics.dart`.
9. **Intégration** : compteurs cumulés.
10. **Risques** : ⚠️ ne pas confondre avec « prestige = reset » (saison) ; ici zéro RAZ.

### F4. Maîtrise par WOD (niveaux de WOD)
1. **Nom** : WOD Mastery.
2. **Principe** : chaque WOD a des paliers de maîtrise (bronze→or sur ce WOD), basés sur le percentile du temps.
3. **Parcours** : `wod_detail_screen.dart`.
4. **Engagement** : 15 mini-progressions = beaucoup de buts.
5. **Psycho** : maîtrise, collection.
6. **Rétention** : D30+.
7. **Priorité** : très important.
8. **Complexité** : moyenne. `wod-levels.data.ts` existe déjà.
9. **Intégration** : `score-service` percentile par WOD.
10. **Risques** : grind d'un seul WOD → l'Index global no-drop limite l'abus ; valoriser la variété (badge collection).

### F5. Index Annuel / Capital de progression
1. **Nom** : Year in Review.
2. **Principe** : bilan annuel narratif (progression d'Index, PR, badges, parcours) + projection de l'année suivante.
3. **Parcours** : `history_screen.dart` Timeline (voir A19) + carte annuelle partageable.
4. **Engagement** : sens du chemin, fierté, viralité annuelle.
5. **Psycho** : sens, identité, statut.
6. **Rétention** : ré-engagement annuel + acquisition.
7. **Priorité** : optionnel.
8. **Complexité** : moyenne. Dérive des events.
9. **Intégration** : `progress` + `share_card`.
10. **Risques** : bilan négatif → toujours souligner ≥1 progrès ; ton positif.

---

# G. 5 IDÉES TRÈS ORIGINALES (peu d'apps sportives les font)

### G1. « Index Fantôme » — cours contre ton toi d'il y a 3 mois
1. **Nom** : Ghost Self.
2. **Principe** : un adversaire fantôme = ton propre profil daté (Index/temps d'il y a 3 mois). Tu cours contre ton ancien toi.
3. **Parcours** : `wod_result_entry_screen.dart` → overlay fantôme ; Home « tu bats ton toi de mars de +3 ».
4. **Engagement** : compétition sans dépendre des autres, toujours « gagnable », ultra-motivant pour les solo/sans matériel.
5. **Psycho** : progression, ego sain, auto-dépassement (pas de comparaison toxique).
6. **Rétention** : D30+ (toujours un fantôme à battre).
7. **Priorité** : très important.
8. **Complexité** : moyenne. Snapshots d'Index historisés (déjà via `results`/`progress`).
9. **Intégration** : `progress.service.ts` expose snapshot T-90j ; UI overlay (`overlay_radar.dart` réutilisable).
10. **Risques** : démotivant si stagnation → si pas de progrès, comparer à un fantôme plus ancien où il y a eu progression ; ton encourageant.

### G2. « Empreinte Hybride » — ta forme de radar comme signature
1. **Nom** : Hybrid Fingerprint.
2. **Principe** : la forme du radar devient une « signature » nommée (ex. « Diesel », « Sprinter », « All-Rounder ») + matchmaking d'athlètes au profil opposé pour apprendre.
3. **Parcours** : `radar_view.dart` → label d'archétype ; suggestion « athlètes complémentaires à suivre ».
4. **Engagement** : identité forte + découverte sociale par complémentarité.
5. **Psycho** : identité, appartenance, curiosité.
6. **Rétention** : D30.
7. **Priorité** : optionnel.
8. **Complexité** : moyenne. Clustering simple des subScores.
9. **Intégration** : `score-service` calcule l'archétype ; `radar_view.dart`.
10. **Risques** : enfermer dans un archétype → présenter comme évolutif, jamais figé.

### G3. « Pacte de Repos » — la récupération comme acte gamifié
1. **Nom** : Recovery Pact.
2. **Principe** : déclarer un jour de repos planifié **maintient** le streak et débloque un micro-bonus cosmétique. La récupération devient une action positive comptabilisée.
3. **Parcours** : `streak_chip.dart` → « Planifier repos » ; jour vert.
4. **Engagement** : retire la culpabilité, fidélise les jours off (rétention même sans entraînement).
5. **Psycho** : soin de soi, habitude saine, appartenance.
6. **Rétention** : D7/D30 — on revient même les jours de repos.
7. **Priorité** : indispensable (incarne le principe « engagement sain », unique sur le marché).
8. **Complexité** : faible/moyenne. Extension `streak.service.ts`.
9. **Intégration** : action « repos planifié » dans `engagement`.
10. **Risques** : abus (tout repos) → cap N repos/semaine comptant pour le streak ; au-delà, neutre (jamais punitif).

### G4. « Battle de Prédiction » — parie sur ta propre progression
1. **Nom** : Call Your Shot.
2. **Principe** : en début de semaine, l'athlète **prédit** son gain d'Index. S'il atteint = badge « Tenu parole ». Engagement par auto-promesse publique (commitment device).
3. **Parcours** : Home lundi → « Je vise +1,5 » → fin de semaine, vérification.
4. **Engagement** : auto-engagement = puissant prédicteur de comportement.
5. **Psycho** : cohérence/engagement (Cialdini), progression.
6. **Rétention** : D7.
7. **Priorité** : très important (très peu d'apps sportives le font).
8. **Complexité** : faible. `engagement` stocke la prédiction.
9. **Intégration** : `engagement` + Weekly Recap vérifie.
10. **Risques** : prédiction ratée = honte → cadrer « pas atteint ? ça compte quand même, on réajuste » ; aucune pénalité.

### G5. « Constellation de Ligue » — carte vivante des athlètes
1. **Nom** : League Map.
2. **Principe** : visualisation type « ciel étoilé » où chaque athlète est une étoile positionnée selon Index/archétype ; ton étoile et celle du rival brillent. Découverte ludique du classement.
3. **Parcours** : `leaderboard_screen.dart` → vue « Constellation ».
4. **Engagement** : rend un classement abstrait beau et explorable, sentiment de faire partie d'un tout.
5. **Psycho** : appartenance, statut, esthétique (« epic meaning » Octalysis).
6. **Rétention** : D30 (exploration récurrente).
7. **Priorité** : optionnel.
8. **Complexité** : élevée (rendu Flutter custom).
9. **Intégration** : data ZSET + archétype (G2) ; rendu `CustomPainter`.
10. **Risques** : perf sur grande population → échantillonnage/zoom par division ; ne pas écraser le n°1 visuellement.

---

# H. SYSTÈME DE RANGS & PALIERS (spec)

| Rang | Cible (percentile ligue / Index ~/100) | Difficulté de montée | Avatar |
|---|---|---|---|
| Bronze | départ (0–40e) | très rapide (D1) | base |
| Argent | 40–65e (~médiane 57) | rapide (D7) | +élément |
| Or | 65–85e | modérée | +élément |
| Platine | 85–95e (Top 15→5 %) | dure | +élément rare |
| Diamant | 95–99e (Top 5→1 %) | très dure | rare |
| Élite | Top 1 % (vers record ~97) | endgame | unique + Pioneer possible |

- **Courbe** : gains d'Index par rang croissants (asymptote vers ~97). Médiane (~57) doit atteindre **Or** sans frustration.
- **Hystérésis** anti ping-pong : seuil d'entrée > seuil de sortie.
- **No-shame** : l'avatar ne régresse jamais visuellement ; un rang perdu se reconquiert sans humiliation.
- **Population** : masquer percentiles fins tant que la ligue < seuil statistique (cf. < 200 users).

---

# I. TAXONOMIE DES NOTIFICATIONS (ZÉRO dark pattern)

**Règles globales** (à coder dans `notifications.data.ts` + `notification_settings_screen.dart`) :
- **Quiet hours par défaut** : 21 h–8 h (heure locale), jamais de push hors plage.
- **Plafond global** : max **1 push/jour** et **~4/semaine** (hors messages directs, eux temps réel).
- **Granularité** : chaque type désactivable individuellement.
- **Ton** : toujours positif/encourageant ; jamais de honte, jamais de FOMO punitif.

| Type | Déclencheur | Plafond | Ton |
|---|---|---|---|
| Rival a bougé | recalcul Index du rival | 1/jour | « Le duel se resserre ! » |
| Presque un rang | à < 1 pt d'un palier | 1/sem/palier | « Tu y es presque ! » |
| Weekly Recap | lundi | 1/sem | bilan positif |
| Duel lancé/terminé | duel hebdo | 2/duel | sportif |
| WOTW dispo | lundi | 1/sem | invitation |
| Kudos reçu | réaction d'un pair | groupé, 1/jour | « X a aimé ton PR » |
| Comeback | retour après pause | 1/retour | « Content de te revoir » (jamais culpabilisant) |
| Repos suggéré | sur-fréquence de log | 1/sem | « Pense à récupérer » |
| Message direct | nouveau message | temps réel | neutre |

**Interdits explicites** : « tu vas perdre ton streak ! », « ton rival te dépasse, vite ! », compte à rebours anxiogène, notification nocturne, culpabilisation d'inactivité.

---

# ⚠️ ENCADRÉ — Éléments touchant des DÉCISIONS VERROUILLÉES (aval humain requis)

1. **Saisons mensuelles (demandées par l'utilisateur)** : les « saisons » sont une décision **SUPPRIMÉE** du cahier des charges. Tout ce qui ressemble à une remise à zéro périodique de classement/score nécessite un **aval humain explicite** avant implémentation. Les fenêtres **hebdomadaires** (duel, WOTW, progression) ne sont **pas** des saisons (aucune RAZ d'Index) et restent conformes. → **Recommandation : valider avec l'humain si l'on veut de vraies saisons mensuelles ; sinon s'en tenir aux fenêtres hebdo + cosmétiques datés.**
2. **Quêtes** : également **SUPPRIMÉES**. La feature A14 est volontairement limitée à des « Objectifs » personnels non-narratifs. Un système de quêtes scénarisées exige un aval humain.
3. **Ligues multiples** : décision = **2 ligues (H/F) uniquement**. Les « Divisions » (B1) sont des subdivisions **internes** de ces 2 ligues, pas de nouvelles ligues → conforme. Ne jamais créer de 3e ligue sans aval.
4. **Box/amis** : classements de box/amis et clubs (D2, D7, D9) activables **seulement après 200 users** (décision verrouillée) → feature-flag de population.
5. **Monétisation** : tout est **gratuit pour l'instant**. Aucune récompense payante ; cosmétiques = mérite uniquement. Toute monétisation (Phase 3 « premium ») = **aval humain**.
6. **Géolocalisation** (B3) : « tout est public » mais la géo doit rester **opt-in** (RGPD) ; granularité ville max.

---

# J. PLAN D'IMPLÉMENTATION EN 3 PHASES

### Phase 1 — Rendre l'app addictive VITE (archi déjà prête : Redis + FCM + score-service)
Ordre :
1. The Reveal (A20) — polissage onboarding.
2. Prochain Rang (A1).
3. Index Projeté (A2).
4. Paliers de Percentile (A4) + Badges Top Tier (C1).
5. Smart Streak (A16) + Recovery Pact (G3) + Badges Régularité (C2, **à ajouter dans `badges.data.ts`**).
6. Weekly Recap (A10).
7. Rival Duel (A5) + Rival Moved push (E3).
8. WOD of the Week + WOTW Board (A6/B5).
9. Notifications éthiques (A18/§I) + quiet hours + plafonds.
10. PR Wall (A8) + Comeback (C5).

**Effort cumulé** : ~moyen (la majorité = faible, réutilise ZSET/score-service/FCM/cosmétiques existants).
**Dépendances** : Redis ZSET (présent), score-service projection dry-run (à exposer), FCM (présent), `streak.service.ts` (présent à étendre), `recap.logic.ts` (présent).
**Pourquoi maintenant** : ces briques activent D1 (reveal, projection), D7 (duel, recap, WOTW, streak) et la dopamine honnête (percentiles) sans nouvelle infra. ROI rétention maximal, risque technique minimal.

### Phase 2 — Compétition & rétention avancées
Ordre :
1. Divisions (B1) + Promotion/Relegation (B2, spec hebdo déjà écrite).
2. Battre le Pro (A3) + Pro Slayer (C4).
3. Maillon Faible (A7) + Rest Nudge (E8) + Weekly Goal (E7).
4. Ghost Self (G1) + Call Your Shot (G4).
5. WOD Mastery (F4, `wod-levels.data.ts` présent) + Attribute Ladders (B9).
6. Avatar Tiers (A13) + Forge cosmétique (A9).
7. Social : Kudos (D1), League Feed (D4), Sparring (B8), Rematch (B10).
8. Rank Ladder courbe (F1) + Elite Endgame (F2).

**Effort cumulé** : moyen→élevé.
**Dépendances** : snapshots historiques d'Index (Ghost Self), clustering archétype (optionnel), géo opt-in (si Geo Boards).
**Pourquoi maintenant** : une fois la boucle de base addictive, on creuse la profondeur compétitive et la personnalisation pour tenir D30 et installer l'endgame.

### Phase 3 — Premium / viral / AAA
Ordre :
1. Geo Boards local/national/mondial (B3, post-200, géo opt-in).
2. Clubs & Box (D2/D7/D9, post-200) + Club Clash.
3. Boss WOD / League Boss (A15/B6).
4. League Map « Constellation » (G5).
5. Hybrid Fingerprint (G2).
6. Year in Review (F5) + Index Card avancée (A17) + Parrainage (D8).
7. Mentor (C7), Peer Tips (D10).
8. **⚠️ Saisons mensuelles** (si — et seulement si — aval humain) ; sinon cosmétiques datés (C8).

**Effort cumulé** : élevé.
**Dépendances** : seuil 200 users (clubs/géo), modération renforcée (peer content), rendu Flutter custom (constellation), **aval humain** (saisons, toute monétisation premium).
**Pourquoi maintenant** : viralité et profondeur sociale n'ont de sens qu'avec une masse critique d'utilisateurs et une boucle de base éprouvée.

---

# K. TOP 7 — Si je ne devais en garder que 7 pour le prochain sprint

1. **The Reveal (A20)** — sans un D1 réussi, rien d'autre ne compte. Premier shot de dopamine honnête. *Déjà 80 % là.*
2. **Prochain Rang (A1)** — transforme un score abstrait en objectif « presque atteint » (goal-gradient). Faible coût, fort effet. *`rank_progress_bar.dart` existe.*
3. **Index Projeté (A2)** — crée le désir avant l'effort ; motive à reloguer. *`projection.dart` déjà amorcé.*
4. **Smart Streak + Recovery Pact (A16+G3)** — LE différenciateur éthique : récompenser régularité ET repos. Rétention D7/D30 sans dark pattern. *`streak.service.ts` existe.*
5. **Rival Duel + Rival Moved (A5+E3)** — réutilise la brique Rival déjà construite pour créer une boucle hebdo 1v1 personnelle. *`rival.logic.ts` + `iso-week.ts`.*
6. **WOD of the Week + Board (A6/B5)** — focalise la communauté, comparabilité parfaite, rythme hebdo. *Réutilise WODs + ZSET + `progress_board_screen.dart`.*
7. **Paliers de Percentile + Top Tier (A4/C1)** — statut public **vérifiable** (crédibilité du « top 5 % » = sacrée). Dopamine honnête. *ZSET `ZRANK/ZCARD`.*

**Pourquoi ces 7** : ils couvrent toute la boucle Hooked (déclencheur=duel/rival/notifs, action=log via reveal/projection, récompense variable=percentile/rang/duel, investissement=streak/PR), s'appuient à >80 % sur du code déjà présent (ZSET, score-service, FCM, streak, rival, cosmétiques), respectent **toutes** les décisions verrouillées, et incarnent les 3 principes non négociables (engagement sain via Recovery Pact, dopamine honnête via percentiles réels, zéro dark pattern via notifs plafonnées). Risque technique faible, impact rétention maximal.
