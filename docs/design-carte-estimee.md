# Carte joueur — état « EN CONSTRUCTION » (Index estimé / radar incomplet)

> Cible : `apps/mobile/lib/features/share/share_card_screen.dart` (`PlayerCard` / `_PlayerCardState`).
> Tokens : `apps/mobile/lib/theme/tokens.dart` (HiColors / HiType / HiSpace / HiRadius / HiMotion).
> Encart sous la carte : `apps/mobile/lib/features/home/grade_block.dart` (`EstimationBlock`).
> Spec de la carte finale (réutilisée comme base) : `docs/design-carte-v2.md`.
> Contrainte : compilable web (dart2js), aucun package lourd, **aucune couleur en dur** (tokens + skins existants).

Ce doc spécifie l'état SPÉCIAL de la `PlayerCard` affiché **tant que l'Athlete Index est
estimé/incomplet** — distinct de la carte finale, désirable (« blueprint scellé », pas
dévalorisant), et orienté progression : « plus que N séances pour révéler ta vraie carte ».

---

## 0. Condition d'activation (une seule source de vérité)

```dart
// Dans _PlayerCardState : dérivé de profile.index (déjà chargé par la carte).
bool get _underConstruction =>
    widget.profile.index.isEstimated || widget.profile.index.radarCoverage < 6;
```

- **Identique** à la condition de l'`EstimationBlock` (`coverage < 6 || isEstimated`) et à celle
  du `home_screen` (l.224) → comportement cohérent partout.
- La carte FINALE (état actuel v2) reste **inchangée** quand `_underConstruction == false`.
  Tout ce qui suit ne s'applique QUE si `_underConstruction == true`.
- `radarCoverage` = nombre d'attributs **réellement mesurés** (0..6). Un attribut « en construction »
  = `RadarAttribute.unlocked == false` **OU** `RadarAttribute.isEstimated == true` (cas Profil
  Express : 6/6 unlocked mais tout estimé → carte encore en construction).

```dart
bool _attrSealed(RadarAttribute? a) => a == null || !a.unlocked || a.isEstimated;
```

---

## 1. Traitement visuel de la carte scellée (« blueprint »)

On **garde la grammaire v2** (border métal, Rajdhani, 3 zones, halo, avatar héros) mais en
version « non encore révélée ». Principe : la carte existe déjà, elle est juste **scellée** —
on voit sa structure (blueprint/hologramme) et elle se « remplit » au fil des séances.

### 1.1 Désaturation maîtrisée du cadre (pas de gris terne)

- Le **skin reste celui du rang** (`_skin`), MAIS on neutralise la flatterie « legendary » :
  en construction on force `legendary = false` localement (pas de halo de carte z9, pas de
  border iridescent élite). Raison : on ne décerne pas l'aura légendaire sur un Index estimé.
  ```dart
  final bool _legendaryEffective = _skin.legendary && !_underConstruction;
  ```
- **Border-gradient** : en construction, remplacer le métal plein par un métal **atténué + trait
  pointillé simulé**. Concrètement, garder `_borderGradient` mais réduire le contraste :
  superposer par-dessus le ClipRRect un **liseré « tireté »** (voir §1.4 ruban) au lieu du
  liseré plein z7. Le z7 plein passe à `skin.frame @ 0.10` (au lieu de 0.18).
- Pas de `_sheen` métallique en boucle : il est **remplacé** par le balayage « scan » (§1.5).

### 1.2 OVR marqué comme estimé (`≈` + label)

Dans `_bandeau` (l.449), bloc OVR haut-gauche :

- **Préfixe `≈`** devant le chiffre quand `_underConstruction`. Le `≈` est rendu en
  `HiType.displayXL.copyWith(fontSize: 40, ...)` (plus petit que le 72 du chiffre), aligné en
  bas, `color: _inkSoft`, `letterSpacing: -2`. Il **ne compte pas** dans le count-up (toujours
  visible, statique).
  ```
  Row(crossAxisAlignment: baseline) : [ ≈ (40, inkSoft) ][ shownOvr (72, métal) ]
  ```
- **Label sous le chiffre** : remplacer `loc.shareCardOvr` par `loc.shareCardOvrEstimated`
  (« NIVEAU ESTIMÉ » / « ESTIMATED LEVEL ») quand en construction. Style inchangé
  (`HiType.overline fontSize 11, color skin.frame @ 0.80`).
- **Pastille « ESTIMÉ »** : à droite du label OVR, micro-chip
  `HiType.overline.copyWith(fontSize: 8, letterSpacing 1.5, color: HiColors.warn)`,
  fond `HiColors.warn @ 0.16`, bord `HiColors.warn @ 0.40`, `BorderRadius.circular(HiRadius.pill)`,
  padding `H 6 / V 2`. Texte `loc.shareCardEstimatedBadge` (« ESTIMÉ »).
  → cohérence avec l'`EstimationBlock` qui utilise déjà `HiColors.warn` comme couleur « estimé ».
- La **barre de grade** (sous l'OVR) reste, mais le remplissage passe en `HiColors.warn`
  (au lieu de `HiGrade.color`) tant qu'en construction → signale « provisoire » sans casser
  la lecture du palier. Le libellé `HiGrade.label` reste affiché mais lui aussi en `warn`.

### 1.3 Mini-barres : mesuré = plein, scellé = verrouillé (cadenas + grisé)

`_statV2` (l.752) reçoit un nouveau paramètre `bool sealed` calculé via `_attrSealed`.

| cas | rendu barre | valeur | abréviation | extra |
|-----|-------------|--------|-------------|-------|
| **mesuré** (`!sealed`) | remplie à `score/100`, couleur `HiColors.attribute(key)` | `$score` couleur normale | normal | progression « se remplit » (cascade existante conservée) |
| **scellé** (`sealed`) | track seul `skin.frame @ 0.12`, **widthFactor 0** | **cadenas** au lieu du chiffre | `HiColors.attrLocked` | overlay tireté léger sur la barre |

Détail du cas scellé :
- **Cadenas** : remplacer le `Text('—')` de droite par
  `Icon(Icons.lock_outline_rounded, size: 13, color: HiColors.attrLocked)` (largeur slot 24 conservée).
- **Abréviation** en `HiColors.attrLocked`, `fontWeight w700` (jamais en avant, jamais « dominant »).
- **Track tireté** : par-dessus le track plein, fines barres verticales `skin.frame @ 0.18`
  espacées (effet « emplacement vide à remplir »). Implémentation simple : `CustomPaint`
  léger OU une `Row` de 8 petits `Container` 2px (web-safe, pas de shader).
- **Aucune valeur estimée n'est jamais affichée en clair** dans la carte scellée : un attribut
  estimé (`isEstimated == true`) est traité comme **scellé** (cadenas), pas comme un score réel.
  → règle produit « pas de fausse flatterie » : on ne montre un chiffre que s'il est vraiment mesuré.

> Conséquence visuelle voulue : la carte montre **les attributs déjà gagnés pleins et colorés**
> (la fierté de ce qui est fait) et **les emplacements restants verrouillés** (la tension de ce
> qui reste à débloquer). C'est la mécanique « collection à compléter ».

### 1.4 Archétype neutralisé tant qu'incomplet

- Tant qu'`_underConstruction`, **forcer** l'archétype sur `loc.archetypeInProgress`
  (« PROFIL EN COURS » / « PROFILE IN PROGRESS »), couleur `HiColors.textTertiary` (neutre).
  Raison : un dominant calculé sur 1–2 attributs mesurés serait trompeur (« LA FORCE » alors
  qu'on n'a fait qu'un WOD de force). On NE révèle l'archétype qu'à la carte finale.
- Pas de pastille de dominant, pas de glow de barre dominante en construction (`highlightKey = null`).

### 1.5 Ruban « EN CONSTRUCTION » (signature de l'état)

Élément le plus reconnaissable. **Ruban diagonal en coin haut-droit** de la carte (au-dessus de
tout, z8), par-dessus l'écusson de ligue qui est alors **masqué** (l'écusson ligue ne s'affiche
qu'en carte finale — éviter de promettre une appartenance ligue avant l'Index complet).

- Bande diagonale à **-45° dans le coin supérieur droit**, largeur ~150px, hauteur ~26px,
  `CustomPaint` ou `Transform.rotate` + `Container` clippé par le `ClipRRect` de la carte.
- Fond : `LinearGradient([HiColors.warn, HiColors.warn @ 0.85])`. Bord 1px `Colors.white @ 0.85`.
  Léger `boxShadow` `HiColors.warn @ 0.40, blur 8`.
- Texte : `loc.shareCardUnderConstruction` (« EN CONSTRUCTION ») en
  `HiType.overline.copyWith(fontSize: 9, letterSpacing 1.5, color: Colors.white)`, centré sur
  la bande. (Couleur de texte blanche = sur fond plein warn, lisible ; c'est le seul blanc
  « sur accent », autorisé comme le `♂/♀` de l'écusson actuel.)
- **Alternative « scan blueprint »** (recommandée EN PLUS du ruban, remplace le sheen métal) :
  une fine ligne horizontale lumineuse `Colors.white @ 0.10` qui balaie la zone héros de haut
  en bas en boucle (réutiliser `_sheen` mais en translation verticale) → sensation « hologramme
  en cours de matérialisation ». Désactivée en `exporting` ET en reduce-motion (statique).

### 1.6 Avatar héros — présent mais « pas encore révélé »

- L'avatar reste affiché (c'est l'identité), MAIS en construction on le rend **légèrement en
  retrait** pour appuyer le « à révéler » : `Opacity(0.92)` + halo réduit (utiliser l'opacité
  de halo du rang `rookie` quel que soit le rang réel : `op = 0.14`, `d = 196`). Pas de pulse.
- Sous l'avatar, **compteur de complétion central** (voir §2) — c'est le call-to-action principal
  ON-card.

---

## 2. Accroche de complétion (sur / sous la carte)

### 2.1 Sur la carte (zone héros, sous l'avatar) — « jauge de révélation »

Au-dessus du socle, dans la zone héros (`_heroScene`), ajouter un bandeau de complétion
**uniquement** en construction :

- **Anneau / jauge de couverture** : réutiliser le motif des `_coverageDots` de l'`EstimationBlock`
  (6 pastilles, `on = i < radarCoverage`, couleur `HiColors.warn` allumé / `HiColors.strokeStrong`
  éteint) — mais en version « carte » : 6 segments d'une barre pill, ou 6 points Ø7.
- **Phrase d'accroche** (la promesse) sous les pastilles :
  - `N = completionPlan.sessions.length` (nombre de séances minimales). Fallback si plan absent :
    `6 - radarCoverage` (attributs restants).
  - `N >= 1` → `loc.shareCardRevealCta(N)` =
    **« Plus que {N} séance(s) pour révéler ta vraie carte »**.
  - `N == 0` mais `isEstimated` (Profil Express) → `loc.shareCardRevealConfirm` =
    **« Confirme tes scores en séance pour figer ta carte »**.
  - Style : `HiType.label.copyWith(color: HiColors.warn, fontWeight w800)`, `textAlign center`,
    `maxLines 2`. Jamais de formulation négative (« ta carte est incomplète/nulle » interdit) :
    toujours orienté **déverrouillage** (« révéler », « débloquer », « ta vraie carte »).

> Le compteur ON-card sert à la **viralité figée** (capture PNG) : même partagée en construction,
> la carte raconte « je suis en train de débloquer mon vrai niveau » — désirable, pas honteux.

### 2.2 Cohérence du N avec l'EstimationBlock

`N` = **même valeur** que celle de l'`EstimationBlock` (`plan.sessions.length`). Les deux lisent
`completionPlanProvider`. Pour éviter toute divergence, la carte lit aussi ce provider :

- `PlayerCard` devient capable de recevoir `completionSessionsCount` (int) en paramètre OPTIONNEL
  fourni par l'appelant (home_screen / share_screen) qui watch déjà le provider — **plus simple
  et plus pur** que de faire de `PlayerCard` un `ConsumerStatefulWidget` (la carte reste un widget
  de présentation, testable hors Riverpod, et la capture PNG reste déterministe).
  ```dart
  // PlayerCard nouveau champ :
  final int? completionSessions; // null hors construction ; sinon = plan.sessions.length
  ```
- Si `completionSessions == null` en construction → fallback `6 - radarCoverage`.

---

## 3. Transition / révélation (Index devient complet)

Quand la **dernière donnée requise** arrive (passage `_underConstruction: true → false`), on
joue une révélation. Détection côté **appelant** (home_screen), pas dans la carte (la carte est
re-construite avec un nouveau `profile`).

### 3.1 Mécanique

- Le `home_screen` (ou un wrapper) compare l'ancien et le nouveau `profile.index` (via un
  `ref.listen(myProfileProvider)` ou un `previous` mémorisé). Transition détectée si
  `wasUnderConstruction && !isUnderConstruction`.
- À la détection :
  1. **Celebration plein écran** (widget existant `apps/mobile/lib/widgets/celebration.dart`) :
     ```dart
     Celebration.show(context,
       title: loc.shareCardRevealedTitle,        // « Ta carte est révélée ! »
       subtitle: loc.shareCardRevealedSubtitle,  // « Ton vrai Athlete Index est débloqué. »
       value: '${profile.index.value}',
       icon: Icons.auto_awesome_rounded,
       accent: HiGrade.color(profile.index.value),
       intensity: CelebrationIntensity.strong);  // 1 seule « strong » / session (anti-fatigue géré)
     ```
  2. La `PlayerCard` se reconstruit en état **final** ; son `_reveal` (1100ms, count-up OVR +
     remplissage des barres) **rejoue** naturellement à la reconstruction → l'OVR grimpe et les
     barres se remplissent jusqu'aux vraies valeurs. C'est la « matérialisation ».
- Le ruban « EN CONSTRUCTION » et les cadenas disparaissent ; l'écusson ligue, l'archétype réel
  et (le cas échéant) l'aura legendary apparaissent.

### 3.2 Reduce-motion (a11y) — IMPÉRATIF

- La carte respecte déjà `MediaQuery.maybeDisableAnimationsOf` (l.289 : `_reveal.value = 1.0`,
  sheen figé). En reduce-motion, la carte finale s'affiche **directement pleine et statique**,
  sans count-up ni scan.
- La `Celebration` : si `disableAnimations`, **ne PAS** ouvrir le plein écran à confettis →
  remplacer par un `SnackBar`/bandeau inline + `HiHaptics.success()`. Le caller (home_screen)
  fait le garde :
  ```dart
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  if (reduce) { showSnackBar(loc.shareCardRevealedTitle); }
  else { Celebration.show(...); }
  ```
- Le **scan blueprint** (§1.5) et le **pulse** : désactivés en reduce-motion ET en `exporting`
  (déjà la convention de la carte).

---

## 4. Rapport avec l'EstimationBlock (sous la carte)

L'`EstimationBlock` (`grade_block.dart`) **reste** : c'est la **liste d'ACTION cliquable**
(séances → fiche WOD), la carte ne peut pas l'être (elle est capturée en PNG, non interactive).
On évite la redondance par une **répartition claire des rôles** :

| Élément | Carte (PlayerCard, en construction) | EstimationBlock (sous la carte) |
|---------|-------------------------------------|---------------------------------|
| Statut « estimé » | OVR `≈` + pastille ESTIMÉ + ruban | titre « Index estimé / Presque ton vrai Index » |
| Compteur N | accroche « plus que N pour révéler » (motivation) | « Complète ces N séances » (intro de liste) |
| Couverture 6 attrs | 6 points sur la carte | `_coverageDots` (conservés) |
| **Liste de séances** | ❌ (jamais — non cliquable en PNG) | ✅ **rôle exclusif** (clic → `WodDetailScreen`) |

Ajustements pour « se sentir connecté » (sans dupliquer) :

1. **Titre de l'EstimationBlock** : conservé, mais l'icône passe de `Icons.auto_graph` à
   `Icons.construction_rounded` pour faire écho au ruban de la carte (même métaphore).
2. **Phrase d'intro** (`gradeCompletePrefix/Many/Suffix`) : conservée — elle introduit la LISTE
   (rôle action). La carte porte la phrase ÉMOTIONNELLE (« révéler ta vraie carte ») ;
   l'EstimationBlock porte la phrase OPÉRATIONNELLE (« complète ces séances : »). Pas de doublon
   textuel mot pour mot.
3. **Continuité visuelle** : l'EstimationBlock garde son cadre `HiColors.warn @ 0.10` + bord
   `warn @ 0.28` → même famille chromatique que la pastille ESTIMÉ et le ruban de la carte.
   → l'ensemble carte + encart se lit comme **un seul module « en construction »**.
4. Quand `N == 0` & non estimé → l'EstimationBlock se masque (déjà le cas : `SizedBox.shrink`) ;
   la carte n'est alors plus en construction non plus. Cohérent.

**Décision** : EstimationBlock **conservé tel quel** dans sa structure (liste d'action), avec
les 2 retouches mineures ci-dessus (icône `construction_rounded`). Pas de refonte.

---

## 5. États, a11y, i18n

### 5.1 États (chargement / données / vide)

- **Chargement profil** : géré par l'appelant (`myProfileProvider.when(loading: HiSkeleton…)`,
  l.92 / l.214). La carte ne se construit qu'avec un `profile` non-null. Rien à ajouter.
- **completionPlan en chargement/erreur** : l'`EstimationBlock` gère déjà (loading/error/data).
  Pour la carte, `completionSessions` peut être `null` pendant le chargement → fallback
  `6 - radarCoverage` (jamais d'écran cassé, l'accroche affiche un N plausible). À l'arrivée du
  plan, l'appelant repasse la vraie valeur → la carte se met à jour.
- **Couverture 0** (aucun attribut, juste après onboarding sans séance) : carte entièrement
  scellée (6 cadenas), accroche `shareCardRevealCta(N)` avec N = plan ou 6. Pas d'OVR `≈ 0` :
  si `idx.value == 0`, afficher `≈ —` (tiret) plutôt que `≈ 0` (un 0 serait dévalorisant).

### 5.2 Accessibilité (Semantics)

La carte porte déjà un `Semantics(label: …, container: true)` + `ExcludeSemantics` sur le visuel
(l.341). En construction, **remplacer le label** par un résumé dédié :

```dart
final semanticsLabel = _underConstruction
    ? loc.shareCardA11yUnderConstruction(cardName, idx.value, n /* séances restantes */, idx.radarCoverage)
    : loc.shareCardA11y(cardName, idx.value, archLabel);
```

- Libellé attendu (FR) : « Carte de {name} en construction. Niveau estimé {ovr}.
  {N} séance(s) restante(s) pour révéler ta vraie carte. {coverage} attributs sur 6 mesurés. »
- Le ruban, les cadenas et le scan sont **décoratifs** → restent sous `ExcludeSemantics`
  (le résumé container suffit, pas de double annonce).
- L'`EstimationBlock` garde ses `Semantics` (titre `gradeA11y`, lignes `gradeSessionA11y`).

### 5.3 Clés i18n à créer (FR + EN)

Ajouter dans `app_fr.arb`, `app_en.arb`, et déclarer dans `app_localizations.dart` (+ `_fr` / `_en`).
Suivre le style existant (clés `shareCard*` regroupées vers l.600 FR / l.1000 EN).

| Clé | FR | EN | Notes |
|-----|----|----|-------|
| `shareCardOvrEstimated` | `NIVEAU ESTIMÉ` | `ESTIMATED LEVEL` | label sous l'OVR |
| `shareCardEstimatedBadge` | `ESTIMÉ` | `ESTIMATED` | pastille |
| `shareCardUnderConstruction` | `EN CONSTRUCTION` | `IN PROGRESS` | ruban |
| `archetypeInProgress` | `PROFIL EN COURS` | `PROFILE IN PROGRESS` | archétype neutre |
| `shareCardRevealCta` | `Plus que {n, plural, one{1 séance} other{{n} séances}} pour révéler ta vraie carte` | `{n, plural, one{1 session} other{{n} sessions}} left to reveal your real card` | accroche on-card ; placeholder `n` (int) |
| `shareCardRevealConfirm` | `Confirme tes scores en séance pour figer ta carte` | `Log real sessions to lock in your card` | cas Profil Express (N=0, estimé) |
| `shareCardRevealedTitle` | `Ta carte est révélée !` | `Your card is revealed!` | Celebration |
| `shareCardRevealedSubtitle` | `Ton vrai Athlete Index est débloqué.` | `Your real Athlete Index is unlocked.` | Celebration |
| `shareCardA11yUnderConstruction` | `Carte de {name} en construction. Niveau estimé {ovr}. {n, plural, =0{Confirme tes scores pour la figer.} one{1 séance restante pour révéler ta vraie carte.} other{{n} séances restantes pour révéler ta vraie carte.}} {coverage} attributs sur 6 mesurés.` | `{name}'s card in progress. Estimated level {ovr}. {n, plural, =0{Log real sessions to lock it in.} one{1 session left to reveal your real card.} other{{n} sessions left to reveal your real card.}} {coverage} of 6 attributes measured.` | placeholders `name`(String), `ovr`(int), `n`(int), `coverage`(int) |

> Déclarer les `@clé` avec `placeholders` typés pour les clés à plural/nombre (cf. `@gradeA11y`,
> `@gradeCompleteSessionMany` existants comme modèle).

---

## 6. Tokens utilisés (rappel — aucune couleur en dur)

- « Estimé / en construction » : `HiColors.warn` (+ alphas 0.10 / 0.16 / 0.28 / 0.40 / 0.85).
- Verrou attribut : `HiColors.attrLocked` ; track : `skin.frame @ 0.12` ; tirets : `skin.frame @ 0.18`.
- Archétype neutre : `HiColors.textTertiary`. Points couverture : `HiColors.warn` / `HiColors.strokeStrong`.
- Métal / fond / halo : skins existants (`_skin.frame`, `_skin.metal`, halo rang `rookie`).
- Grade révélé (Celebration accent) : `HiGrade.color(value)`.
- Typo : `HiType.displayXL` (OVR + `≈`), `HiType.overline` (labels/ruban/pastille),
  `HiType.label` (accroche), `HiType.numericM` (valeurs mesurées).
- Espacements/rayons : `HiSpace.*`, `HiRadius.pill / sm / md / xl`. Motion : `HiMotion` + courbes
  `Curves.easeOutExpo` (count-up) / `easeOutCubic` (entrée) déjà utilisées par `_reveal`.

---

## 7. Checklist d'implémentation (ordre conseillé)

1. `PlayerCard` : ajouter `_underConstruction`, `_attrSealed`, le champ `completionSessions`
   (optionnel) ; le câbler depuis `home_screen` et `share_card_screen` (les deux watch déjà
   `completionPlanProvider` / peuvent l'ajouter).
2. `_bandeau` : OVR `≈`/`—`, label `shareCardOvrEstimated`, pastille `ESTIMÉ`, barre de grade en `warn` ;
   masquer l'écusson ligue en construction.
3. `_statV2` : paramètre `sealed` → cadenas + track tireté + `attrLocked` ; archétype forcé `inProgress`.
4. Ruban « EN CONSTRUCTION » (z8) + scan vertical (reduce-motion / exporting aware).
5. Accroche on-card (jauge 6 points + `shareCardRevealCta`/`shareCardRevealConfirm`) dans `_heroScene`.
6. `Semantics` : brancher `shareCardA11yUnderConstruction`.
7. `home_screen` : `ref.listen(myProfileProvider)` → détection transition → `Celebration.show`
   (garde reduce-motion). EstimationBlock : icône `construction_rounded`.
8. i18n : créer les 8 clés FR+EN (+ `@` typés) ; `flutter gen-l10n`.
9. Revue `reviewer` + vérif capture PNG en construction (carte figée propre : ruban + cadenas
   visibles, scan/sheen OFF, OVR `≈` plein) ET capture en finale (inchangée).
```
