# Carte de joueur partageable — v2 AAA (spec d'implémentation)

> Cible : `apps/mobile/lib/features/share/share_card_screen.dart` (`_Card` / `_CardState`).
> Tokens : `apps/mobile/lib/theme/tokens.dart`. Avatar : `apps/mobile/lib/widgets/hi_avatar.dart`.
> Contrainte : compilable web (dart2js), aucun package lourd, QR différé (espace réservé).
> Toutes les couleurs viennent de `HiColors` / des skins existants (`_skins`).

Ce doc remplace la composition actuelle (Column + `Spacer()` + header Row avatar 84px collé en
haut à droite). On passe d'une fiche « formulaire » à une **carte trophée** type FIFA Ultimate
Team / NBA 2K : avatar héros centré, OVR en métal Rajdhani, archétype, badges, branding.

---

## 0. Constantes de référence (à ajouter en tête de `_CardState`)

```dart
// ─── Dimensions carte v2 ───
static const double _kCardW = 360;   // largeur logique de rendu
static const double _kCardH = 504;   // ratio 0.714 (360/504), proche carte à jouer 0.70
static const double _kBorder = 2;    // épaisseur du faux border-gradient métallique
static const double _kPad = 18;      // marge intérieure horizontale du contenu

// ─── Hauteurs des 3 zones (somme = _kCardH) ───
static const double _kBandH = 132;   // bandeau haut (OVR + grade + écusson ligue)
static const double _kHeroH = 214;   // scène héros (avatar + halo + vignette)
static const double _kSocleH = 158;  // socle bas (nom + archétype + stats + badges + footer)
```

Le rendu reste **fixe en pixels logiques** (comme l'actuel 340×453) puis est mis à l'échelle
par le parent et capturé via `RepaintBoundary` pour l'export PNG. Ne pas rendre responsive
l'intérieur de la carte : un layout fixe garantit un PNG identique sur tous les appareils.

> **Implémenté (écart assumé vs spec ci-dessus)** : carte **360×540** (au lieu de 504), bandeau
> **128** fixe, **héros en `Expanded`** (absorbe le reste) et **socle intrinsèque** (`mainAxisSize.min`)
> au lieu de 3 `SizedBox` à hauteur fixe → plus robuste (aucun risque de débordement d'un `SizedBox`
> trop court). La carte est en outre enveloppée dans un `MediaQuery(textScaler: TextScaler.noScaling)`
> pour neutraliser le réglage « grandes polices » de l'OS (gabarit pixel-stable + PNG déterministe).
> Le **grade** est rendu en **barre de progression** sous l'OVR (avec libellé « 70+ » + dégradé vers
> le palier suivant) plutôt qu'en arc — plus lisible sur une carte-snapshot. Le champ `cosmetics` n'est
> pas câblé (pas de source côté `myProfileProvider`) : l'aura vient du **halo de carte (z4)**.

---

## A. Composition en 3 zones + ordre des layers

Carte **360 × 504** (ratio 0.714). `ClipRRect(BorderRadius.circular(HiRadius.xl))` = 32px
au coin, sur le conteneur intérieur. La carte est composée comme un `Stack` plein cadre, avec
une `Column` à 3 zones par-dessus les couches de fond.

### Stack — du fond (z0) vers l'avant (z9)

| z | Layer | Zone | Détail |
|---|-------|------|--------|
| z0 | **Faux border métallique** | full | `Container` extérieur avec `gradient` métal (§F), `padding: EdgeInsets.all(2)`, enfant = carte. |
| z1 | **Fond dégradé de base** | full | `LinearGradient(topLeft→bottomRight, [skin.bgTop, skin.bgBottom])` (existant). |
| z2 | **Motif gravé** | full | `CustomPaint` chevrons/diagonales, opacité 3–5 % (§F). `IgnorePointer`. |
| z3 | **Vignette radiale sombre** | hero | `RadialGradient` centré sur l'avatar, assombrit les bords (§C/§F). |
| z4 | **Halo radial de skin** | hero | `RadialGradient` coloré derrière l'avatar (couleurs par skin, §C). |
| z5 | **Inner top highlight** | full | fin gradient blanc 0→6 % du haut sur ~30 % de hauteur (§F). |
| z6 | **Contenu (Column 3 zones)** | full | bandeau / héros / socle (voir ci-dessous). L'avatar vit ici (z6) au-dessus du halo. |
| z7 | **Liseré intérieur** | full | `Border.all` 1px `skin.frame @ 0.18` collé sous le border-gradient (double-trait premium). |
| z8 | **Sheen diagonal** | full | bande lumineuse animée (§H). Intensité croissante selon rang. `IgnorePointer`. |
| z9 | **Halo de carte (legendary)** | full | `boxShadow` externe coloré sur le conteneur le plus extérieur (diamant/élite). |

> Note layer héros : le **halo (z4)** et la **vignette (z3)** sont des `Positioned` ancrés au
> centre de la zone héros, PAS dans la Column. On les place dans le Stack avant la Column pour
> qu'ils passent derrière l'avatar (qui est dans la Column en z6). Centre du halo =
> `Offset(_kCardW/2, _kBandH + _kHeroH*0.46)` (légèrement au-dessus du centre géométrique
> pour laisser respirer les pieds de l'avatar).

### Column (z6) — 3 zones empilées, hauteurs fixes

```
Column(
  children: [
    SizedBox(height: _kBandH,  child: _bandeau(...)),   // zone 1
    SizedBox(height: _kHeroH,  child: _heroScene(...)),  // zone 2 (l'avatar)
    SizedBox(height: _kSocleH, child: _socle(...)),      // zone 3
  ],
)
```

Aucun `Spacer()` : chaque zone a une hauteur fixe → plus de trou central. Le centrage se fait
DANS chaque zone (Align/Center), pas par espace résiduel.

---

## B. Bandeau haut (zone 1 — hauteur 132)

Layout : `Stack` plein cadre de la zone (`_kBandH`), padding horizontal `_kPad`.

### B.1 Bloc OVR (ancré en haut-gauche)

`Positioned(left: _kPad, top: 14)` → `Column(crossAxisAlignment: start)` :

- **OVR (le héros chiffré)** — `ShaderMask` métal (existant) sur un `Text('$shownOvr')` avec :
  ```dart
  HiType.displayXL.copyWith(fontSize: 72, fontWeight: FontWeight.w700, height: 0.86)
  ```
  → **Rajdhani** (corrige l'audit #4 : l'actuel `TextStyle(fontSize:76, w900)` sans famille
  utilisait Inter). `displayXL` porte déjà `fontFeatures: tabularFigures` (count-up sans saut)
  et `letterSpacing: -1.5`. Garder `fontWeight: w700` (Rajdhani n'a pas de w900 propre ;
  w700 est son bold le plus lourd embarqué). Shader : `SweepGradient(skin.metal)` si élite,
  sinon `LinearGradient(topCenter→bottomCenter, skin.metal)` (existant).
- **Label « OVR »** — directement sous le chiffre, `SizedBox(height: 2)` :
  ```dart
  HiType.overline.copyWith(fontSize: 11, color: skin.frame.withValues(alpha: 0.80))
  ```
  (Rajdhani, letterSpacing 2.5, MAJ). Texte = `loc.shareCardOvr`.

### B.2 Grade en ARC autour de l'OVR (remplace le 3e chip)

Au lieu d'un `RankBadge` chip empilé, le **grade devient un segment/arc** qui ceinture le bloc
OVR — signature visuelle forte type « note encerclée ».

- `CustomPaint` placé derrière/autour du bloc OVR, taille `Size(96, 96)`, centré sur le chiffre.
- Anneau de progression : `Canvas.drawArc`, `strokeWidth: 4`, `StrokeCap.round`.
  - **Track** (fond) : cercle complet `skin.frame.withValues(alpha: 0.16)`.
  - **Valeur** : arc partant de -90° (midi), balayant `2π * fillRatio`.
    `fillRatio = ((idx.value - lower) / 10).clamp(0,1)` où `lower = HiGrade.lowerBound(idx.value)`
    (déjà dans tokens : palier de 10). Couleur = `SweepGradient(skin.metal)` via `Shader` sur
    le `Paint`, sinon `skin.frame` plein. Anime de 0→fillRatio sur la courbe de reveal.
  - **Pastille de grade** : petit disque Ø18 à l'extrémité de l'arc (angle courant), rempli
    `skin.frame`, avec le numéro de palier `HiType.overline.copyWith(fontSize: 9, color: ...)`
    centré (ex « 70 » pour un OVR 76). Optionnel mais recommandé pour la lecture du grade.
- Si `RankBadge` reste souhaité ailleurs (écran principal), on le RETIRE ici : l'arc + l'écusson
  ligue suffisent et désencombrent (corrige l'audit #6 « ligue invisible »).

### B.3 Écusson de LIGUE (ancré en haut-droite)

`Positioned(right: _kPad, top: 12)`. Forme **blason/hexagone bouclier** (distinct du cercle de
rang) pour signaler « division », pas « rang ».

- `CustomPaint` Ø56 dessinant un bouclier (path : largeur 48, hauteur 56, pointe en bas).
- Remplissage : `LinearGradient` de **couleur de division** — INDÉPENDANTE du skin de rang :
  - Ligue Hommes → `HiColors.info` (azur `0xFF6FB3FF`) vers une version 30 % plus sombre.
  - Ligue Femmes → `HiColors.brandSecondary` (violet `0xFF7C5CFF`) vers 30 % plus sombre.
  > Justification : le rang colore déjà tout le cadre/OVR. La ligue doit avoir SA couleur pour
  > être lisible comme appartenance, sinon elle se fond (audit #6).
- Bordure du bouclier : 1.5px blanc `@ 0.85`.
- Contenu : glyphe de sexe `♂` / `♀` en `HiType.numericM.copyWith(fontSize: 20, color: white)`
  centré, + micro-label sous le bouclier `« LIGUE H »` / `« LIGUE F »` en
  `HiType.overline.copyWith(fontSize: 8, letterSpacing: 1.5, color: white @ 0.75)`.
- Légère ombre portée : `BoxShadow(color: division @ 0.45, blur: 12, spread: -2)`.

---

## C. Scène héros (zone 2 — hauteur 214)

Centre de gravité de la carte. L'avatar devient le **point focal unique** (audit #1, #2).

### C.1 Avatar

- Taille : **`size: 156`** (fourchette 140–170 ; 156 équilibre présence vs place pour le halo).
- `HiAvatar(config: avatar, rank: idx.rank, size: 156, cosmetics: widget.cosmetics)`
  - **IMPORTANT** : passer `cosmetics` (ajouter le champ à `_Card` ; aujourd'hui `_avatar()`
    n'envoie PAS `cosmetics` → aura jamais rendue dans la carte). C'est le canal d'aura/glow
    (cf. `hi_avatar.dart` : `glow = cosmetics.aura.color`, et `_AvatarPainter` peint l'aura/la
    couronne si `cosmetics.ids.isNotEmpty`, sinon repli rang diamond/elite).
  - Si `cosmetics == null`, l'avatar retombe sur l'aura historique par rang (diamant/élite) :
    comportement voulu, ne rien forcer.
- Centrage : `Align(alignment: Alignment(0, -0.08))` dans la zone (légèrement haut).
- Fallback initiales : garder, mais **agrandir** à Ø132 avec `BorderRadius.circular(HiRadius.xl)`
  et initiales `HiType.displayL.copyWith(fontSize: 44)` (Rajdhani), bord `skin.frame @ 0.6`.

### C.2 Halo radial coloré par skin (layer z4, derrière l'avatar)

`Positioned` centré sur l'avatar, `Container` Ø `haloD` avec `RadialGradient`. Anime l'opacité
de 0→1 sur le reveal, puis **pulse** lent (§H).

Paramètres PAR SKIN (rayon = diamètre du halo ; couleurs = stops du RadialGradient ;
opacité = alpha du 1er stop) :

| skin | couleur halo (centre) | Ø halo | opacité centre | 2e stop |
|------|----------------------|--------|----------------|---------|
| rookie | `skin.frame` (acier) | 196 | 0.14 | transparent @ 0.62 du rayon |
| bronze | `skin.frame` | 196 | 0.18 | transparent |
| silver | `skin.frame` | 200 | 0.18 | transparent |
| gold | `0xFFFFE27A` (or clair) | 210 | 0.26 | `skin.frame @ 0.10` puis transparent |
| platinum | `0xFFA8F5E6` (jade clair) | 210 | 0.26 | transparent |
| diamond | `0xFFBFE0FF` (azur clair) | 220 | 0.32 | `0xFF6FB3FF @ 0.12` puis transparent |
| elite | `0xFFB98CFF`→`0xFF5FE0C8` | 232 | 0.38 | bi-stop violet/jade puis transparent |

Implémentation générique :
```dart
RadialGradient(
  center: Alignment.center,
  radius: 0.5,
  colors: [haloColor.withValues(alpha: haloOpacity * t), Colors.transparent],
  stops: const [0.0, 1.0],
)
```
Pour élite, halo bi-couleur :
`colors: [violet @0.38*t, jade @0.16*t, Colors.transparent], stops: [0.0, 0.45, 1.0]`.

### C.3 Vignette radiale sombre (layer z3, sous le halo)

Assombrit les bords de la scène pour détacher l'avatar (audit #5 « fond plat »).
`Positioned.fill` sur la zone héros :
```dart
RadialGradient(
  center: Alignment(0, -0.10),
  radius: 0.95,
  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
  stops: const [0.45, 1.0],
)
```
(0.55 en dark ; clamp 0.40 si jamais thème clair activé pour la carte.)

### C.4 Ombre portée + anneau

- **Ombre portée sous l'avatar** : ellipse `Container` Ø largeur 96 × hauteur 16, sous les pieds
  (`Positioned(bottom: 24)`), `BoxShadow(color: Colors.black @ 0.5, blur: 22, spread: 2)` OU
  simple `RadialGradient` noir 0.5→transparent (compatible web, pas de blur coûteux).
- **Anneau de rang** : déjà géré par `HiAvatar` (`Border.all(ringColor, width: size*0.04)` =
  6.2px à 156). Ne pas doubler.

---

## D. Socle bas (zone 3 — hauteur 158)

`Column` (start), padding horizontal `_kPad`, padding bottom 14.

### D.1 Séparateur

Ligne 1px `skin.frame @ 0.15` en haut du socle (conserve l'existant) + 10px d'air.

### D.2 Bannière de NOM

- Texte = `widget.name` (fallback `loc.shareCardAthlete`), **MAJUSCULES** (`.toUpperCase()`),
  `maxLines: 1`, `overflow: ellipsis`, `textAlign: center`.
- Style : `HiType.titleL.copyWith(fontSize: 22, letterSpacing: 0.4, color: _ink)` (Inter w800).
  Le nom reste en Inter (lisibilité FR, accents) — Rajdhani est réservé aux chiffres/labels.
- Fond optionnel : fine plaque `skin.frame @ 0.08`, `BorderRadius.circular(HiRadius.sm)`,
  padding `H 12 / V 4`, centrée, largeur `min-content` (Wrap/IntrinsicWidth). Donne l'effet
  « plaque gravée » FIFA. Si nom très long → fond pleine largeur.

### D.3 Ligne d'ARCHÉTYPE

Sous le nom, `SizedBox(height: 3)`, `textAlign: center` :
- Texte = `_archetype(...)` (cf. §E), **MAJUSCULES**.
- Style : `HiType.overline.copyWith(fontSize: 11, letterSpacing: 2.0, color: domColor)`
  où `domColor = HiColors.attribute(dominantKey)` (teinte l'archétype de la couleur de
  l'attribut dominant → cohérence radar). Rajdhani.
- Préfixe d'un petit losange/point coloré 4px de chaque côté (optionnel), même couleur.

### D.4 Grille de STATS v2 (mini-barres)

Remplace le tableau « abréviation + chiffre » plat (audit #3). 6 attributs en **2 colonnes ×
3 lignes** (ordre actuel conservé : col G `engine/power/muscular_endurance`, col D
`strength/speed/hybrid`).

Chaque cellule `_statV2(key, attr, isDominant)` — **hauteur de ligne 26**, `Row` :

```
[ABBR 30px][barre Expanded h6][valeur 24px right]
```

- **Abréviation** : `HiLabels.attrAbbreviation(key)` (ENG/FOR/PUI/VIT/RES/HYB), largeur fixe 30,
  `HiType.caption.copyWith(fontSize: 10, fontWeight: w700, color: _inkSoft)`.
  > Pictogramme : pas d'icône custom (pas de package). On garde l'abréviation Rajdhania-like
  > via `caption` (Inter) OU `overline` (Rajdhani) — préférer `overline @ fontSize 10` pour
  > l'allure « instrument ».
- **Mini-barre** : `Stack` dans un `Expanded`, marges `H 8` :
  - Track : `Container(height: 6, borderRadius: pill, color: skin.frame @ 0.12)`.
  - Remplissage : `FractionallySizedBox(widthFactor: fill * t)` où `fill = (score/100).clamp(0,1)`,
    `height: 6, borderRadius: pill`, couleur = `HiColors.attribute(key)`.
    Si verrouillé (`!unlocked`) : `widthFactor: 0`, track seul, valeur « — ».
    Léger dégradé sur le fill : `LinearGradient([attrColor, attrColor.withValues(alpha:0.7)])`.
  - **Glow du dominant** : si `isDominant`, ajouter sur le fill
    `boxShadow: [BoxShadow(color: attrColor @ 0.55, blur: 8, spread: 0)]`.
- **Valeur** : `unlocked ? '$score' : '—'`, largeur fixe 24, `textAlign: right`,
  `HiType.numericM.copyWith(fontSize: 16, color: noteColor)` (Rajdhani tabular). Garder la
  logique de `noteColor` existante (≥80 success / ≥60 ink / ≥40 inkSoft / sinon warn ;
  locked = attrLocked). Provisoire (`isEstimated`) → `Opacity(0.7)` (conserver).
- **Mise en avant du dominant** (audit #3) : la cellule dominante reçoit en plus
  - abréviation en `_ink` (au lieu de `_inkSoft`) + `fontWeight w800`,
  - un point coloré 4px à gauche de l'abréviation (`attrColor`),
  - le glow de barre ci-dessus.
  `isDominant = (key == dominantKey)` (le dominant calculé en §E).

Cascade d'apparition : conserver le mécanisme actuel (`_order[key]`, start `0.45 + i*0.06`,
fade + translate 6px). Ajouter le **count-up de la valeur** et l'**animation de remplissage de
barre** sur la même fenêtre (`fill * localT`).

### D.5 Rangée de BADGES

Sous les stats, `SizedBox(height: 8)`, `Row(mainAxisAlignment: center)` de **5 slots**.

- Pastille : Ø28, `BoxShape.circle`. Espacement 10px entre pastilles.
- **Badge possédé** : fond `badge.color @ 0.20`, bord 1.5px `badge.color`, glyphe/initiale
  centré `HiType.overline.copyWith(fontSize: 11, color: badge.color)`.
  - **Rare → glow** : `boxShadow: [BoxShadow(color: badge.color @ 0.6, blur: 10, spread: 0)]`.
- **Slot vide** : fond `skin.frame @ 0.06`, bord 1px `skin.frame @ 0.18` (pointillé simulé via
  alpha faible), pas de glyphe (ou point central `skin.frame @ 0.25`). Grisé, signale « à
  débloquer » → moteur de progression (montre qu'il en manque, dopamine honnête).
- Source : si pas de système de badges branché ici, **réserver les 5 slots vides** (tous grisés)
  pour l'instant et brancher plus tard sur `widget.cosmetics`/badges. Ne pas inventer de faux
  badges remplis (cohérent avec la règle produit « pas de fausse flatterie »).

---

## E. Mapping ARCHÉTYPE (§E — règle + table)

### Règle de calcul

```dart
// 1. Ne considérer que les attributs DÉVERROUILLÉS (sinon « ATHLÈTE HYBRIDE » par défaut).
// 2. dominant = attribut de score max.
// 3. Si l'écart entre le top-1 et le top-2 (parmi les déverrouillés) < 6 points
//    → l'athlète est polyvalent → archétype HYBRIDE, quel que soit le dominant.
// 4. Si < 2 attributs déverrouillés → « ATHLÈTE HYBRIDE » (profil incomplet).
String _dominantKey(...) { /* max score parmi unlocked */ }
bool _isBalanced(...)   { /* (top1 - top2) < 6 */ }
```

- `dominantKey` sert AUSSI à teinter l'archétype (§D.3) et à marquer la cellule dominante (§D.4).
- Seuil d'égalité = **6 points** (sur /100). En dessous, on récompense la polyvalence par le
  label HYBRIDE (cohérent avec l'identité « hybrid index »).

### Table (6 + cas hybride)

| dominant | Couleur (HiColors.attribute) | Archétype (FR, MAJ) |
|----------|------------------------------|---------------------|
| `engine` (Cardio) | attrEngine `0xFFEB7A5E` | **MOTEUR** |
| `strength` (Force) | attrStrength `0xFFEA6389` | **LA FORCE** |
| `power` (Puissance) | attrPower `0xFF9D6CE0` | **EXPLOSIF** |
| `speed` (Vitesse) | attrSpeed `0xFFE6C758` | **VÉLOCITÉ** |
| `muscular_endurance` (Endurance) | attrEndurance `0xFF45D6C0` | **INFATIGABLE** |
| `hybrid` (Hybride) | attrHybrid `0xFF5BD49B` | **TOUT-TERRAIN** |
| *équilibré* (écart < 6) | attrHybrid `0xFF5BD49B` | **ATHLÈTE HYBRIDE** |

```dart
const _archetypeLabel = {
  'engine': 'MOTEUR',
  'strength': 'LA FORCE',
  'power': 'EXPLOSIF',
  'speed': 'VÉLOCITÉ',
  'muscular_endurance': 'INFATIGABLE',
  'hybrid': 'TOUT-TERRAIN',
};
// balanced → 'ATHLÈTE HYBRIDE'
```

> Variantes longues optionnelles si on veut un sous-titre (non requis) :
> engine→« SPÉCIALISTE CARDIO », strength→« MONSTRE DE FORCE », power→« PUISSANCE BRUTE »,
> speed→« FOUDRE », muscular_endurance→« ENDURANCE MUSCULAIRE », hybrid→« POLYVALENT ».

---

## F. Profondeur de fond (§F — params concrets)

### F.1 Vignette
Voir §C.3 (RadialGradient noir 0.55, centré scène). C'est la principale source de profondeur.

### F.2 Motif gravé (layer z2)
`CustomPaint` plein cadre, `IgnorePointer`. Motif **chevrons diagonaux** (lignes parallèles à
-45°) OU fines diagonales :
- `Paint()..color = skin.frame.withValues(alpha: 0.04)..strokeWidth = 1` (opacité 4 %, dans la
  fourchette 3–5 %).
- Espacement 14px, lignes sur toute la diagonale. `Canvas.drawLine` en boucle.
- Élite : opacité 5 % + 2 jeux croisés (effet carbone). Autres rangs : 1 jeu à 3–4 %.
- Coût négligeable en web (lignes vectorielles, pas de shader).

### F.3 Inner top highlight (layer z5)
Reflet haut subtil (lumière du dessus), `Positioned(top:0,left:0,right:0,height: _kCardH*0.30)` :
```dart
LinearGradient(begin: topCenter, end: bottomCenter,
  colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent])
```

### F.4 Bordure métallique en dégradé (faux border-gradient) — layer z0
Flutter n'a pas de `Border` à gradient natif. Technique recommandée (légère, web-safe) :
**conteneur dégradé + padding 2px** = le gradient « déborde » de 2px tout autour → faux border.

```dart
Container(                                   // border-gradient
  decoration: BoxDecoration(
    gradient: _borderGradient(skin),         // métal du skin
    borderRadius: BorderRadius.circular(HiRadius.xl + _kBorder), // 34
    boxShadow: skin.legendary                // halo de carte (z9)
        ? [BoxShadow(color: skin.frame.withValues(alpha: 0.30 * t), blurRadius: 34, spreadRadius: -4)]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: Offset(0, 12))],
  ),
  padding: const EdgeInsets.all(_kBorder),   // 2px → épaisseur du faux-border
  child: ClipRRect(
    borderRadius: BorderRadius.circular(HiRadius.xl), // 32, carte intérieure
    child: /* Stack z1..z8 */,
  ),
)
```

`_borderGradient` :
- Non-élite : `LinearGradient(topLeft→bottomRight, [skin.metal[0], skin.metal.last, skin.metal[0]])`
  (clair → foncé → clair = reflet métal en diagonale).
- Élite : `SweepGradient(center, skin.metal)` (le 4-stops violet→azur→jade→violet existant) →
  bord iridescent legendary. `transform: GradientRotation(t * 6.283)` pour le faire tourner
  lentement (lié au `_sheen`).

Le **liseré intérieur 1px** (z7) se fait avec un `Border.all(skin.frame @ 0.18, width: 1)` sur
le premier enfant du ClipRRect → double-trait (métal extérieur + fin liseré clair) = finition AAA.

---

## G. Branding footer (§G)

Tout en bas de la carte, à l'intérieur du socle (`Positioned(bottom: 10, left/right: _kPad)`),
`Row(spaceBetween)` :

- **Gauche — espace QR réservé** : `SizedBox(width: 34, height: 34)` placeholder (carré arrondi
  `skin.frame @ 0.08`, bord `@ 0.18`, coin 6px). Ne rien dessiner dedans pour l'instant (le QR
  viendra ; aucun package requis maintenant). Un micro-glyphe « ▣ » `@ 0.25` peut suggérer la
  place.
- **Centre/Droite — wordmark** : `Column(end)` :
  - `« ATHLETE LEAGUE »` en `HiType.overline.copyWith(fontSize: 11, letterSpacing: 3.0,
    color: _ink.withValues(alpha: 0.55))` (Rajdhani, MAJ). Discret mais présent (viralité).
  - `@handle` (si dispo) en dessous, `HiType.caption.copyWith(fontSize: 9.5,
    color: _inkSoft.withValues(alpha: 0.7))`. Si pas de handle → ne montrer que le wordmark,
    centré.

> Le wordmark doit rester lisible mais ne JAMAIS concurrencer l'OVR/avatar : opacité 0.55,
> taille 11. Sur skin élite, on peut passer le wordmark en `ShaderMask(skin.metal)` pour la
> touche premium (optionnel).

---

## H. Animations (§H — garder / ajouter, chiffré)

On garde les 2 controllers existants (`_reveal` 1100ms, `_sheen` 2600ms) et on en étend l'usage.
Référence des courbes : `HiMotion` (`enter = easeOutCubic`, `emphasis = easeOutBack`,
`countUp = easeOutExpo`).

### À GARDER
- **Count-up OVR** : `shownOvr = (idx.value * t)` avec `t = Curves.easeOutExpo` (au lieu de
  `easeOutCubic` actuel → meilleure sensation « grimpe puis se pose », c'est `HiMotion.countUp`).
  Durée 1100ms. Tabular figures (déjà via `displayXL`) → pas de tremblement de largeur.
- **Cascade des stats** : conservée (start `0.45 + i*0.06`, fenêtre 0.35, fade + translate 6px).
- **Haptic** : `HapticFeedback.mediumImpact()` à `AnimationStatus.completed` du reveal (conservé).
  Ajouter un `selectionClick()` léger au moment où la barre du **dominant** se remplit (≈ à
  `t == start_dominant + 0.2`) — un seul, pas de spam.

### À AJOUTER
- **Count-up des valeurs de stats** : chaque cellule affiche `(score * localT).round()` où
  `localT = Curves.easeOutExpo.transform(((reveal - start)/0.35).clamp(0,1))`. La barre se
  remplit avec le MÊME `localT` (`widthFactor: fill * localT`). Synchronise chiffre + barre.
- **Sheen sur TOUTES les cartes** (audit #5/#6 : aujourd'hui seulement legendary). Activer
  `_sheen.repeat()` pour tous les rangs, **intensité croissante** via l'alpha de la bande :

  | rang | alpha sheen | période |
  |------|-------------|---------|
  | rookie | 0.03 | 4200ms |
  | bronze | 0.04 | 4000ms |
  | silver | 0.05 | 3800ms |
  | gold | 0.07 | 3400ms |
  | platinum | 0.08 | 3200ms |
  | diamond | 0.10 | 2900ms |
  | elite | 0.13 | 2600ms |

  Reprendre `_sheenLayer` existant (translate -0.5→1.2 de la largeur, `rotate(-0.42)`,
  largeur `w*0.32`) en remplaçant la durée de `_sheen` et l'alpha par la table. **Désactivé en
  `exporting`** (capture figée) — déjà le cas. Pour la période, on peut garder un seul
  controller à 2600ms et moduler la fréquence par un facteur, ou créer le controller avec
  `Duration(milliseconds: periodFor(rank))`.
- **Pulse du halo de l'avatar** : oscillation douce de l'opacité du halo (§C.2) post-reveal :
  ```dart
  final pulse = 0.85 + 0.15 * sin(_sheen.value * 2 * pi); // 0.85↔1.0
  haloOpacity = baseHaloOpacity * t * pulse;
  ```
  Amplitude ±15 %, calé sur `_sheen` (pas de 3e controller). Donne « vie » à l'avatar sans
  distraire. Sur élite, amplitude ±20 %.
- **Apparition des badges** : petite échelle 0.8→1.0 (`easeOutBack`) en cascade après les stats
  (start ≈ 0.85, +0.04 par badge). Slots vides apparaissent en fade simple.
- **Entrée de l'écusson de ligue** : scale 0.6→1.0 `easeOutBack` sur la fenêtre 0.2→0.5 du reveal.

### Budget perf (60 fps, web)
- 2 controllers seulement (`_reveal`, `_sheen`). Pas de `BackdropFilter`/`ImageFiltered` (coûteux
  en dart2js) → ombres via gradients ou `boxShadow` simples uniquement.
- `RepaintBoundary` autour de la carte pour isoler les repaints du sheen/pulse.
- Le motif gravé (z2) et la vignette (z3) sont **statiques** → les sortir de l'`AnimatedBuilder`
  (les construire une fois) ; seuls OVR/stats/halo/sheen sont animés.

---

## Checklist d'implémentation (ordre conseillé)

1. Ajouter le champ `final CosmeticSet? cosmetics;` à `_Card` + le câbler depuis l'appelant, et
   le passer à `HiAvatar` dans la scène héros.
2. Poser les constantes §0 et la coque §A (border-gradient §F.4 + Stack 3 zones).
3. Bandeau §B (OVR Rajdhani 72 + arc de grade + écusson ligue).
4. Scène héros §C (avatar 156, halo par skin, vignette, ombre).
5. Socle §D (nom MAJ, archétype §E, stats v2 mini-barres, badges).
6. Profondeur §F (motif gravé, inner highlight, liseré intérieur).
7. Footer §G (wordmark + slot QR réservé).
8. Animations §H (count-up expo, fill barres, sheen tous rangs, pulse halo).
9. Revue `reviewer` + vérif export PNG (carte figée propre, `exporting == true`).
