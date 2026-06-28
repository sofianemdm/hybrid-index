# Audit AAA — Athlete League — APRES 2 passes de correctifs (28 juin 2026)

Moyenne globale : **7,77/10** (depart 6,09). Toutes zones >= 7,4.

# Audit AAA — Athlete League (post 2 passes de correctifs)

## 1) Notes par zone (triées) + moyenne

| # | Zone | Note /10 |
|---|------|----------|
| 1 | Création de séance (wod_builder + score-service estimate) | 8.4 |
| 2 | Messages (messaging) | 8.2 |
| 3 | Ligue | 8.1 |
| 4 | Design (theme/tokens + widgets partagés) | 8.0 |
| 5 | Séances (wods + score-service) | 7.6 |
| 6 | Accueil (home + PlayerCard) | 7.4 |
| 6 | Communauté (social/posts/modération) | 7.4 |
| 6 | Notifications (engagement gating & feed) | 7.4 |
| 6 | Gamification (badges/streak/célébrations) | 7.4 |

**Moyenne globale : 7,76 / 10** (69,8 / 90).

## 2) Zones encore < 9 et principal levier restant

Les 9 zones sont sous 9. Levier dominant par zone :

- **Création de séance (8.4)** — Borner les entrées : ajouter `.max()` aux DTO Zod (`reps`, `loadKg`, `distanceMeters`) + `@UseGuards(JwtAuthGuard)` sur `POST /estimate`.
- **Messages (8.2)** — Appliquer `blockedIds()` aux LECTURES (`conversations()` / `messages()`), pas seulement à `send()` ; ajouter les tests API absents (pairing, eligibility, anti-N+1).
- **Ligue (8.1)** — Unifier l'échelle d'affichage : la Ligue est en points bruts (jusqu'à 4000) alors que tout le reste est en /100 FIFA ; corriger aussi l'ordinal EN (`2th/3th`).
- **Design (8.0)** — **A11Y** : zéro `Semantics` dans toute la couche de widgets partagés (IndexRing, HiButton, RadarView…). C'est le levier transverse n°1 de l'app.
- **Séances (7.6)** — Harmoniser les états d'erreur : `ErrorRetry` localisé sur les 4 écrans restants (fuite de `'$snap.error'` brut) + i18n des chaînes FR en dur ('LIGUE', 'tours', top X%).
- **Accueil (7.4)** — Reduce-motion + perf : la PlayerCard ignore `disableAnimations` (sheen `repeat()` permanent, monté en `IndexedStack` sans `RepaintBoundary`) ; et **GradeBlock mort** = régression produit (l'Index n'est plus annoncé comme « estimé »).
- **Communauté (7.4)** — Rate-limiting absent partout (posts/follow/report/kudos = vecteur de spam public) ; valider l'enum `explore` (Zod) pour éviter les 500.
- **Notifications (7.4)** — Bug de correctness : `next-rank-close` compare l'échelle /100 (RANK_BANDS) à l'Index interne /1000 → déclencheur mort ; appliquer `ratingFromInternal`. + i18n des libellés de types.
- **Gamification (7.4)** — i18n cassé au moment dopamine maximal (montée de bande / pluriel badge en FR codé en dur) ; et fonctionnalité verrouillée non livrée : repos planifié / weeklyGoal présents back+client mais inaccessibles dans l'UI.

## 3) Verdict

**Pas encore AAA.** L'app est solide et homogène (toutes les zones ≥ 7,4 ; moyenne 7,76), avec un backend de très haute qualité (idempotence, anti-triche, gating de notifications testé, modération bidirectionnelle). Mais **aucune zone n'atteint 9**, et trois dettes transverses bloquent le niveau AAA :

1. **Accessibilité** — quasi inexistante (zéro `Semantics` dans les widgets partagés et sur l'élément héros IndexRing/PlayerCard) : disqualifiant pour un standard AAA.
2. **Cohérence post-correctifs** — le correctif annoncé (`ErrorRetry` localisé, reduce-motion) n'est PAS appliqué partout (Séances, Communauté, Notifications, Accueil, Gamification fuient encore `'$e'` brut).
3. **Deux bugs de correctness** — `next-rank-close` mort (échelle /100 vs /1000) et incohérence d'échelle Ligue (points bruts vs /100), plus régression produit du GradeBlock.

Niveau actuel : **« très bon MVP+ », pas AAA.** Cap pour franchir le AAA : une passe a11y transverse (Semantics partout), finir l'harmonisation `ErrorRetry`/reduce-motion, et corriger les 2 bugs d'échelle. Cela hisserait mécaniquement les 5 zones à 7,4–7,6 vers ≥ 8,5.

---

# Defauts restants par zone (vers 10/10)

## ACCUEIL (features/home + PlayerCard share_card_screen.dart + providers app.dart) — **7.4/10**

_États d'écran complets et soignés : loading→HomeSkeleton qui épouse la forme réelle (anti layout-shift), error→ErrorRetry localisé partagé, profil null→retry localisé (home_screen.dart:117-135) ; pull-to-refresh invalide tous les providers home (44-49). Robustesse providers : streak/recap/history/badges/inbox sont tolérants try/catch → jamais une raison d'échec d'écran (app.dart:40-108). RivalCard défensif (ne déréférence jamais rival! sur null, rival_card.dart:18-20). Zéro dark pattern : projection 100% honnête (null si delta<=0, jamais de fausse promesse, projection.dart:26 ; horizon plafonné 52 sem) ; badges vides assumés « dopamine honnête » (share_card_screen.dart:689) ; ton bienveillant (rival « jamais de honte »). i18n complète sur Accueil (homeGreetingNoName, homeProjection, beta, freshness… tous dans app_fr.arb) + greeting null-safe (75-77). Design AAA de la PlayerCard : skins par rang, métal, halo pulse, cascade d'attributs, FittedBox(scaleDown) garantit qu'elle tient toujours (170), TextScaler.noScaling pour PNG déterministe (137). Nav a Semantics(selected/button) (home_shell.dart:217). CTA unique plein par écran (un seul HiButton), actions secondaires en fantômes._

### Defauts restants
- Reduce-motion IGNORÉ sur l'élément dominant de l'Accueil : disableAnimations n'est géré QUE dans league_reveal_sheet.dart. La PlayerCard lance _sheen.repeat() en PERMANENCE (share_card_screen.dart:278) + reveal 1100ms (272) sans jamais lire MediaQuery.disableAnimations. La correction reduce-motion annoncée ne couvre PAS la zone Accueil.
- Animation perpétuelle coûteuse : la carte embarquée sur l'Accueil n'a AUCUN RepaintBoundary (home_screen.dart) → le sheen en boucle repeint un grand sous-arbre ; IndexedStack (home_shell.dart:126) garde l'Accueil monté donc le sheen + le polling inbox 8s (app.dart:88-107) tournent même quand l'utilisateur est sur un autre onglet (batterie/GPU).
- PlayerCard = 0 Semantics : OVR animé, grade, archétype, scores par attribut, écusson de ligue, badges sont totalement invisibles aux lecteurs d'écran. Trou d'accessibilité majeur sur l'élément héros. Le tap avatar (home_screen.dart:55) n'a ni Semantics ni tooltip.
- GradeBlock = CODE MORT (grade_block.dart, 263 lignes, jamais référencé). C'était le seul composant qui affichait l'état global « Index estimé » + les séances minimales à faire pour révéler le vrai Index. L'Accueil ne dit DONC PLUS jamais à l'utilisateur que son Index global est une estimation (seule une opacité 0.7 par attribut subsiste, share_card_screen.dart:804) → régression produit/conformité vs la promesse « ~3 entraînements pour un Index complet ».
- Sémantique du « prochain palier » incohérente sur le même écran : GradeBlock vise ovr+1, projection vise la dizaine suivante 80+ (projection.dart:28), la barre de la PlayerCard utilise HiGrade.progress → trois définitions de « progression vers le prochain » coexistent.
- _ErrorScreen (app.dart:154-177) viole la règle maison « jamais de Text('$e') brut » : affiche l'exception brute (169) ET « Réessayer » en dur non localisé (171) ; le chemin de boot AuthGate court-circuite ErrorRetry et l'i18n.
- inboxBadgeProvider : boucle 8s sans backoff en cas d'échec réseau répété (app.dart:95-107) — pas critique mais inélégant côté perfs/réseau.

---

## SEANCES (features/wods : tab, detail, result_feedback, bareme/prediction, leaderboard, Rx + API wods + score-service) — **7.6/10**

_Backend de très haute qualité, c'est le socle de la note. logResult (apps/api/src/modules/wods/wods.service.ts:93-127) couvre l'idempotence (clé stable + upsert update:{}, compteur incrémenté UNIQUEMENT sur 1re écriture L89-90), l'anti-triche (saut >+30% du sous-score ET percentile≥0.85 → pending_review, exclu classements, L56-57), et l'anti-spam feed PR-only (L100-110, pas de post sur rejeu). Le leaderboard (L501-585) utilise un tie-break déterministe identique entre la liste (orderBy rawResult+userId, L60) et le calcul de « ma position » (L98-105) — les divergences BUG-007/008 sont closes ; « Toi #N » épinglé hors top (wod_detail_screen.dart:584-587). Tri sur perf brute (pas subScore) volontairement cohérent avec l'affichage (L43-46). Rx/Allégé = SOURCE UNIQUE via la prescription back (poids non vide) propagée par widget.scalable de la fiche → l'entrée de résultat (wod_detail_screen.dart:135 → wod_result_entry_screen.dart:29,61) ; plus aucune liste codée en dur ; classements Rx/Scaled séparés (sélecteur masqué si non scalable, wod_detail_screen.dart:553). Sécurité de saisie : secondes [0,59] (BUG-013, wod_result_entry_screen.dart:90-95), idempotencyKey stable (BUG-014, L51), bornes WOD_RESULT_OUT_OF_BOUNDS gérées côté UI (L186) et back (wods.service.ts:118-119). Prédiction crédible et gardée : null tant que l'Index n'est pas complet (radar 6/6, ni provisoire ni estimé, wods.service.ts:484-485) ; moteur score-service robuste (Riegel L291, multiplicateur de charge/fatigue L295-298, transitions L312, monotonicité forcée L345-349, garde-fous finite/positif L340). result_feedback.dart normalise correctement le gain (g>0 = mieux quel que soit le sens de la métrique, L54-56), jamais de fanfare sur contre-perf (dialogue calme + haptique en intensité light, L102-123), 5 paliers, variantes aléatoires, intégralement i18n (clés rf*). Célébration calibrée sur la rareté du badge (wod_result_entry_screen.dart:210-220), enchaînement bande→résultat→badges propre, review natif plafonné OS. wod_builder_screen.dart utilise bien le composant partagé ErrorRetry (L462). Design cohérent (tokens HiColors/HiType/HiSpace, gradients de marque, RankBadge, FittedBox-friendly)._

### Defauts restants
- ÉTATS D'ERREUR NON HARMONISÉS (UX) : le composant partagé ErrorRetry n'est utilisé QUE dans wod_builder_screen.dart:462. Les 4 autres écrans affichent un Text brut de l'exception SANS bouton réessayer : wod_tab.dart:49-52 (Text('${snap.error}')), wod_detail_screen.dart:89 et :575 (leaderboard), other_workouts_screen.dart:191. Sur erreur réseau l'utilisateur est bloqué sans recours (le seul moyen est le pull-to-refresh, absent du détail/other). Incohérent avec le reste de l'app post-correctifs.
- FUITE D'EXCEPTION BRUTE À L'ÉCRAN : '${snap.error}' expose le message technique (stack/URL) à l'utilisateur — wod_tab.dart:51, wod_detail_screen.dart:89/575, other_workouts_screen.dart:191. Doit passer par un message localisé neutre (comme ErrorRetry).
- i18n INCOMPLET : chaînes FR codées en dur — wod_tab.dart:184 ('LIGUE'), :195 ('La séance imposée de la Ligue du mois...'), :208 ('Faire cette séance') ; wod_result_entry_screen.dart:206 ('🚀 Tu entres dans le top X% des plus en forme !') ; wod_detail_screen.dart:536 ('Open'/'Scaled') ; wod_format.dart:19,128-153 ('tours' pour kRoundWods). En anglais ces textes resteront français.
- ACCESSIBILITÉ ABSENTE : aucun Semantics/semanticLabel dans TOUTE la zone wods (grep = 0). Les puces d'attributs colorées (wod_detail_screen.dart:99-109), les chips Rx/Scaled (GestureDetector nus, wod_result_entry_screen.dart:320-338 et _segment :155-176, _scopeChip :441-461) ne sont pas annoncés comme boutons sélectionnés/non par les lecteurs d'écran ; cibles tactiles des chips ~36-40px (< 48dp recommandé).
- ÉTATS VIDES PARTIELS : pas d'état vide dédié si le catalogue WODs revient vide (wod_tab.dart:55-58 suppose snap.data! non vide, affiche des sections vides silencieusement). Le leaderboard a un message vide (wod_detail_screen.dart:577-579) et la communauté aussi (other_workouts_screen.dart:213-218), mais le catalogue principal non. snap.data! (wod_tab.dart:55, wod_detail_screen.dart:90, :576) plante si data null sans erreur.
- PERF / DOUBLE-FETCH : other_workouts_screen.dart:186 appelle wodsCatalog() dans le build via ref.read sans cache/Future stocké → re-fetch à chaque rebuild (pas de FutureBuilder mémoïsé comme wod_tab). wod_result_entry_screen._submit refait un wodPrediction() réseau AVANT chaque log (L117) ; acceptable mais ajoute de la latence au moment le plus sensible (le tap Enregistrer).
- DÉPENDANCES CODÉES EN DUR À DES IDs WOD dans l'UI : run_free_distance (wod_result_entry_screen.dart:54), hyrox_solo (:57, et wod_detail_screen.dart:536), cindy via kRoundWods (wod_format.dart:128). Logique métier (catégorie Pro/Open, unité 'tours') figée côté client au lieu d'être pilotée par la prescription/scoreType du back → fragile si on ajoute un WOD en tours ou une autre épreuve Pro/Open.
- MICRO-UX : wod_detail_screen.dart:89 (erreur détail) n'offre pas de retour arrière clair ; _histRow date formatée manuellement par substring (wod_detail_screen.dart:523) au lieu d'un format localisé (jj/mm/aa fixe, pas adapté à l'EN). Toast générique '$e' en dernier recours (wod_result_entry_screen.dart:188) expose l'exception.

---

## Création de séance (wod_builder_screen.dart + score-service computeEstimate/estimateLoad) — **8.4/10**

_Tous les états d'écran sont gérés proprement et de façon distincte : vide (wod_builder_screen.dart:471), chargement (468), erreur sans donnée via le composant partagé ErrorRetry compact (461-467), erreur avec estimation valide conservée + ré-essai inline non destructif (524-536), et succès. Robustesse UI excellente : controllers persistants (1 par bloc, créés hors build) qui éliminent le saut de curseur et la perte de charge (BUG-004, lignes 49-56), debounce 400ms + jeton de séquence _estimateSeq qui ignore les réponses périmées et évite la course de requêtes (81-84, 169-193), dispose() complet de tous les controllers et du timer (95-104). Le moteur d'estimation est solide et finiment borné : garde-fous de finitude NaN/Inf/≤0 (scoring.service.ts:336-350), monotonicité stricte des paliers (344-350, 458-461), clamp charge ≤3.5×poids de corps (448-452), AMRAP cardio (mètres/calories/secondes) agrégé en workPerRound anti-zéro (305-310, 320-325), Riegel pour la course (291). État NON ESTIMABLE explicite (références à 0, confidence 'low') au lieu d'un faux « 0 kg » quand aucun mouvement chargé n'ancre la charge (427-441), affiché par un encart clair côté Flutter (477-496, models.dart:1197-1198). Couverture de tests forte au niveau score-service e2e : Fran médiane ±8%, AMRAP reps croissant, charge monotone/bornée, non-estimable, AMRAP cardio mètres+calories, mouvement inconnu dans les deux branches (scoring.e2e.spec.ts:188-360). i18n complet (clés wodBuilder* présentes en fr ET en), nom de séance auto-généré (zéro friction de saisie), validation Zod des entrées, charge décimale tolérante virgule+point, endpoint de création protégé par JwtAuthGuard._

### Defauts restants
- Securite : POST /v1/wods/estimate n'a PAS de @UseGuards(JwtAuthGuard) (wods.controller.ts:34) — seul l'OptionalJwtAuthGuard de classe s'applique, donc un appelant anonyme peut solliciter le moteur de score. Atténué par le RateLimitGuard global (app.module.ts:56) mais reste un calcul non authentifié exposé.
- Validation : EstimateWodRequest (wod-estimate.dto.ts:6-10,15) et CreateWodRequest (create-wod.dto.ts:6-10) utilisent .positive() SANS .max() — reps:1e9, loadKg:99999, distanceMeters géants sont acceptés. Le moteur clampe la sortie charge mais un amount dégénéré gonfle workPerRound/roundTime sans borne d'entrée avant les garde-fous.
- Validation client : le champ amount par bloc fait int.tryParse(v) ?? b.amount (wod_builder_screen.dart:386) — un champ vidé conserve silencieusement l'ancienne valeur sans feedback visuel ; aucun min/max client-side, aucun message si amount invalide.
- Tests : zéro test au niveau API (NestJS) pour /estimate (seul score-service e2e couvre le moteur) et aucun widget test Flutter pour le builder — l'enchainement debounce/seq/états d'erreur n'est pas verrouillé par un test.
- Accessibilite : les CircularProgressIndicator d'estimation (469, 514) n'ont ni Semantics ni label ; les TextField d'amount/charge ont seulement un hintText (pas de labelText/semanticsLabel) — lecteur d'écran perd le contexte ; le glyphe d'attribut ◆ (545) est décoratif sans texte a11y.
- Garde models.dart:1198 notEstimable = references.every(rawResult<=0) : la branche non-load renvoie toujours des références numériques, donc ce chemin est de facto load-only ; un retour 0 légitime du moteur pourrait faux-positiver l'état non-estimable.

---

## COMMUNAUTE (features/community + modules/social, posts, moderation : kudos, Decouvrir, bloquer, auto-masquage) — **7.4/10**

_Boucle d'engagement saine, zero dark pattern : feed FINI borne (FEED_LIMIT=60, pas de scroll infini, social.service.ts:16), kudos unifie en toggle honnete facon Strava avec mise a jour optimiste + rollback sur echec (community_tab.dart _toggleKudos), et repli « Decouvrir » qui remplit un fil vide par le top de la ligue (vraie valeur, pas manipulation). Moderation solide et coherente : blocage BIDIRECTIONNEL (moderation.service.ts blockedIds OR blockerId/blockedId, applique dans social.service.ts feed/discover), auto-masquage a 3 rapporteurs DISTINCTS (AUTOHIDE_REPORTS=3, upsert garantissant l'unicite par rapporteur) + masquage immediat dans MON fil des le signalement (posts.service.ts forFeed notIn reportedIds). Tous les garde-fous d'abus de base presents : pas d'auto-kudos (social.service.ts:69, posts.service.ts), pas d'auto-follow (social.service.ts:33), pas d'auto-block (moderation.service.ts:21), ownership verifiee sur delete/perf_share (posts.service.ts ForbiddenException). Bonne couverture de tests sur la logique critique (social-kudos-moderation.spec.ts : kudos events+posts, seuil auto-masquage 2 vs 3, repli Decouvrir, exclusion des posts signales). Front soigne : avatar + timeago + RankBadge(ovr) sur chaque carte, etats vide/chargement(skeleton)/succes geres sur le feed, debounce 300ms sur la recherche, i18n complet (AppLocalizations partout, aucun libelle en dur). FeedEventsService best-effort (un echec d'emission ne casse jamais l'action source). Filtre lexical de termes interdits applique au corps des posts (posts.service.ts isCleanName)._

### Defauts restants
- ROBUSTESSE/SECURITE — Aucun rate-limiting nulle part : @nestjs/throttler absent du package.json et de src/. posts.controller.ts create(), follow, reactions, reports n'ont aucun cooldown ni quota → spam de posts, de follows, de signalements et de kudos totalement non borne (vecteur d'abus majeur pour une surface sociale publique).
- SECURITE/VALIDATION — explore non valide : social.controller.ts:48-54 passe les query params sex/rank/q bruts, injectes dans le where Prisma via 'as never' (social.service.ts:91-92), sans Zod enum (contrairement a TOUS les autres endpoints qui utilisent ZodValidationPipe). Une valeur d'enum invalide provoque une 500 au lieu d'un 400 propre.
- ROBUSTESSE — react() sur events non atomique : social.service.ts:71-72 fait deleteMany puis create hors transaction → une course peut perdre le kudos ou en dupliquer ; le chemin post utilise un upsert (correct), incoherence a aligner (envelopper dans prisma.$transaction).
- UX/ETATS — Le composant partage ErrorRetry n'est PAS utilise dans la zone Communaute : l'etat d'erreur du feed (community_tab.dart, Text('${snap.error}')) et celui d'Explore (explore_screen.dart:116) affichent l'erreur brute SANS bouton Reessayer. C'est exactement le correctif annonce mais non applique ici.
- UX — Explore : spinner brut CircularProgressIndicator (explore_screen.dart:114) au lieu du HiSkeleton utilise par le feed (incoherence visuelle), et force-unwrap snap.data! (explore_screen.dart:117).
- ACCESSIBILITE — Zero Semantics/semanticLabel dans tout le dossier community. Le bouton kudos (_kudos, community_tab.dart) est un emoji seul '👏 {n}' avec un simple Tooltip : un lecteur d'ecran annonce « mains qui applaudissent » + un nombre, sans etat applaudi/non-applaudi ni libelle d'action (applaudir/retirer). L'icone more_horiz du menu et le bouton Suivre de Decouvrir n'ont aucun label semantique.
- CONFORMITE — Le cahier des charges (ligne 334) specifie des reactions multi-emoji 💪🔥👏 ; le code unifie a un seul 👏. Decision produit verrouillee (MEMORY « kudos unifie ») donc acceptable, mais c'est une deviation documentee du texte du cahier a faire entériner.
- ENGAGEMENT (mineur) — La carte Decouvrir trie le top de la ligue par Index decroissant (social.service.ts discover) : on ne suggere que des athletes plus forts, ce qui peut etre demotivant pour un debutant. Un melange (quelques pairs de niveau proche) serait plus engageant.
- I18N — Le filtre BANNED_WORDS (moderation.service.ts) est une courte liste FR/EN en dur, non versionnee/centralisee, et applique au corps des posts cote serveur uniquement (pas de feedback preventif cote composer) ; couverture lexicale faible et non extensible (« A enrichir » dans le commentaire).

---

## MESSAGES (features/messaging + modules/messaging : accusés lus, pending/retry, bloquer) — **8.2/10**

_Messagerie réellement aboutie et sans dark pattern. Envoi optimiste complet avec états pending/failed et retry au tap sans perte de message (chat_screen.dart _deliver/_retry). Accusés de lecture propres : « Envoyé » → « Lu » avec icône done_all colorée, affiché seulement sur mon DERNIER message (chat_screen.dart _bubble, isLastMine). Séparateurs de jour localisés (aujourd'hui/hier/date moyenne via MaterialLocalizations). Polling 3 s conscient du cycle de vie : suspendu en arrière-plan, relancé + rattrapage au resume (didChangeAppLifecycleState) — économie batterie/réseau réelle. Tous les états gérés (vide/chargement/erreur/succès) côté inbox ET chat, avec HiEmptyState + CTA Découvrir. Erreurs mappées par code en copie localisée, jamais de Text('$e') brut (messagingErrorMessage). Blocage avec dialogue de confirmation + snackbar + sortie de conversation. Backend rigoureux : couple canonique stable (pair), garde-fous sécurité conservés (blocage + age-gating mineurs/adultes via dmAgeAllowed), cible doit être active, rate limit 20/min, max 2000 car. validé client+serveur+Zod, non-lus en UNE requête groupBy (N+1 BUG-022 corrigé), serveur = source de vérité. i18n FR/EN symétrique (24 clés chacune). Enter=envoyer / Shift+Enter=nouvelle ligne._

### Defauts restants
- Sécurité/UX : conversations() (messaging.service.ts:118) et messages() (ligne 157) ne filtrent PAS les utilisateurs bloqués — seul send() revérifie le blocage via assertCanDm. Un fil avec un utilisateur bloqué reste dans la boîte de réception et le bloqueur peut toujours l'ouvrir et lire l'historique. blockedIds() existe dans ModerationService mais n'est pas appliqué aux lectures de messagerie.
- Tests absents : aucun fichier *messaging*spec/test côté API. CLAUDE.md impose 'TESTS OBLIGATOIRES sur la logique critique' — pairing canonique, eligibility (self/blocked/age/not_connected), marquage lu, anti-N+1 ne sont couverts par aucun test.
- Perf/scalabilité non-AAA : polling toutes les 3 s refait un GET complet jusqu'à 200 messages (messages take:200, chat_screen _pollMessages) sans curseur/paramètre `since` ni delta. O(n) par tick par chat ouvert ; pas de websocket. Acceptable MVP, pas irréprochable.
- Vie privée : accusés de lecture forcés et non désactivables ; messages() marque tout comme lu à l'ouverture (updateMany readAt) sans réglage utilisateur pour couper les accusés.
- Accessibilité : la bulle en échec est un GestureDetector nu sans Semantics/tooltip 'taper pour réessayer' (lecteurs d'écran n'ont que le texte méta). L'IconButton d'envoi n'a ni tooltip ni label sémantique explicite.
- Pastille de non-lus sans plafond : Text('${c.unread}') dans un cercle de taille fixe (conversations_screen.dart:124) déborde pour de grands compteurs — pas de format '99+'.
- Course mineure : pendant un envoi (_sending), _pollMessages sort tôt, donc un message reçu via polling peut être retardé jusqu'au prochain tick non-sending.

---

## Notifications (features/notifications + cloche home_screen.dart/app.dart + modules/engagement gating & feed) — **7.4/10**

_Garde-fous AAA solides et PURS/TESTÉS : notification-gating.ts (quietHours avec passage minuit, dailyCap, cooldown, opt-out, tous fail-open et déterministes via `now` injectable) couverts par test/notification-gating.spec.ts. Anti-spam RÉEL dans le feed : rank-overtaken auto-acquitte le snapshot (engagement.service.ts:163-167) et wod-overtaken est fenêtré sur `performedAt > idx.computedAt` (:196) — pas de notif fossile. Ton 100% bienveillant, zéro FOMO/honte, garde-fou percentile/écart sur rank-overtaken (:156) = aucun dark pattern. Messages du feed entièrement localisés (clé+params, feed* présents dans app_en.arb). Bannière HONNÊTE 'coming soon' si !Env.pushEnabled (notification_settings_screen.dart:99-121). Cloche : badge auto-rafraîchi 8s (app.dart:88), invalidé au retour ; pull-to-refresh + refresh au resume (lifecycle). Push : tokens persistés en base, purge FCM sur 404/400, no-op pur sans requête DB si inactif. RGPD export/delete présents._

### Defauts restants
- CORRECTNESS (significatif) : le déclencheur 'next-rank-close' est CASSÉ/mort. engagement.service.ts:134 `RANK_BANDS.find((b) => b.min > idx.value)` compare des bornes en échelle d'AFFICHAGE /100 (RANK_BANDS.min = 40..100, contracts enums) contre HybridIndex.value qui est INTERNE [0,1000] (partout ailleurs converti via ratingFromInternal/ovr, cf. leaderboard.service.ts:11,73,104). Pour tout athlète réel `next` est undefined → la tuile ne se déclenche jamais ; et `pts = next.min - idx.value` (:136) serait absurde. Aucun ratingFromInternal appliqué ici.
- I18N (significatif) : la liste 'Types de notification' des réglages est en français codé en dur. _triggerRow rend t['title']/t['body'] issus du backend NOTIFICATION_TRIGGERS (notifications.data.ts:15-24) = chaînes FR littérales ; en locale EN cette liste s'affiche en français. Seule surface non localisée de la zone.
- UX/ÉTATS (incohérence avec les correctifs) : l'état d'erreur du feed n'utilise PAS le composant partagé ErrorRetry. notifications_screen.dart:128-136 affiche le `${snap.error}` brut en rouge SANS bouton Réessayer (fuite du texte d'exception), alors que home_screen.dart:46 utilise ErrorRetry. Côté réglages, _load en erreur se contente d'un toast `$e` (notification_settings_screen.dart:48) et laisse un formulaire interactif sur données vides, sans retry.
- ROBUSTESSE (latent) : les heures de silence utilisent l'heure LOCALE SERVEUR, pas le fuseau utilisateur. notification-gating.ts:40 `now.getHours()` ; aucun timezone par utilisateur stocké. Le défaut 22:00→07:00 sera faux hors fuseau serveur dès l'activation FCM.
- UX : aucun état lu/vu. Le feed est recalculé à chaque ouverture (engagement.service.ts feed()) ; un déclencheur encore vrai (ex. week-almost-complete) réapparaît à chaque visite — pas de dismiss/mark-read, légèrement insistant.
- A11Y : boutons d'heures de silence sans label sémantique au-delà de la valeur affichée ; IconButtons +/- du plafond/jour sans tooltip ni label sémantique (notification_settings_screen.dart:137-145).
- MINEUR : next.rank passé brut à feedNextRankTitle(rank) (notifications_screen.dart:282) = clé de bande ('platinum') et non un libellé de rang localisé — sans effet tant que le défaut #1 empêche la tuile, mais ressortirait non traduit une fois corrigé.

---

## LIGUE — **8.1/10**

_ok_

### Defauts restants
- BUG i18n anglais: leagueRevealRankOrdinal autres rangs donnent 2th/3th au lieu de 2nd/3rd (app_en.arb:1036); FR correct.
- Incoherence echelle: Ligue en points bruts jusqu'a 4000/mois (league_screen.dart:175,250,346,389) vs reste de l'app en /100 FIFA.
- clubName charge backend (league.service.ts:114-119) mais jamais affiche dans _myCard (league_screen.dart:339-371).
- Etat vide ma position (pos null) sans CTA direct vers le WOD: engagement manque.
- Perf: standings/me/closeSeason agregent toutes les lignes du mois en JS (league.service.ts:78-82,:220-223), aucun LIMIT SQL; a migrer avant 200+ users.
- A11y: icones de rang podium en liste (league_screen.dart:404-409) sans Semantics; or/argent/bronze par couleur seule.
- Reveal: avatar repli en dur skinTone 2 plus rookie (league_reveal_sheet.dart:235-236): 3 gagnants sans avatar = meme visage.
- Doc: cahier-des-charges.md:294 dit pas de saisons/reset; ligue mensuelle actee (MEMORY) legitime mais cahier non mis a jour.

---

## DESIGN (theme/tokens + widgets partages) — **8/10**

_Systeme de tokens mature : double palette kHiDark/kHiLight avec bascule runtime via getters HiColors.active (tokens.dart:118-152) ; corrections WCAG documentees avec ratios mesures en commentaire (tokens.dart:64,92,98,102). ErrorRetry partage en place, 100% localise, interdit le Text('$e') brut, variante compact (error_retry.dart). Reduce-motion respecte dans les 3 animations lourdes : Celebration (celebration.dart:105-112), IndexRing count-up + halo (index_ring.dart:33-41,52-57), RadarView (radar_view.dart:30-34). HiSkeleton preserve le layout et HomeSkeleton epouse la forme reelle du contenu (hi_skeleton.dart:56-82). Celebration a un vrai anti-fatigue (1 forte/session, retrograde la 2e) + RepaintBoundary sur les confettis (celebration.dart:16-34,158). Typo en polices embarquees, chiffres tabulaires anti-jank (tokens.dart:408-436). HiPressable apporte un micro-scale coherent + haptique a tout element interactif._

### Defauts restants
- A11Y CRITIQUE : zero Semantics dans toute la couche de widgets partages. Aucun Semantics/MergeSemantics dans IndexRing, RadarView, HiButton, HiCard, HiPressable, HiAvatar, ErrorRetry, HiEmptyState, Celebration (grep : seul streak_chip utilise un Tooltip). L'IndexRing, point focal de l'app, expose l'OVR en Text brut (index_ring.dart:99-108) -> un lecteur d'ecran lit '73 / ATHLETE INDEX / TOP 4%' en 3 fragments sans role ni label.
- HiButton/HiPressable s'appuient sur un GestureDetector brut (hi_card.dart:24) sans Semantics(button:true) -> non annonces comme boutons, pas de role de focus pour l'accessibilite.
- HiTap.minTarget (48dp) est du code mort : defini (tokens.dart:338-341) mais reference nulle part. Les cibles reelles le violent : lignes d'attributs du radar a 8px de padding vertical ~= 28px de hauteur tappable (radar_view.dart:86) ; HiGhostButton a 44px (hi_button.dart:104), sous le 48 que le token lui-meme impose.
- HiSkeleton ignore le reduce-motion : controller ..repeat() inconditionnel (hi_skeleton.dart:24) ; le shimmer continue d'animer pour les utilisateurs ayant demande la reduction des animations, alors que tous les autres widgets animes le respectent.
- Chaines francaises en dur dans des widgets partages (i18n incomplet sur la zone) : 'Continuer', 'Touche pour continuer', barrierLabel:'Fermer' (celebration.dart:46,204,206) et 'estime' (radar_view.dart:100) contournent AppLocalizations.
- Etat desactive des boutons signale par la seule Opacity(0.5) (hi_button.dart:21,65), sans Semantics(enabled:false) -> invisible pour les technologies d'assistance et risque de contraste.
- Derive de nommage vs decision verrouillee : entetes/docstrings disent encore 'HYBRID INDEX' (tokens.dart:3, app_theme.dart:4) alors que le score est 'Athlete Index' (le label du ring est correct, index_ring.dart:106, mais pas les commentaires de fichiers).

---

## Gamification (badges, streak, celebrations, result_feedback, endgame) — **7.4/10**

_Backend badges/streak de qualite AAA, reellement defendu contre la flatterie a vide. badges.service.ts:18-25 + :128 bornent les paliers Top X% par effectif (Top 1% exige >=1000 users, Top 5% >=200) -> plus de "Top 1%" mensonger a 20 membres. badges.service.ts:120-153 : grappe de seuils au premier batch attribuee SANS inonder le feed; ensuite UN SEUL post, reserve aux badges epic/legendary (anti-spam reel et bien commente). Attribution idempotente avec gestion P2002 (:131-135) -> pas de double-celebration. streak.service.ts est exemplaire pour une decision verrouillee (§4.6 streak sain) : streak HEBDOMADAIRE (regularite, pas volume), jetons de gel (:86-88) qui protegent une semaine ratee sans en couvrir deux d'affilee, regen +1/4 semaines validees (:95-97), repos planifie (:79-81), garde-fou MAX_CATCHUP_WEEKS=12 contre une boucle infinie apres longue inactivite, le tout idempotent. Cote produit : paliers d'Index calibres sur la courbe display-v2 (badges.data.ts:28-40, pas de <=35 toujours-vrai ni >=100 inatteignable), serie streak jusqu'a 52 semaines bien dosee. Celebrations sans dark pattern : celebration.dart:16/29-34 retrograde une 2e "forte" par session (anti-fatigue dopaminergique), :104-112 respecte reduce-motion (pas de confettis ni pop), auto-fermeture 2.6s sauf si CTA Partager. result_feedback.dart est le point fort UX : 5 paliers compares au temps/score PREDIT, JAMAIS de fanfare sur une contre-perf (:88/95 intensity light -> dialogue calme, pas de confettis), variantes aleatoires i18n, gain plancher a 1% (:57) pour ne jamais afficher "0%". streak_chip.dart : ton non culpabilisant, masque pour compte neuf (:17-18), tooltip+sheet i18n. endgame.service.ts seuils /100 normalises par sexe (equitable H/F)._

### Defauts restants
- i18n CASSE sur le moment dopamine MAXIMAL : wod_result_entry_screen.dart:206 _bandUpText() retourne une chaine FRANCAISE EN DUR ('🚀 Tu entres dans le top X% des plus en forme !'). C'est la celebration FORTE de montee de bande population, la plus importante de l'app, et un utilisateur EN la voit en francais. Aucune cle ARB.
- i18n : wod_result_entry_screen.dart:236 pluralise le sous-titre badge en francais code en dur ('+N autre(s) badge(s)') -> casse en anglais. La logique de pluriel devrait passer par une cle ARB.
- CONFORMITE cahier (verrouille §4.4) : le Grand Chelem est defini comme 'battre le pro reference sur les 15 WODs', l'implementation (wods.service.ts:21 FLAGSHIP_WOD_IDS = 4 WODs ; endgame.service.ts:13-14 seuils fixes 75/90) ne porte que sur 4 epreuves vs des seuils de note, PAS sur 15 WODs ni vs pro reference. Absents aussi du §4.4 : 'top-100 par WOD' et '% vers le record du monde' (cible ultime). Aucune entree decisions-log n'autorise cette reduction de perimetre -> a faire arbitrer/tracer par l'humain.
- FONCTIONNALITE VERROUILLEE INACCESSIBLE : le repos planifie et le reglage d'objectif hebdo (§4.6 'repos planifie maintient la serie', configurable) existent backend (streak.service.ts:27-37, endpoint PATCH engagement.controller.ts:54) et cote client (api_client.dart:282 updateStreak) mais ne sont appeles NULLE PART dans l'UI. La sheet streak_chip.dart est en LECTURE SEULE (aucun bouton). L'utilisateur ne peut donc ni changer son weeklyGoal ni declarer un repos -> la decision verrouillee n'est pas livree au user.
- Etat d'erreur non conforme au correctif ErrorRetry partage : endgame_screen.dart:47 affiche le brut '${snap.error}' (texte technique, pas de bouton Reessayer), au lieu du composant ErrorRetry. Incoherent avec le reste de l'app post-correctifs.
- Etat vide endgame faible : endgame_screen.dart ne distingue pas 'pas encore d'Index/zero phare faite' d'un veritable contenu — le hero affiche 🔒 et 0/4 mais il n'y a pas d'onboarding/CTA explicite pour un compte neuf (pas d'empty state dedie).
- Accessibilite : celebration.dart n'emet AUCUN Semantics/live-region (aucun SemanticsService.announce). Un lecteur d'ecran n'annonce pas le titre/valeur de la celebration plein ecran (badge debloque, montee de bande) -> moment cle muet pour malvoyants. Le CustomPaint confetti n'est pas non plus marque decoratif/ExcludeSemantics.
- Robustesse : badges.service.ts evaluate() est appele en lecture dans listForUser/cardForUser (:159, :183) -> chaque consultation de profil/carte declenche un buildContext lourd (7 requetes Promise.all + 2 count de ligue) et des ecritures userBadge. Pas de cache/debounce -> charge potentielle sur le hot path classement/profil.
- Cosmetiques orphelins : plusieurs badges humanity legendary (badges.data.ts:57-58 humanity-2/-1) n'ont AUCUN cosmeticUnlock, alors que les paliers de ligue equivalents (top-1/top-5) en ont. Incoherence de recompense pour les plus hauts faits.
- Design/engagement : la celebration de badge (wod_result_entry_screen.dart:226-) et la montee de bande s'ENCHAINENT en sequence de dialogues plein ecran apres un seul log (resultat -> bande -> badges). Meme avec la retro-gradation anti-fatigue, c'est jusqu'a 3 modales successives a fermer -> friction sur un moment cense etre fluide.

---

