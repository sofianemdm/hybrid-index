# Spec UI — Mode Ligue (Athlete League)

> Spec d'écran prête à implémenter. Réutilise STRICTEMENT les tokens et composants existants
> (`theme/tokens.dart`, `widgets/hi_card.dart`, `widgets/hi_button.dart`, `widgets/hi_empty_state.dart`,
> `widgets/hi_skeleton.dart`, `widgets/rank_badge.dart`, `widgets/celebration.dart`, `theme/haptics.dart`).
> Le visuel s'aligne sur `challenge_screen.dart` (WOD imposé + classement) et `leaderboard_screen.dart`
> (lignes de classement, ma ligne surlignée). Ton premium/motivant, jamais de dark pattern.

---

## 0. Principe directeur : ne JAMAIS confondre Index et Ligue

C'est LE risque produit. Deux systèmes coexistent, ils doivent être visuellement séparés :

| | **Index** (permanent) | **Points de Ligue** (mensuels) |
|---|---|---|
| Nature | Niveau de l'athlète, /100, type FIFA | Score de compétition du mois |
| Couleur signature | **cyan** (`brandGradient`, anneau, RankBadge grade) | **violet** (`brandSecondary` / `brandSecondaryText`) |
| Durée | cumulatif, ne baisse pas brutalement | **remis à zéro le 1er de chaque mois** |
| Affichage | grade « 70+ », anneau d'Index | « pts » + position du mois |

Règles d'application :
- Tout ce qui touche la Ligue utilise l'accent **violet** (`brandSecondary` / `brandSecondaryText`),
  comme la `RivalCard` existante. On NE met PAS de `RankBadge` de grade sur les lignes Ligue
  (le grade appartient à l'Index — sinon confusion). Sur une ligne Ligue, l'unité est **« pts »**.
- Le mot « points » (Ligue) n'est JAMAIS écrit « Index » ni « OVR ». L'unité visible est toujours « pts ».
- La remise à zéro est rappelée explicitement (libellé du compte à rebours + une ligne dans « mon résumé »).
- L'accent victoire (lime `accentVictory`) reste réservé aux célébrations (inscription, podium), jamais en repos.

---

## 1. Placement dans la navigation

**Reco : sous-écran d'un onglet existant — l'onglet Classement (index 3)**, PAS un 5e onglet.

Motivation :
- La barre est une `CircularNotchedRectangle` à 4 items + FAB central (`home_shell.dart`). Un 5e onglet
  casserait l'équilibre de l'encoche (2 items à gauche / 2 à droite) et la lisibilité des libellés à 10 px.
- La Ligue est conceptuellement un **classement** (compétition mensuelle). Sa place naturelle est à côté
  du classement Index. On évite la dispersion : l'utilisateur trouve « tout ce qui se compare » au même endroit.
- La Ligue est opt-in et peut ne pas avoir de saison active → un onglet permanent qui mène parfois à du vide
  serait frustrant. Un sous-écran promu par une carte gère mieux l'absence de saison.

### Mécanique de placement (deux points d'entrée, cohérents avec l'existant)

1. **Onglet Classement → segment haut « Ligue »**
   En haut de `LeaderboardScreen`, AU-DESSUS des onglets Hommes/Femmes existants, ajouter un
   sélecteur à 2 segments pill (même style que `_tab` du leaderboard) :
   `[ Index ]  [ Ligue ]`.
   - `Index` = la vue actuelle (classement permanent par Index), inchangée.
   - `Ligue` = la nouvelle vue Ligue (cette spec), accent violet quand actif au lieu de `brandGradient` cyan.
   Cela évite une 2e route à découvrir et rend la dualité Index/Ligue immédiatement lisible côte à côte.

2. **Carte d'accroche sur l'Accueil** (réutilise le pattern `ChallengeBanner`)
   Quand une saison est active, afficher sur le Home une carte d'entrée vers la Ligue
   (voir §3, états « pas inscrit » et « WOD à faire »). Tap → ouvre l'onglet Classement sur le segment Ligue
   (`ref.read(homeTabProvider.notifier).state = 3` + un provider `leaderboardSegmentProvider = 'league'`).

### Icône & libellé
- Segment : libellé texte **« Ligue »** (pas d'icône dans le pill, comme les segments existants).
- Carte Accueil : icône `Icons.military_tech_rounded` (médaille/compétition), teinte `brandSecondaryText` (violet)
  pour la distinguer de la `ChallengeBanner` cyan. Overline **« LIGUE DU MOIS »**.

---

## 2. Architecture des données (providers à créer)

Suivre le pattern `FutureProvider.autoDispose` + `apiClientProvider` déjà en place.

```
// data/league_providers.dart (à créer)
leagueSeasonProvider      → ApiClient.leagueSeason()      // GET /v1/league/season/current  → LeagueSeason?
leagueMeProvider          → ApiClient.leagueMe()          // GET /v1/league/me              → LeagueMe
leagueStandingsProvider(sex) → ApiClient.leagueStandings(sex) // GET /v1/league/standings?sex=
// action : ApiClient.leagueEnroll() → POST /v1/league/enroll
```

Méthodes `ApiClient` à ajouter (mêmes conventions que `currentChallenge()` / `leaderboard()` existantes :
`_send('GET'|'POST', path)` + `fromJson`). Modèles à ajouter dans `data/models.dart` :

```
class LeagueSeason {
  final String monthKey;        // "2026-06"
  final String status;          // "open" | ...
  final String divisionTier;
  final DateTime opensAt, closesAt;
  final LeagueWeek? currentWeek;
  final bool enrolled;
}
class LeagueWeek {
  final int weekIndex;
  final String weekKey, wodId, wodName;
  final DateTime opensAt, closesAt;
}
class LeagueStandings {
  final String monthKey, sex;
  final int total;
  final List<LeagueEntry> entries;   // déjà triées, top N
  final LeagueMePosition? me;         // null si jamais classé
}
class LeagueEntry { final int position; final String userId, displayName; final int points; final bool isMe; }
class LeagueMePosition { final int position, points; }
class LeagueMe { final bool enrolled; final String? monthKey; final int points, position, weeksPlayed; }
```

Le `sex` de l'onglet vient de `sessionProvider.sex` (comme leaderboard/challenge). Au lancement,
la Ligue de l'utilisateur = sa ligue de sexe ; on garde tout de même les 2 onglets Hommes/Femmes
pour consulter l'autre ligue (lecture seule), exactement comme le classement Index.

---

## 3. L'écran Ligue — layout section par section

Conteneur : `ListView` avec `padding: EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96)`
(même padding bas que challenge/leaderboard pour dégager la barre + FAB). `RefreshIndicator`
(`color: HiColors.brandPrimary`) qui invalide les 3 providers, comme le leaderboard.

L'écran route selon l'état (voir §4). Voici le layout de l'état nominal **inscrit + classé** :

### A. En-tête saison + compte à rebours fin de mois
`HiHeroCard` avec **gradient violet** (PAS le cyan du challenge, pour séparer Index/Ligue) :
```
gradient: LinearGradient(colors: [
  HiColors.brandSecondary.withValues(alpha: 0.22),
  HiColors.brandPrimary.withValues(alpha: 0.08),
])  // même esprit que RivalCard, plus saturé
```
Contenu :
- Ligne 1 : chip pill `brandSecondary @0.2` overline **« LIGUE · JUIN »** (mois dérivé de `monthKey`)
  + à droite, compte à rebours fin de mois en `caption` w700 :
  `« Remise à zéro dans 6 j »` (réutiliser la logique `_countdown` de `challenge_screen.dart`,
  basée sur `closesAt`). Le mot **« Remise à zéro »** est intentionnel : il rappelle le caractère mensuel.
- Ligne 2 : titre `titleL` (28, w900) **« Ligue du mois »**.
- Ligne 3 : sous-titre `caption` `textSecondary` :
  `« Compétition mensuelle. Chaque semaine, un WOD imposé. Le classement repart à zéro le 1er. »`

### B. Carte WOD imposé de la semaine
Reprend EXACTEMENT le `_hero` + `_whatToDo` du `challenge_screen.dart`, mais en accent violet et avec
un bandeau de synergie. Si `currentWeek == null` → carte « pas de WOD cette semaine » (voir états).

`HiCard` (fond `bgElevated`) contenant :
- Overline `brandSecondaryText` **« WOD DE LA SEMAINE · SEMAINE {weekIndex} »**.
- Titre WOD `titleM` w800 `textPrimary` = `currentWeek.wodName`.
- Compte à rebours de la semaine `caption` `textTertiary` : `« Se termine dans 2 j 4 h »` (basé sur `currentWeek.closesAt`).
- **Bandeau synergie** (le point clé du brief) : un encart `bgElevated2`, radius `sm`, icône
  `Icons.bolt_rounded` cyan + texte :
  **« Une séance, double bénéfice : ce WOD compte aussi pour ton Index. »**
  (icône cyan = clin d'œil assumé à l'Index ; c'est le SEUL endroit où le cyan apparaît dans le bloc Ligue,
  justement parce qu'on parle d'Index.)
- CTA primaire `HiButton(label: 'Faire ce WOD', icon: Icons.play_arrow_rounded)` →
  navigue vers `WodResultEntryScreen(wodId, wodName, scoreType)` comme `_doChallenge`. Au retour `true`,
  invalider `leagueMeProvider` + `leagueStandingsProvider` + déclencher la célébration (§5b).
- Lien secondaire `OutlinedButton.icon(Icons.info_outline_rounded, 'Voir le détail du WOD')` →
  `WodDetailScreen`.

> Un seul point focal : le CTA « Faire ce WOD ». L'en-tête saison est décoratif/informatif, pas un CTA.

### C. Bloc « Mon résumé du mois »
`HiCard`, 3 stats en `Row` (séparateurs `VerticalDivider` `strokeSubtle`), accent violet. Données de `leagueMeProvider` :
```
[  Points        |  Position      |  Semaines jouées  ]
   148 pts          #12 / 240        2
```
- Valeurs en `HiType.numericL` (Rajdhani tabulaire) `textPrimary` ; l'unité « pts » en `caption` `textSecondary`.
- Libellés en `overline` `textTertiary` : **« POINTS »**, **« POSITION »**, **« SEMAINES »**.
- La position s'écrit `#12` avec `/240` (total) en `caption textTertiary` à côté.
- Sous la Row, une `caption` `textTertiary` discrète :
  **« Tes points repartent de zéro chaque mois. Ton Index, lui, reste acquis. »**
  (rappel honnête de la dualité, exactement le piège à éviter du brief.)

### D. Sélecteur de ligue (Hommes / Femmes)
Identique à `_tab` du leaderboard, MAIS accent actif = **violet** (`brandSecondary` plein ou
`brandGradientDuo`) au lieu du `brandGradient` cyan, pour rester dans le code couleur Ligue.
`[ Hommes ]  [ Femmes ]`. Par défaut, le sexe de session est présélectionné (logique `_manual` du leaderboard).

### E. Liste du classement mensuel
Titre `titleM` `textPrimary` **« Classement du mois »** + à droite `caption textTertiary` le total :
`« 240 athlètes »`.
Puis la liste, calquée sur `_row` de `leaderboard_screen.dart` mais adaptée Ligue :
- `Container` surligné si `isMe` : `color: brandSecondary @0.12` + `border brandSecondary @0.5`
  (violet, PAS le cyan du leaderboard Index — séparation visuelle).
- Colonne position (largeur 40) : top 3 → `Icons.military_tech_rounded` teinté
  or/argent/bronze (`HiColors.rank('gold'|'silver'|'bronze')`) ; sinon `#{position}` en `numericM` 16
  `textTertiary`.
- Nom : `displayName` (`bodyStrong` si `isMe`, sinon `body`), ellipsis. Si `isMe`, suffixe « (toi) »
  via le helper i18n existant (`leaderboardYou`).
- **PAS de RankBadge** ici (le grade = Index). À la place, valeur à droite : `points` en `numericM`
  `textPrimary` + « pts » en `caption textSecondary`.
- Séparateur : `Divider(height: 1, color: strokeSubtle)`.

### F. Ma ligne « hors top » (si position > taille du top renvoyé)
Si `me != null` mais que `me.position` n'apparaît PAS dans `entries` (au-delà du top affiché, ex. top 50),
afficher SOUS la liste, après un séparateur épais (`Divider(height: 24, thickness: 1)`), un
encart fixe « ma ligne » :
- `Container` `brandSecondary @0.12` + bordure violet, même structure de ligne que E, label
  **« Ta position »** en `overline brandSecondaryText` au-dessus.
- Affiche `#{me.position}` · ton nom · `{me.points} pts`.
- Au-dessus, une `caption textTertiary` centrée : **« … »** (3 points, indiquant la coupure du classement),
  comme le pattern « ma position détachée » des leaderboards AAA.

---

## 4. Tous les états (DoD front)

Routage en tête de build, dans cet ordre. Chaque état est un retour distinct du `ListView`/`Center`.

### 4.1 Chargement (skeleton)
Pendant que `leagueSeasonProvider` est en `loading` (`AsyncValue.loading`), afficher un squelette
calqué sur `HomeSkeleton` :
```
SizedBox(height: HiSpace.lg),
HiSkeleton(height: 120, radius: HiRadius.xl),   // en-tête saison
SizedBox(height: HiSpace.md),
HiSkeleton(height: 160, radius: HiRadius.lg),   // carte WOD
SizedBox(height: HiSpace.md),
HiSkeleton(height: 84,  radius: HiRadius.lg),   // mon résumé
SizedBox(height: HiSpace.lg),
... 8× HiSkeleton(height: 44, radius: HiRadius.sm) séparés de 10  // lignes classement
```
Pas de spinner : on préserve le layout (cohérent avec le reste de l'app).

### 4.2 Erreur (réseau / 500)
Réutiliser le pattern d'erreur du `leaderboard_screen.dart` :
```
Center( Column(
  Icon(Icons.military_tech_rounded, color: textTertiary, size: 40),
  Text('La Ligue est momentanément indisponible.', textAlign center, body/textSecondary),
  TextButton('Réessayer', onPressed: invalider les providers),
))
```
Titre exact : **« La Ligue est momentanément indisponible. »** · CTA **« Réessayer »**.

### 4.3 Aucune saison active (`season == null`)
`HiEmptyState` :
- `icon: Icons.event_busy_rounded`
- `title: « Aucune ligue en ce moment »`
- `message: « La prochaine saison arrive bientôt. Continue à logger tes séances : ton Index, lui, ne s'arrête jamais. »`
- Pas de CTA (ou CTA secondaire « Voir mon Index » qui ramène à l'Accueil — optionnel).
> Honnête : on ne fait pas miroiter une inscription impossible ; on redirige vers la valeur permanente (Index).

### 4.4 Saison active mais PAS inscrit (`season.enrolled == false`) — écran d'accroche
C'est l'écran de conversion. Point focal unique = bouton « Rejoindre la Ligue ».
Layout (`ListView`, pas de `HiEmptyState` ici car on veut riche/vendeur) :

1. `HiHeroCard` gradient violet (comme §3.A) :
   - overline **« NOUVEAU · LIGUE DU MOIS »**
   - titre `titleL` w900 **« Entre dans la Ligue »**
   - sous-titre `body textSecondary` :
     **« Une compétition mensuelle, même WOD pour tous, classée par sexe. Un nouveau défi chaque semaine. »**
2. Trois lignes « bénéfices » (icône cyan/violet + texte), style liste `_whatToDo` :
   - `Icons.calendar_view_week_rounded` — **« 1 WOD imposé par semaine. »**
   - `Icons.leaderboard_rounded` — **« Un classement mensuel dans ta ligue. »**
   - `Icons.bolt_rounded` (cyan) — **« Synergie Index : le WOD de la Ligue compte aussi pour ton Index. Une séance, deux progrès. »**
3. Carte « comment ça marche » (`HiCard`, `caption textSecondary`) :
   **« Le classement repart à zéro chaque mois — tout le monde redémarre à égalité. Ton Index n'est pas affecté. »**
4. CTA primaire `HiButton(label: 'Rejoindre la Ligue', icon: Icons.military_tech_rounded)` → flux §5.
5. Sous le CTA, `caption textTertiary` centré : **« Gratuit · tu peux quitter quand tu veux »** (rassurance, pas de pression).

> Erreur `PROFILE_REQUIRED` à l'enroll → on ne devrait pas atteindre cet écran sans profil, mais
> gérer : SnackBar « Termine ton profil pour rejoindre la Ligue. » + route onboarding.

### 4.5 Inscrit mais 0 point (`enrolled && me.points == 0`)
L'utilisateur a rejoint mais n'a pas encore fait le WOD de la semaine. On NE montre PAS un classement
vide décourageant en point focal. Layout :
- En-tête saison (§3.A) — inchangé.
- Carte WOD de la semaine (§3.B) — c'est le point focal, CTA « Faire ce WOD ».
- Bloc « mon résumé » avec `0 pts`, `Non classé`, `0 semaine` — mais habillé d'un encouragement :
  remplacer la `caption` du bas par : **« Fais le WOD de la semaine pour entrer au classement. »**
  (accent `brandSecondaryText`).
- Classement affiché normalement EN DESSOUS (l'utilisateur peut voir qui mène) ; sa ligne n'y figure
  pas encore → afficher l'encart §3.F en mode « Pas encore classé » :
  `#— · ton nom · 0 pts`, label **« Ta position »**, caption **« Joue le WOD pour apparaître ici. »**

### 4.6 Inscrit avec points (`enrolled && me.points > 0`) — état nominal
Layout complet §3.A → §3.F. Si le WOD de la semaine n'est pas encore fait CETTE semaine
(`me.weeksPlayed < weekIndex`), garder la carte WOD active en haut avec CTA « Faire ce WOD ».
Sinon (déjà joué cette semaine) : la carte WOD passe en état « validé » →
overline **« WOD DE LA SEMAINE · VALIDÉ »**, icône `Icons.check_circle_rounded success`,
CTA remplacé par un `HiButtonSecondary('Revoir le classement')` qui scrolle vers la liste,
+ caption **« Reviens lundi pour le prochain WOD. »**

### 4.7 Hors classement (top dépassé) — voir §3.F
Déjà couvert : `me != null` + position absente de `entries` → encart « Ta position » détaché avec « … ».

### 4.8 Classement vide (saison neuve, personne n'a encore joué)
`entries.isEmpty` mais saison active : sous le titre « Classement du mois », afficher
(comme `challengeBeFirst`) une `body textTertiary` :
**« Personne n'a encore joué ce mois-ci. Sois le premier à marquer des points. »**

---

## 5. Flux d'inscription (opt-in)

### 5a. Confirmation (bottom sheet, pas une modale brutale)
Au tap sur « Rejoindre la Ligue » → `showModalBottomSheet` (radius `HiRadius.xxl`, fond `bgElevated`,
ombre `HiShadow.e3`, drag handle), contenu :
- Titre `titleM` w800 **« Rejoindre la Ligue du mois ? »**
- Corps `body textSecondary` :
  **« Tu seras classé dans la ligue {Hommes/Femmes}. Le WOD de la semaine compte aussi pour ton Index. »**
- Rappel `caption textTertiary` : **« Classement remis à zéro chaque mois. »**
- `HiButton(label: 'Je rejoins', loading: _enrolling)` — passe en `loading` pendant le POST.
- `HiGhostButton('Plus tard')` pour fermer sans pression.

Pendant l'appel : `HiHaptics.tap()` au tap. `POST /v1/league/enroll`.
- Erreur `NO_ACTIVE_SEASON` → fermer + SnackBar « La saison vient de se terminer. » + invalider `leagueSeasonProvider`.
- Erreur `PROFILE_REQUIRED` → fermer + router onboarding (cf. 4.4).
- Erreur réseau → garder le sheet, SnackBar « Connexion perdue. Réessaie. », bouton repasse en idle.

### 5b. Succès — moment de dopamine honnête
Au succès du POST :
1. `HiHaptics.celebrate()` (heavyImpact).
2. Fermer le bottom sheet, invalider `leagueSeasonProvider` + `leagueMeProvider` + `leagueStandingsProvider`
   (l'écran se reconstruit en état 4.5 « inscrit, 0 point »).
3. `Celebration.show(context, intensity: CelebrationIntensity.medium, ...)` :
   ```
   title:    'Bienvenue dans la Ligue 🏆',
   subtitle: 'Fais le WOD de la semaine pour marquer tes premiers points.',
   icon:     Icons.military_tech_rounded,
   accent:   HiColors.brandSecondaryText,        // violet, cohérent Ligue
   actionLabel: 'Faire le WOD',
   onAction: () => push WodResultEntryScreen(currentWeek...),
   )
   ```
   Intensité **medium** (et non strong) : l'inscription est une vraie étape mais pas le sommet — on garde
   le `strong` (lime + confettis maxi) pour la VRAIE victoire (ex. entrer dans le top 3 / podium de fin de mois).
   Confettis de `Celebration` déjà en palette cyan/violet/lime → cohérent.

### 5c. Célébration sur résultat de WOD Ligue (au retour de `WodResultEntryScreen`)
Quand le log fait gagner des points / des places, on peut chaîner (optionnel, P2) :
- Montée de position → `Celebration` medium, accent violet, `« +{n} places ce mois-ci ! »`.
- Entrée dans le top 3 → `Celebration` **strong** (lime, `glowVictory`), `HiHaptics.celebrate()`,
  `« Tu es sur le podium ! »`. C'est le seul moment où le lime sort en Ligue.

---

## 6. Copywriting FR (récapitulatif des chaînes — à mettre en `app_localizations`)

| Clé (suggérée) | Texte FR |
|---|---|
| `leagueSegment` | Ligue |
| `leagueTabIndexSegment` | Index |
| `leagueHomeCardOverline` | LIGUE DU MOIS |
| `leagueSeasonChip(mois)` | LIGUE · {mois} |
| `leagueCountdownReset(d)` | Remise à zéro dans {d} |
| `leagueTitle` | Ligue du mois |
| `leagueSubtitle` | Compétition mensuelle. Chaque semaine, un WOD imposé. Le classement repart à zéro le 1er. |
| `leagueWeekOverline(n)` | WOD DE LA SEMAINE · SEMAINE {n} |
| `leagueWeekValidated` | WOD DE LA SEMAINE · VALIDÉ |
| `leagueSynergy` | Une séance, double bénéfice : ce WOD compte aussi pour ton Index. |
| `leagueDoWod` | Faire ce WOD |
| `leagueWodDetail` | Voir le détail du WOD |
| `leagueWeekDone` | Reviens lundi pour le prochain WOD. |
| `leagueSummaryPoints` | POINTS |
| `leagueSummaryPosition` | POSITION |
| `leagueSummaryWeeks` | SEMAINES |
| `leagueResetReminder` | Tes points repartent de zéro chaque mois. Ton Index, lui, reste acquis. |
| `leagueMen` / `leagueWomen` | Hommes / Femmes |
| `leagueStandingsTitle` | Classement du mois |
| `leagueStandingsCount(n)` | {n} athlètes |
| `leagueMyPositionLabel` | Ta position |
| `leagueNotRankedYet` | Joue le WOD pour apparaître ici. |
| `leagueEmptyStandings` | Personne n'a encore joué ce mois-ci. Sois le premier à marquer des points. |
| `leagueZeroPointsHint` | Fais le WOD de la semaine pour entrer au classement. |
| `leagueNoSeasonTitle` | Aucune ligue en ce moment |
| `leagueNoSeasonBody` | La prochaine saison arrive bientôt. Continue à logger tes séances : ton Index, lui, ne s'arrête jamais. |
| `leagueError` | La Ligue est momentanément indisponible. |
| `leagueRetry` | Réessayer |
| `leagueJoinTitle` | Entre dans la Ligue |
| `leagueJoinSubtitle` | Une compétition mensuelle, même WOD pour tous, classée par sexe. Un nouveau défi chaque semaine. |
| `leagueBenefitWeek` | 1 WOD imposé par semaine. |
| `leagueBenefitRank` | Un classement mensuel dans ta ligue. |
| `leagueBenefitSynergy` | Synergie Index : le WOD de la Ligue compte aussi pour ton Index. Une séance, deux progrès. |
| `leagueHowItWorks` | Le classement repart à zéro chaque mois — tout le monde redémarre à égalité. Ton Index n'est pas affecté. |
| `leagueJoinCta` | Rejoindre la Ligue |
| `leagueJoinReassure` | Gratuit · tu peux quitter quand tu veux |
| `leagueConfirmTitle` | Rejoindre la Ligue du mois ? |
| `leagueConfirmBody(ligue)` | Tu seras classé dans la ligue {ligue}. Le WOD de la semaine compte aussi pour ton Index. |
| `leagueConfirmReset` | Classement remis à zéro chaque mois. |
| `leagueConfirmYes` | Je rejoins |
| `leagueConfirmLater` | Plus tard |
| `leagueWelcomeTitle` | Bienvenue dans la Ligue 🏆 |
| `leagueWelcomeBody` | Fais le WOD de la semaine pour marquer tes premiers points. |
| `leagueWelcomeAction` | Faire le WOD |
| `leaguePodiumTitle` | Tu es sur le podium ! |
| `leagueProfileRequired` | Termine ton profil pour rejoindre la Ligue. |
| `leagueSeasonEnded` | La saison vient de se terminer. |

Ton : direct, tutoiement (cohérent avec `rival_*`, `challenge_*`), motivant, jamais culpabilisant.
Pas de compte à rebours anxiogène, pas de « ne rate pas », pas de faux « il ne reste que… ».

---

## 7. Accessibilité & perf (rappels DoD)
- Cibles tactiles ≥ 44 px (segments, lignes de classement via `InkWell`, CTA `HiButton` = 52 px).
- Contrastes : textes sur gradient violet → `textPrimary`/`textSecondary` validés ; le violet
  `brandSecondaryText` (#A98CFF) sur `bgElevated` passe AA pour du texte non-corps (overline/label).
  Ne PAS écrire de corps long en `brandSecondary` plein sur fond sombre.
- `Semantics` sur les segments (selected/button) comme `_navItem`.
- 60 fps : confettis déjà optimisés (`_ConfettiPainter` existant) ; skeletons au lieu de spinners ;
  `ListView` lazy pour le classement (réutiliser `ListView.separated`).
- `fontFeatures: tabularFigures` (déjà dans `HiType.numericM/L`) → count-up de points sans saut.

---

## 8. Pièges à éviter — checklist de revue
- [ ] Aucun `RankBadge` de grade sur une ligne Ligue (grade = Index uniquement).
- [ ] L'unité Ligue est toujours « pts », jamais « Index »/« OVR ».
- [ ] Accent Ligue = violet partout ; cyan réservé à la mention de synergie Index.
- [ ] Le surlignage « moi » Ligue est violet (≠ surlignage cyan du classement Index) — pour qu'un
      utilisateur qui bascule entre les deux segments voie immédiatement qu'il a changé de système.
- [ ] La remise à zéro mensuelle est rappelée au moins 3 fois (compte à rebours, résumé, accroche).
- [ ] Lime (`accentVictory`) absent en repos ; uniquement podium / célébration strong.
- [ ] Tous les états gérés (vide saison / pas inscrit / 0 pt / classé / hors-top / chargement / erreur).
- [ ] `intensity: medium` à l'inscription, `strong` réservé au podium.
