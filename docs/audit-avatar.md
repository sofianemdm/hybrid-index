# Audit avatar — Athlete League (ex-HYBRID INDEX)

> Audit factuel basé sur le code réel (juin 2026). Univers visé : athlète hybride, sombre,
> premium, « feel jeu compétitif ». Couleur Index = cyan, Ligue = violet, rangs Bronze→Élite.
> Contrainte verrouillée : avatar créé en 30 s max à l'onboarding, app 100 % gratuite, Flutter pur.

Fichiers audités :
- `apps/mobile/lib/widgets/hi_avatar.dart` (rendu, 281 lignes)
- `apps/mobile/lib/features/avatar/avatar_customizer.dart` (bloc de perso réutilisable)
- `apps/mobile/lib/features/avatar/avatar_editor_screen.dart` (éditeur complet)
- `apps/mobile/lib/features/onboarding/onboarding_screen.dart` (étape 0 = avatar)
- `apps/mobile/lib/data/models.dart` (`AvatarConfig`, l.750+)
- `apps/api/prisma/schema.prisma` (`model Avatar`, l.489)
- `apps/mobile/lib/theme/cosmetics.dart` + `apps/api/src/modules/engagement/badges.data.ts`
- `apps/mobile/lib/theme/tokens.dart` (design system)
- Affichage : `home_screen.dart`, `public_profile_screen.dart`, `share_card_screen.dart`

---

## 1. Analyse complète de l'expérience actuelle

### Parcours de création (écran par écran, factuel)

**Onboarding — étape 0 « avatar »** (`onboarding_screen.dart`, l.26 `_step = 0`, l.186 `_avatarStep()`)
- Titre : « Crée ton avatar » (`onbAvatarTitle`), sous-titre : « Personnalise-le (modifiable à
  tout moment dans les paramètres). » (`onbAvatarSubtitle`, l.158-159).
- Le corps est un `AvatarCustomizer` (l.193) avec, de haut en bas :
  1. **Aperçu** de l'avatar dessiné, taille 150 (`avatar_customizer.dart` l.22).
  2. **Teint** : 8 pastilles de couleur (`AvatarPalettes.skin`).
  3. **Couleur des cheveux** : 8 pastilles (`AvatarPalettes.hair`).
  4. **Coupe** : 6 chips texte — `['Chauve', 'Court', 'Mi-long', 'Long', 'Piquant', 'Afro']`.
  5. **Barbe** : 5 chips texte — `['Aucune', 'Barbe naissante', 'Barbe pleine', 'Bouc', 'Moustache']`.
- Bouton « Continuer ». Aucune étape dédiée au sexe ici (le sexe vit ailleurs dans le flow), donc
  l'avatar est **mono-silhouette** (pas de différenciation homme/femme dans le rendu).
- Valeurs par défaut : `AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1)` (l.27) — un avatar
  générique court/brun s'affiche d'emblée.
- À la validation finale du reveal : `await api.updateAvatar(_avatar)` (l.139) — pas d'écran de
  confirmation, pas de célébration de l'avatar.

**Éditeur complet** (`avatar_editor_screen.dart`)
- Même bloc que l'onboarding + 2 ajouts : **photo de profil** (galerie via `image_picker`,
  l.47-70, redimension 512px, qualité 72, plafond 400 Ko, stockée en data-URL base64) et **Fond**
  (8 pastilles `AvatarPalettes.background`, l.157-162). La photo, si présente, **masque entièrement
  l'avatar dessiné** (`hi_avatar.dart` l.68-81).
- Bouton « Enregistrer mon avatar » → `updateAvatar` → `Navigator.pop()`. Aucun feedback de succès.

### Style graphique réel du rendu (le cœur du sujet)

Tout est **vectoriel, dessiné à la main au `CustomPainter`** (`_AvatarPainter`, l.101-281). Aucun
asset. Concrètement, l'avatar est un **empilement de formes géométriques plates, sans dégradé, sans
ombrage, sans contour** :
- **Tête** : un simple `drawCircle` rempli d'une couleur de peau unie (l.169-170).
- **Buste** : un `RRect` rempli de `brandPrimaryDeep` (cyan foncé), identique pour tous (l.157-161).
- **Cheveux** : un arc demi-cercle (« casquette ») clippé sur la tête (l.227-246) ; le « long » ajoute
  2 `RRect` sur les côtés, le « piquant » 5 triangles, l'« afro » un gros cercle derrière la tête.
- **Yeux** : 2 petits `drawCircle` noirs (l.194-196). **Pas de nez, pas de bouche, pas de sourcils.**
- **Barbe** : un arc bas du visage, ou un `RRect` pour la moustache (l.198-224).
- **Couronne Élite** : un `Path` polygonal doré posé au-dessus de la tête (l.177-191).
- **Aura** : un `drawCircle` flou unique (`MaskFilter.blur`), statique, derrière l'avatar (l.121-140).
- **Cadre de rang** : un anneau `stroke` de la couleur du rang (l.145-151).

Le résultat visuel est celui d'un **pictogramme « bonhomme » plat de niveau wireframe** : une boule de
peau, une frange, deux points pour les yeux, un buste arrondi. C'est lisible comme symbole, mais ce
**n'est pas un personnage** : pas de visage expressif, pas de corps d'athlète, pas de volume, pas de
matière. À 48px dans le header (`home_screen.dart` l.64) il passe pour une icône ; à 150-160px en
plein écran à l'onboarding et dans l'éditeur, **la pauvreté du dessin saute aux yeux** (aplats, arcs
grossiers, yeux qui flottent sans visage).

### Choix proposés

| Axe | Nb d'options | Détail |
|---|---|---|
| Teint | 8 | du clair (`0xFFFFE0BD`) au foncé (`0xFF3D2314`) — couverture correcte |
| Couleur cheveux | 8 | dont fantaisie (violet `0xFF6A4E9C`, vert `0xFF2E8B57`) |
| Coupe | 6 | Chauve, Court, Mi-long, Long, Piquant, Afro |
| Barbe | 5 | Aucune, Naissante, Pleine, Bouc, Moustache |
| Fond | 8 | Neutre, Ardoise, Cyan, Violet, Or, Émeraude, Rubis, Nuit (éditeur uniquement) |
| Photo | — | upload galerie, masque le dessin |

Le modèle DB (`schema.prisma` l.489-499) contient en plus un champ `accessory` (SmallInt, défaut 0)
**jamais exposé ni rendu** : prévu mais mort. `equippedCosmetics` / `unlockedCosmetics` (Json)
existent aussi mais ne pilotent pas l'éditeur.

### Fluidité, lisibilité, émotions

- **Fluidité** : `onChanged` → `setState` direct (`onboarding_screen.dart` l.193,
  `avatar_editor_screen.dart` l.133+). Le repaint est conditionné proprement (`shouldRepaint`,
  l.272-280). C'est **réactif et performant**, mais **0 transition, 0 animation, 0 haptique** : le
  changement est instantané et sec. Aucun `HapticFeedback`, `AnimatedScale`, `Confetti`, son — vérifié
  par recherche (aucune occurrence dans `features/avatar` ni dans l'étape avatar de l'onboarding).
- **Lisibilité** : bonne. Labels clairs en `overline`, pastilles 40px (cible tactile correcte),
  bordure cyan sur la sélection active (`brandPrimary`). Pas de problème d'accessibilité majeur côté
  contrôles (les chips à 32px de haut sont un peu justes pour le pouce, voir §2).
- **Émotions** : **plates**. L'écran ressemble à un formulaire de préférences, pas à une création de
  personnage. Aucun moment de dopamine, aucun « waouh », aucune mise en scène. Le sous-titre («
  modifiable à tout moment dans les paramètres ») **dévalorise** l'acte : il dit en substance « ce
  n'est pas important, tu changeras plus tard ».

### Qualité visuelle, personnalisation, cohérence, temps, plaisir, rétention

- **Qualité visuelle** : faible. Niveau « placeholder fonctionnel », pas « produit premium AAA ».
- **Personnalisation** : superficielle. On change 4-5 paramètres de surface ; impossible d'exprimer
  une **identité d'athlète** (morphologie, tenue, posture, attitude, accessoires sportifs).
- **Cohérence univers sport** : **quasi nulle**. Rien dans l'avatar n'évoque le CrossFit/HYROX/hybride :
  pas de débardeur, pas de short, pas de musculature, pas de chalk, pas d'attitude. Le buste cyan
  générique pourrait être n'importe quelle app.
- **Temps** : la contrainte 30 s est **respectée et même sous-exploitée** (on peut finir en 5 s). Le
  problème n'est pas la lenteur, c'est le **manque de récompense** pour le temps passé.
- **Plaisir** : faible. On ne joue pas, on ne se reconnaît pas, on n'a pas envie de montrer son avatar.
- **Impact rétention** : **négatif/neutre**. Un avatar moche et générique ne crée **aucun attachement**.
  Pire : il est affiché partout (header accueil l.61, profil public l.242, carte de partage l.339,
  classement), donc il **plombe la perception premium de toute l'app** à chaque écran. Les cosmétiques
  de progression (aura, couronne, glow) existent côté data mais sont **invisibles dans l'éditeur** et
  **pas branchés sur l'accueil** (voir §2), donc le levier « améliore ton avatar en progressant » ne
  produit aujourd'hui presque aucune motivation.

---

## 2. Problèmes identifiés (précis et sévères, fichier:ligne)

### Bloquants pour le AAA (rendu)

1. **L'avatar est un pictogramme plat, pas un personnage.** `hi_avatar.dart` l.169-170 (tête =
   `drawCircle` uni), l.157-161 (buste = `RRect` uni). Aplats sans dégradé, sans ombrage, sans
   contour, sans volume. À 150px c'est visiblement pauvre. **C'est LA cause du « c'est moche ».**

2. **Visage sans visage.** Seulement 2 points noirs pour les yeux (l.194-196). **Aucun nez, aucune
   bouche, aucun sourcil, aucune expression.** Un avatar humain sans bouche tombe dans l'« uncanny
   wireframe » : on lit un symbole, pas un individu → zéro attachement.

3. **Cheveux/barbe grossiers.** Les coupes sont des arcs demi-cercle clippés (l.240-245) ; « piquant »
   = 5 triangles isocèles (l.260-268) ; « long » = 2 rectangles arrondis collés (l.250-257). Le rendu
   évoque un croquis, pas une coiffure.

4. **Buste identique pour tous + couleur marque en dur.** `torso = HiColors.brandPrimaryDeep`
   (l.157). Tout le monde a le même torse cyan. Aucune tenue, aucune morphologie, aucun haut/short
   d'athlète → **rien ne dit « sport ».**

5. **Mono-genre.** Le rendu ne tient pas compte du sexe (pourtant central : 2 ligues, score normalisé
   par sexe). La silhouette est unique. Une athlète féminine n'a aucune représentation distincte.

6. **Aura/cosmétiques statiques et sous-exploités.** L'aura est un simple cercle flou fixe (l.121-140).
   `cosmetics.dart` déclare `animated: true` pour les auras diamant/top5/top1 (l.19-21), mais
   `_AvatarPainter` est un `CustomPainter` **statique** : **l'animation déclarée n'est jamais rendue**.
   Le commentaire l.140 le confirme (« Rendu statique »).

7. **Cosmétiques de progression invisibles là où ça compte.** L'accueil (`home_screen.dart` l.61-65)
   et l'éditeur (`avatar_editor_screen.dart` l.102) instancient `HiAvatar` **sans** passer `cosmetics:`.
   Résultat : l'aura/couronne ne s'affichent **que** via le repli rang (`hi_avatar.dart` l.132-140 :
   uniquement diamond/elite) et **seul le profil public** (`public_profile_screen.dart` l.246) montre
   les vrais cosmétiques (`avatar_glow_gold`, `avatar_aura_top5`, `avatar_badge_arsenal`…). Un joueur Or
   ou Top 5 % **ne voit jamais sa récompense sur son propre header** → le levier de rétention est cassé.

8. **Champ `accessory` mort.** `schema.prisma` l.495 (`accessory Int @default(0)`) : prévu, jamais
   exposé dans l'éditeur ni rendu. Dette + promesse non tenue (casque, bandeau, lunettes… absents).

### Friction / expérience

9. **Sous-titre démotivant.** `onbAvatarSubtitle` (l.158-159) : « modifiable à tout moment dans les
   paramètres » → signale que l'étape est secondaire. Pour la rétention, l'avatar doit être **valorisé**,
   pas minimisé.

10. **Zéro dopamine à la création.** Aucune animation d'apparition, aucun haptique au tap d'une option,
    aucun effet « reveal » quand l'avatar se compose, aucune célébration à l'enregistrement
    (`_save` l.72-84 fait juste `pop()`). L'app a pourtant un design system riche en glows/gradients
    (`tokens.dart` `HiShadow.glowBrand`, `gradientBrand`) **non utilisé ici**.

11. **Pas d'aperçu en situation.** On ne voit jamais, pendant la création, à quoi ressemblera l'avatar
    dans sa **carte FIFA**/header avec l'anneau de rang et l'Index. La création est décorrélée de la
    récompense finale.

12. **La photo court-circuite tout l'univers.** L'upload galerie (`avatar_editor_screen.dart` l.47-70)
    remplace intégralement l'avatar stylisé (`hi_avatar.dart` l.68). C'est pratique mais ça **casse la
    direction artistique** : un classement « jeu vidéo » rempli de selfies recadrés perd toute identité.
    (À garder, mais à cadrer : voir plan.)

13. **Chips un peu justes au pouce.** `ChoiceChip` par défaut (~32px de haut) ×6 ×2 lignes ; sur petit
    écran, cibles serrées. Acceptable mais perfectible vu l'exigence pouce-friendly du cahier.

14. **Incohérence de taille de l'aperçu.** Onboarding 150 (`avatar_customizer.dart` l.22), éditeur 160
    (`avatar_editor_screen.dart` l.102), header 48, partage 84, profil grand. Pas un défaut grave, mais
    le rendu plat « tient » mal la montée en taille (plus c'est grand, plus c'est pauvre).

### Cohérence système

15. **Rangs riches, avatar pauvre.** Le design system a 7 rangs avec couleurs premium
    (`tokens.dart` l.196-209 : bronze `0xFFC87E4F`, or `0xFFF3C13A`, diamant `0xFF6FB3FF`, élite
    `0xFFB98CFF`) et des cosmétiques par palier (`badges.data.ts` l.25-27, 43-44, 50-51). **L'avatar ne
    capitalise quasiment pas dessus** : un seul anneau de couleur + une aura optionnelle. Énorme
    potentiel inexploité pour faire « évoluer le personnage » visiblement avec le rang.

---

## 3. Ce qui fonctionne déjà (à conserver / améliorer)

- **Architecture data propre et extensible.** `AvatarConfig` (immutable + `copyWith` + `fromJson`/
  `toJson`, `models.dart` l.750-810), `model Avatar` Prisma avec champs déjà prévus (`accessory`,
  `background`, `equipped/unlockedCosmetics`). On peut enrichir sans casser le contrat API.
- **Système de cosmétiques déjà conçu de bout en bout.** Catalogue Flutter (`cosmetics.dart`) ↔ source
  unique API (`badges.data.ts` `cosmeticUnlock`), priorité d'aura (`_auraPriority` l.28), test garde-fou
  côté backend. **La logique de déblocage existe** — il « suffit » de la rendre belle et visible.
- **Tout-vectoriel = perf + zéro asset.** `CustomPaint` léger, `shouldRepaint` ciblé (l.272-280),
  rendu 60 fps garanti, app légère, pas de dépendance lourde. **C'est la bonne fondation technique** ;
  le problème est la qualité du dessin, pas l'approche.
- **Couverture des teints correcte** (8 tons, clair→très foncé) — inclusif.
- **Cadre de rang + aura déjà câblés** (couleur par rang `HiColors.rank`, anneau, blur) : la
  **plomberie** de la mise en valeur est là.
- **Upload photo robuste** (redimension, compression, plafond 400 Ko, gestion d'erreur, data-URL).
- **Design system premium disponible** (`tokens.dart` : glows, gradients, rangs, attributs colorés) —
  **tout le vocabulaire visuel pour faire du AAA existe**, il n'est juste pas appliqué à l'avatar.
- **Hero animation** déjà posée (`tag: 'me-avatar'`) entre header et éditeur : transition fluide gratuite.

---

## 4. Note sur 10

### 3,5 / 10

**Justification.** La **fondation technique et data est solide (7-8/10)** : vectoriel performant,
modèle extensible, système de cosmétiques conçu de bout en bout, plomberie de rang en place. Mais la
mission ici est l'**expérience et le rendu de l'avatar**, et sur ce terrain c'est **faible** :
- Rendu = pictogramme plat sans visage (ni nez, ni bouche), sans volume, sans tenue, mono-genre → **2/10
  en qualité visuelle perçue**, l'antithèse du « premium feel jeu vidéo ».
- Création = formulaire sans aucune dopamine (0 animation, 0 haptique, 0 célébration, sous-titre
  démotivant) → **3/10 en expérience**.
- Cohérence univers sport = quasi nulle (rien n'évoque l'athlète hybride) → **2/10**.
- Effet rétention/attachement = neutre à négatif (l'avatar plombe la perception premium partout) ;
  les cosmétiques qui devraient motiver sont **invisibles sur l'écran principal** (bug d'intégration
  `home_screen.dart` l.61) → **3/10**.

Le 3,5 (et pas moins) reconnaît que **rien n'est cassé fonctionnellement** et que les **fondations
permettent d'atteindre 9-10 sans refonte data**. Le delta est presque entièrement du **rendu + de la
mise en scène**.

---

## 5. Benchmark mental des meilleures apps

**Ce que font les meilleurs, et où Athlete League décroche.**

- **Apple Fitness / Memoji & Apple Watch** : avatars vectoriels **avec volume** (dégradés doux,
  ombrage, contours, visage expressif). Leçon : même sans 3D, un personnage 2D peut être premium si on
  ajoute **profondeur (gradient + ombre portée), contour, et un vrai visage**. → Athlete League est
  resté au stade « formes plates ».

- **Whoop** : pas d'avatar humain, mais une **identité par la data mise en scène** (anneaux, halos,
  couleurs d'état, animations fluides). Leçon : si on garde un avatar minimaliste, **la scénographie
  (glow, anneau de rang animé, fond réactif) fait le premium**. → Athlete League a les tokens (glows,
  gradients) mais **ne les applique pas** à l'avatar.

- **Strava** : badges, segments, « kudos » — **identité sociale forte**. Leçon : l'avatar/profil doit
  être **désirable à montrer** et **évoluer avec l'effort**. → Les cosmétiques de progression existent
  ici mais sont **invisibles sur le header** → l'envie de progresser pour « débloquer » est neutralisée.

- **Nike Training Club / Nike .SWOOSH** : direction artistique sportive nette (silhouettes, tenues,
  matières). Leçon : un avatar fitness doit **porter le sport** (débardeur, short, attitude). →
  Athlete League a un buste cyan générique, **zéro signal sport**.

- **Jeux AAA avec avatars (NBA 2K, FIFA/EA FC, Fortnite, Apex)** : **carte de joueur** (note + rareté +
  cadre + tenue), **création mise en scène** (tour de podium, lumière, rotation), **déblocables
  désirables** (skins, kits, auras de rang), **célébration** (confettis, son, haptique) à chaque montée.
  Leçon : la création d'avatar est un **moment de jeu**, pas un formulaire ; l'avatar est **le trophée
  vivant** du joueur. → Athlete League a déjà le concept « carte FIFA » et les rangs/auras, mais le
  **personnage au centre n'est pas à la hauteur de son cadre**.

- **Bitmoji / Snapchat, Ready Player Me** : **systèmes par couches** (layers) avec preview live
  ultra-réactif et large bibliothèque. Leçon : un **avatar par couches vectorielles** (peau → corps →
  tenue → tête → cheveux → barbe → accessoire → aura) est **le bon compromis Flutter pur** : riche,
  léger, instantané. → C'est exactement la cible réaliste pour Athlete League (voir §6).

**Synthèse benchmark.** Les meilleurs gagnent sur 4 axes qu'Athlete League rate aujourd'hui :
(1) **profondeur visuelle** (volume/ombrage/contour vs aplats), (2) **identité sport** (tenue/posture vs
buste générique), (3) **mise en scène** (lumière/anneau/glow/animation vs formulaire statique),
(4) **récompense visible et désirable** (cosmétiques de rang affichés partout vs invisibles).

---

## 6. Plan d'amélioration vers 10/10

Objectif : **un avatar « athlète stylisé premium », 100 % Flutter pur (CustomPaint par couches), sans
asset lourd**, qui exprime une identité sportive, évolue avec le rang, et se crée en < 30 s avec
dopamine. On garde la fondation data ; on remplace le rendu et on met en scène.

### 6.1 Style cible : « Athlète vectoriel par couches » (réaliste en Flutter pur)

Conserver le `CustomPainter` mais passer d'un bonhomme à un **personnage en buste stylisé** composé de
**couches dessinées avec profondeur** (chaque couche = `Path` + dégradé + ombre interne légère) :

Ordre de rendu (du fond vers l'avant) :
1. **Fond** : dégradé radial (couleur de fond choisie) au lieu d'un aplat → profondeur immédiate.
2. **Aura de rang** : halo dégradé **animé** (respiration douce) — voir 6.5.
3. **Anneau de rang** : arc épais avec léger dégradé métallique (bronze→or→diamant→élite).
4. **Corps/épaules** : silhouette d'athlète (trapèze épaules large + cou), **dégradé** peau, ombrage
   sous le menton. Deux gabarits selon le sexe (épaules masc. plus larges, fém. plus fines).
5. **Tenue (kit)** : débardeur/brassière d'athlète **coloré** (couleur d'équipe = couleur de ligue
   violet par défaut, ou choix), avec col et bretelles → **LE signal sport** qui manque.
6. **Tête** : ovale (pas un cercle parfait) avec dégradé peau + ombrage des joues → volume.
7. **Visage** : **sourcils + yeux (avec blanc + iris) + nez (trait/ombre) + bouche** (sourire léger).
   C'est le saut qualitatif n°1 : passer de 2 points à un vrai visage.
8. **Cheveux** : `Path` lissés (courbes de Bézier `cubicTo`) au lieu d'arcs, avec mèche/dégradé.
9. **Barbe** : `Path` épousant la mâchoire, dégradé.
10. **Accessoire** (champ `accessory` enfin utilisé) : bandeau, casquette, lunettes de sport, chalk…
11. **Couronne/effets de rang** : couronne or affinée + particules optionnelles (élite).

Tout reste vectoriel (aucun PNG), donc **léger, net à toute taille, 60 fps**. Le gain vient des
**dégradés, ombres internes (`MaskFilter`/`Gradient`), courbes de Bézier, et de la tenue**.

> Alternative si on veut pousser plus loin le rendu sans coder 50 `Path` : intégrer **un set d'assets
> SVG par couches** (rendus via `flutter_svg`) — par ex. une banque type « athlete avatar kit » (têtes,
> coiffures, tenues, accessoires) en SVG monochromes teintables. Coût : dépendance `flutter_svg` +
> design/achat d'un pack SVG cohérent. **Recommandation : commencer en CustomPaint enrichi (zéro
> dépendance), et n'introduire des SVG que si on vise un niveau « illustration » supérieur.**

### 6.2 Choix de personnalisation (élargis mais bornés pour tenir 30 s)

- **Sexe/silhouette** : déjà connu du profil → applique automatiquement le bon gabarit (pas une étape
  en plus).
- **Teint** : garder 8 (OK).
- **Visage** : 3-4 **presets de visage/expression** (déterminé, concentré, sourire, neutre) — léger.
- **Cheveux** : passer à 8-10 coupes redessinées proprement + 8 couleurs.
- **Barbe** : garder 5, redessinées.
- **Tenue (kit)** : 4-6 hauts d'athlète (débardeur, brassière, tee compression, hoodie) × couleur de
  kit (palette de 6, dont couleur de ligue). **Nouveau pilier d'identité.**
- **Accessoire** : 5-6 (aucun, bandeau, casquette, lunettes, chalk, écouteurs) via le champ
  `accessory` existant.
- **Fond** : garder 8 (OK), passer en dégradé radial.
- **Photo** : conserver, mais l'**encadrer dans le style** (anneau de rang + éventuel masque hexagonal
  « carte ») pour ne pas casser la DA ; option « revenir à l'avatar stylisé ».

> Tenir 30 s : ne **pas** tout imposer. Étape onboarding = **4 réglages express** (silhouette auto +
> teint + cheveux + kit) avec **presets « surprends-moi »**. Le reste (barbe, accessoire, fond,
> visage, photo) vit dans l'éditeur complet, **après**.

### 6.3 Rapidité du parcours (≤ 30 s, voir §7 pour le flow détaillé)

- **Pré-rempli intelligent** : silhouette par sexe + un preset aléatoire « athlète » dès l'arrivée
  (l'écran n'est jamais vide/par défaut fade).
- **Bouton « 🎲 Aléatoire / Surprends-moi »** : génère un avatar complet d'un tap (dopamine + zéro
  friction). C'est le raccourci 30 s ultime.
- **Sélecteurs horizontaux à défilement** (carrousels de vignettes) plutôt que `Wrap` de chips :
  plus rapide au pouce, plus « jeu ».
- **Preview en situation** : l'aperçu est montré **dans son cadre de carte** (anneau + place pour
  l'Index), pas isolé.

### 6.4 Animations & micro-interactions

- **Apparition** : à l'ouverture de l'étape, l'avatar **se compose** (couches qui « montent » avec un
  léger `scale`+`fade` séquencé, ~400 ms) → effet « ton athlète prend vie ».
- **À chaque changement d'option** : micro **`AnimatedScale`/pulse** de l'avatar (1.0→1.06→1.0, 120 ms)
  + **`HapticFeedback.selectionClick()`** sur chaque tap. (Aujourd'hui : rien.)
- **Transitions de couleur** : `TweenAnimationBuilder<Color>` pour faire **fondre** le changement de
  teint/cheveux/kit au lieu d'un saut sec.
- **Sélection de vignette** : la vignette active fait un petit **rebond** + glow cyan (`glowBrand`).
- **Aura animée** : remplacer le `CustomPainter` statique par un `AnimationController` (respiration de
  l'opacité/rayon, 2-3 s en boucle) — **honore enfin `animated: true`** déclaré dans `cosmetics.dart`.

### 6.5 Effets de récompense (dopamine honnête)

- **Validation onboarding** : courte séquence « ton athlète est prêt » → l'avatar **se cale dans sa
  carte**, l'anneau de rang **s'allume**, **léger flash + haptique `mediumImpact`**. Pas de confettis
  ici (réservés aux vraies étapes : le reveal d'Index garde la vedette).
- **Déblocage de cosmétique** (montée de rang Or/Diamant/Élite, Top 5 %/1 %, arsenal…) : **moment fort**
  dédié → l'avatar **s'illumine de sa nouvelle aura/couronne** avec animation + haptique + son court,
  carte « Nouveau cosmétique débloqué ». **C'est ça qui crée l'envie d'améliorer l'avatar.**
- **Cohérence transverse** : afficher **les cosmétiques partout** (corriger `home_screen.dart` l.61 et
  `avatar_editor_screen.dart` l.102 pour passer `cosmetics: CosmeticSet(activeCosmetics)`), pas
  seulement sur le profil public.

### 6.6 Preview temps réel

- Aperçu **toujours visible et grand**, dans son **cadre de carte** (anneau de rang + slot Index), mis
  à jour < 16 ms (déjà le cas via `shouldRepaint`).
- **Bascule « voir dans mon classement »** : montrer l'avatar en mini dans une ligne de classement
  fictive → renforce « c'est comme ça que les autres me verront ».

### 6.7 Rareté / déblocables (lier à la progression)

- **3 niveaux de désirabilité** alignés sur la rareté badge existante (`common→legendary`,
  `badges.data.ts`) :
  - **Cosmétiques de base** : tous les kits/coiffures/accessoires de l'éditeur (gratuits, déblocage
    immédiat) — large personnalisation dès J1.
  - **Cosmétiques de rang** (déjà conçus) : `avatar_glow_gold` (Or), `avatar_aura_diamond` (Diamant),
    `avatar_crown_elite` (Élite) → rendre **animés et visibles partout**.
  - **Cosmétiques d'exploit** : `avatar_aura_top5`/`top1` (classement ligue), `avatar_badge_arsenal`
    (15 WODs), `radar_skin_full` (6 attributs) → effets **premium animés** (particules, bi-ton).
- **Vitrine de cosmétiques** dans l'éditeur : montrer les cosmétiques **verrouillés** (grisés + «
  débloqué au rang Or / Top 5 % ») → **objectif visuel** qui tire la rétention (« je veux cette aura »).

### 6.8 Cohérence ligues / badges / rangs / perfs

- **Couleur de ligue** (violet) proposée par défaut comme couleur de kit → l'avatar **porte sa ligue**.
- **Anneau + aura = langage de rang** unifié (mêmes couleurs que `HiColors.rank`).
- **Carte FIFA** : l'avatar enrichi + anneau de rang + Index cyan + cosmétiques = **une vraie player
  card** désirable à partager (`share_card_screen.dart` en bénéficie automatiquement).
- **Évolution dans le temps** : à chaque palier (rang, Top %, arsenal), un **changement visible** sur
  l'avatar → la progression **se voit sur le personnage**, pas seulement dans un chiffre.

### 6.9 Faisabilité (honnête)

- **100 % Flutter pur, zéro asset** pour 6.1→6.8 si on reste en CustomPaint enrichi (Bézier + dégradés
  + ombres + animations). **Aucune promesse de 3D** : on vise le **meilleur 2D stylisé atteignable
  proprement**, ce qui est largement suffisant pour un effet premium (cf. Apple/Bitmoji 2D).
- **Effort principal** = **redessiner les couches** (le `_AvatarPainter`) avec soin + ajouter
  l'animation/haptique. C'est du travail de design-en-code, pas une refonte d'archi.
- **Option SVG** (`flutter_svg` + pack de couches teintables) seulement si on vise un rendu «
  illustration » : à décider plus tard, non bloquant.

---

## 7. Expérience idéale en 30 secondes (flow parfait)

> Contrainte : ~30 s, dopamine honnête, identité d'athlète. 3 écrans/étapes max à l'onboarding.

**Écran 1 — « Forge ton athlète » (0-12 s)**
- L'avatar apparaît **déjà composé** (silhouette du bon sexe + un preset « athlète » aléatoire), au
  centre, **dans son cadre de carte** (anneau de rang Débutant, slot Index vide). Il se **compose en
  ~400 ms** (couches qui montent).
- Titre : **« Forge ton athlète »**. Sous-titre **valorisant** : **« C'est lui qui grimpera le
  classement. »** (remplacer l'actuel « modifiable plus tard »).
- Sous l'avatar, **3 carrousels horizontaux** : Teint · Cheveux · Kit (tenue+couleur). Tap = l'avatar
  **pulse** + **haptique** + couleur qui **fond**.
- Un bouton secondaire **« 🎲 Surprends-moi »** (génère tout d'un tap).
- **Ressenti** : « je crée un perso, pas un formulaire » ; réactif, joueur, sportif.

**Écran 2 — « Détails » (12-22 s, optionnel/skippable)**
- Mêmes carrousels pour **Barbe · Accessoire · Fond** (et accès « Photo »). Bouton **« Passer »** bien
  visible (pour tenir les 30 s).
- Texte : **« Peaufine (ou passe — tu pourras tout changer plus tard). »**
- **Ressenti** : liberté sans obligation ; on peut finir vite.

**Écran 3 — « Ton athlète est prêt » (22-30 s)**
- L'avatar **se cale dans sa carte**, l'**anneau de rang s'allume** (glow cyan/violet), **léger flash +
  haptique `mediumImpact`**, le **nom du joueur** s'inscrit sous la carte.
- Texte : **« Voilà ton athlète. Maintenant, montre ce que tu vaux. »**
- CTA : **« Calculer mon Index »** (enchaîne sur le reveal — qui garde les confettis).
- **Ressenti** : fierté, anticipation ; l'avatar est devenu « le mien » et il a un objectif.

**Résultat final** : en < 30 s, un avatar **reconnaissable, sportif, dans sa carte**, avec une
promesse claire (« il va grimper »). Le vrai feu d'artifice (confettis/son) reste pour le **reveal
d'Index** juste après → on ne brûle pas la dopamine, on l'**escalade**.

---

## 8. Recommandations prioritaires (classées)

### URGENT (ce qui fait passer de « moche » à « crédible »)
- **U1 — Redessiner l'avatar avec profondeur + vrai visage + tenue.** Passer des aplats aux couches
  (dégradés, ombres internes, Bézier), ajouter **nez+bouche+sourcils** et un **kit d'athlète coloré**,
  2 gabarits par sexe. *Effort : élevé. Flutter pur (CustomPaint), zéro asset.* — **LE chantier n°1.**
- **U2 — Brancher les cosmétiques partout.** Passer `cosmetics: CosmeticSet(activeCosmetics)` au
  `HiAvatar` du header (`home_screen.dart` l.61) et de l'éditeur (`avatar_editor_screen.dart` l.102).
  *Effort : faible. Flutter pur.* — Débloque immédiatement le levier rétention déjà payé.
- **U3 — Ajouter haptique + micro-animation de sélection + transitions de couleur** dans
  `AvatarCustomizer`/éditeur. *Effort : faible-moyen. Flutter pur.*
- **U4 — Réécrire la copy de l'étape avatar** (titre « Forge ton athlète », sous-titre valorisant).
  *Effort : faible. Flutter pur.*

### IMPORTANT (identité + récompense)
- **I1 — Aura/cosmétiques animés** (respiration/particules) via `AnimationController` ; honorer
  `animated: true`. *Effort : moyen. Flutter pur.*
- **I2 — Bouton « Surprends-moi »** (preset aléatoire complet). *Effort : faible. Flutter pur.*
- **I3 — Aperçu « dans la carte »** (anneau + slot Index) pendant la création + écran « ton athlète est
  prêt ». *Effort : moyen. Flutter pur.*
- **I4 — Activer le champ `accessory`** (bandeau/casquette/lunettes/chalk) — déjà en DB. *Effort :
  moyen (dessin). Flutter pur.*
- **I5 — Carrousels horizontaux** à la place des `Wrap`/chips (pouce-friendly + feel jeu). *Effort :
  moyen. Flutter pur.*

### BONUS PREMIUM (désir + viralité)
- **B1 — Vitrine de cosmétiques verrouillés** dans l'éditeur (grisés + condition de déblocage) →
  objectif visuel. *Effort : moyen. Flutter pur.*
- **B2 — Moment « Nouveau cosmétique débloqué »** (animation + haptique + son) à la montée de
  rang/exploit. *Effort : moyen. Flutter pur.*
- **B3 — Carte FIFA partageable enrichie** (avatar + rang + Index + cosmétiques + cadre). *Effort :
  moyen. Flutter pur (le squelette `share_card_screen.dart` existe).*
- **B4 — Photo encadrée dans la DA** (anneau de rang + masque carte) au lieu de remplacer toute
  l'identité. *Effort : faible. Flutter pur.*

### LONG TERME (montée en gamme)
- **L1 — Pack d'assets SVG par couches** (`flutter_svg`) pour un rendu « illustration » supérieur, si
  le CustomPaint enrichi ne suffit plus. *Effort : élevé. Nécessite des assets (pack SVG teintable).*
- **L2 — Plus de morphologies / poses / expressions** et kits saisonniers (cosmétiques d'événement).
  *Effort : élevé. Flutter pur ou assets.*
- **L3 — Éditeur avancé** (zoom visage, calques, palettes étendues). *Effort : élevé. Flutter pur.*

---

> ## Quick wins < 1 jour (fort impact / faible coût)
> 1. **U2 — Passer `cosmetics:` au header et à l'éditeur** (`home_screen.dart` l.61,
>    `avatar_editor_screen.dart` l.102) : le joueur voit **enfin** son aura/couronne sur SON écran. ~30 min.
> 2. **U3 — `HapticFeedback.selectionClick()` + `AnimatedScale` pulse** sur chaque tap d'option dans
>    `AvatarCustomizer` : la création « répond » enfin. ~1-2 h.
> 3. **U4 — Copy valorisante** (« Forge ton athlète » / « C'est lui qui grimpera le classement. »)
>    au lieu de « modifiable plus tard ». ~15 min.
> 4. **I2 — Bouton « Surprends-moi »** (preset aléatoire) : dopamine + parcours 30 s instantané. ~1 h.
> 5. **Fond en dégradé radial** + anneau de rang autour de l'aperçu de l'éditeur (utiliser
>    `gradientBrand`/`glowBrand` déjà dans `tokens.dart`) : +premium immédiat sans toucher au personnage. ~1 h.
>
> ## Le seul changement qui compte le plus
> **U1 — Redessiner l'avatar en personnage stylisé avec profondeur, un vrai visage (nez + bouche +
> sourcils) et une tenue d'athlète colorée (kit), en couches CustomPaint.** C'est la **cause racine** du
> « c'est moche » : aucun glow, aucune copy, aucun cosmétique ne sauvera un pictogramme plat sans
> visage affiché sur tous les écrans. Faisable **100 % en Flutter pur, sans asset**. Une fois le
> personnage crédible et sportif, tous les autres leviers (auras de rang, carte FIFA, partage,
> rétention par cosmétiques) prennent enfin toute leur valeur.
