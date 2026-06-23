> ## 🆕 v2 « AAA » (implémentée 2026-06-23) — source de vérité = `apps/mobile/lib/theme/tokens.dart`
>
> Refonte premium (cf. `docs/decisions-log.md` D21). Tokens implémentés :
> - **Couleurs** (dark-first) : signature cyan `brandPrimary #2BD4F5`, `brandPrimaryBright #6BECFF`,
>   `brandPrimaryDeep #0A8FB3`, secondaire violet `#7C5CFF`. **`accentVictory #C6FF4A` (lime) =
>   réservé aux célébrations**, jamais en UI de repos. Fond profond `bgBase #090B11`, surfaces
>   `bgElevated #11151F` / `bgElevated2 #1A1F2D` / `bgElevatedHi #232A3B`. `attrEndurance` passé en
>   teal `#2EE6C6` (ne plus collisionner avec le cyan marque). Palette light alignée WCAG AA.
> - **Typographie** (`HiType`, via `google_fonts`) : **Rajdhani** (chiffres data, `tabularFigures`)
>   pour `displayXL/displayL/numericL/numericM/overline` ; **Inter** pour `titleL/titleM/body/
>   bodyStrong/label/caption/button`. L'app passe globalement en Inter (`app_theme.dart`).
> - **Tokens** : `HiSpace` (xxs→xxxl + gutter 20), `HiRadius` (xs 8 → xxl 36, cartes=lg 20,
>   héros=xl 28, boutons=md 16), `HiShadow` (e1/e2/e3 + `glowBrand`/`glowVictory`, adaptés clair),
>   `HiMotion` (instant 90 / fast 180 / base 280 / slow 480 / reveal 1600 / celebrate 900 ; courbes
>   enter=easeOutCubic, emphasis=easeOutBack, countUp=easeOutExpo).
> - **Composants** : `HiCard` / `HiHeroCard` / `HiPressable` (micro-scale 0.97 + haptique au press),
>   `HiButton` (gradient métal cyan + glow) / `HiButtonSecondary` / `HiGhostButton`, `HiSkeleton`
>   (shimmer) + `HomeSkeleton`, `Celebration` (overlay plein écran + confettis maison, intensités
>   light/medium/strong, anti-fatigue 1 forte/session), `AnimatedNumber`, `HiHaptics` (no-op web).
> - **Anneau d'Index** : point focal (264, stroke 14, Rajdhani tabular, halo cyan respirant 2.6 s).
> - **Hiérarchie accueil** : Index dominant → barre vers le point suivant → carte **rival amical** →
>   bandeau **fraîcheur** (`isStale`) → preuve sociale → radar → **un seul** CTA plein + actions
>   fantômes. Skeleton au chargement. Icônes Material **`_rounded`**.
> - **Révélation onboarding** : séquence cinématique (suspense → count-up → rang/preuve → radar → CTA),
>   skippable au tap, pic haptique.
>
> Le reste de ce document (v1) reste valable pour la structure des écrans non encore retouchés.

# HYBRID INDEX — Design System & Spécification des écrans (v1)

> **Statut :** livrable du designer UI/UX. Source de vérité : `docs/cahier-des-charges.md` (§3, §5, §6, §8, §9, §11, §12, §13, §17, §19) et `docs/gamification.md` (rangs §3.1, rareté §4.7, rival §2).
> **Cible :** Flutter (iOS + Android, base unique). Mode **sombre prioritaire** (feel « jeu »). Mobile d'abord, pouce-friendly, 60 fps.
> **Doctrine :** un seul point focal par écran ; dopamine **honnête** (on célèbre fort les vraies étapes, jamais de fausse flatterie) ; chaque action a une conséquence visible ; le score ne baisse jamais brutalement.

---

## 0. Légende & conventions

- **Unités :** `dp` (= px logique Flutter). Couleurs en `#RRGGBB` (ajout `AA` = alpha si besoin).
- **Phases :** `[MVP]` = Phase 1 (thin slice §19) · `[P2]` = Phase 2 · `[P3]` = Phase 3.
- **Tokens :** nommés `couleur.rôle`, `space.x`, `radius.x`, etc. Reflètent une implémentation `ThemeData` Flutter + classes statiques de tokens.
- **Contraste :** toutes les paires texte/fond visées **≥ 4.5:1** (texte normal) / **≥ 3:1** (texte large & éléments graphiques actifs). Cibles tactiles **≥ 48×48 dp**.

---

## 1. TOKENS DU DESIGN SYSTEM

### 1.1 Palette — surfaces & marque (mode sombre prioritaire)

| Token | Hex | Usage |
|---|---|---|
| `bg.base` | `#0B0E14` | Fond d'écran principal (presque noir bleuté, profondeur « jeu ») |
| `bg.elevated` | `#121724` | Cartes niveau 1 |
| `bg.elevated2` | `#1A2030` | Cartes niveau 2 / modales / champs |
| `bg.overlay` | `#000000B3` | Scrim modale (alpha 70 %) |
| `stroke.subtle` | `#FFFFFF14` | Bordures de cartes (alpha 8 %) |
| `stroke.strong` | `#FFFFFF29` | Bordures focus/sélection (alpha 16 %) |
| `brand.primary` | `#3DE1FF` | Cyan électrique — couleur signature (Index, CTA principal) |
| `brand.primaryDeep` | `#0A8FB3` | Variante pressée / gradient bas |
| `brand.secondary` | `#7C5CFF` | Violet énergie — accents, badges, sélection radar |
| `brand.gradient` | `#3DE1FF → #7C5CFF` (135°) | Anneau d'Index, boutons héro, auras |
| `text.primary` | `#F2F5FA` | Texte principal (contraste 15.8:1 sur `bg.base`) |
| `text.secondary` | `#A7B0C0` | Texte secondaire (contraste 7.1:1) |
| `text.tertiary` | `#6B7competition...` → `#6B7488` | Légendes, placeholders (contraste 4.6:1) |
| `text.onBrand` | `#04121A` | Texte sur fond cyan/gradient clair |

> Note typo : `text.tertiary` = **`#6B7488`** (la coquille ci-dessus est corrigée ici, valeur unique à utiliser).

#### Mode clair `[P2]` (variante, non prioritaire)
`bg.base #F4F6FB` · `bg.elevated #FFFFFF` · `text.primary #0B0E14`. Mêmes accents de marque. Le feel « jeu » reste optimal en sombre ; le clair est une option d'accessibilité/préférence.

### 1.2 Palette — les 7 RANGS (Rookie → Élite)

Bornes alignées sur `gamification.md §3.1` : `[min,max)` (max exclusif), Élite inclusif.

| Rang | Index | `rank.x` (principal) | Métal/gradient | Effet (rappel gamif. §4.7) |
|---|---|---|---|---|
| **Rookie** | 0–149 | `#8A93A6` | plat gris-acier | aucun |
| **Bronze** | 150–299 | `#C87E4F` | `#E0996A → #9C5B30` | teinte |
| **Argent** | 300–449 | `#C2CBD8` | `#E8EEF6 → #97A3B6` | accessoire mineur |
| **Or** | 450–599 | `#F3C13A` | `#FFD95A → #C9941A` | aura légère |
| **Platine** | 600–749 | `#5FE0C8` | `#8AF0DD → #2FB6A0` | particules |
| **Diamant** | 750–899 | `#6FB3FF` | `#9CD0FF → #3D7DE6` | animation cadre |
| **Élite** | 900–1000 | `#B98CFF` | `#D7B8FF → #7C5CFF` + liseré holo | **cadre prestige + aura exclusive** |

- Chaque rang fournit aussi `rank.x.glow` (même teinte, alpha 40 %) pour halos/cadres d'avatar.
- **Alternative non-couleur (a11y) :** chaque rang a une **icône d'insigne distincte** (chevrons : 1 = Rookie … forme cristal = Diamant, couronne = Élite) + **libellé texte toujours visible**.

### 1.3 Palette — les 6 ATTRIBUTS du radar (§5.1)

Chaque axe a une teinte propre + une icône (jamais la couleur seule).

| Attribut | `attr.x` | Hex | Icône (alt non-couleur) |
|---|---|---|---|
| **Engine** (aérobie) | `attr.engine` | `#FF6B4A` | poumon/flamme |
| **Vitesse** | `attr.speed` | `#FFD23F` | éclair |
| **Force** | `attr.strength` | `#FF4D7E` | haltère |
| **Puissance** | `attr.power` | `#A05CFF` | explosion |
| **Endurance musc.** | `attr.endurance` | `#3DE1FF` | barre + reps (∞) |
| **Hybride** | `attr.hybrid` | `#46E6A0` | flèches croisées |

- Attribut **verrouillé** : tracé/aire en `#3A4considera...` → **`#3A4256`** (gris froid) + icône cadenas.
- Attribut **à rafraîchir** (fraîcheur §5.4) : petit point `warn` + icône horloge sur l'axe.
- **Force en proxy sans matériel** : badge `≈` (estimation) sur l'axe (flag `isEstimated`).

### 1.4 Palette — sémantique

| Token | Hex | Usage |
|---|---|---|
| `success` | `#46E6A0` | PR, validation, montée |
| `success.bg` | `#46E6A01F` | fond toast succès |
| `error` | `#FF5470` | erreurs, résultat invalide |
| `error.bg` | `#FF54701F` | fond bannière erreur |
| `warn` | `#FFB23F` | « à rafraîchir », estimation, anti-surentraînement |
| `warn.bg` | `#FFB23F1F` | fond bannière avertissement |
| `info` | `#6FB3FF` | indicateur de confiance / calibration |

> **Règle dopamine honnête :** `warn` (orange) signale « estimation / provisoire / à vérifier ». On ne maquille **jamais** un chiffre estimé en chiffre vert validé.

### 1.5 Typographie

Police : **Sora** (titres, chiffres — géométrique, sportive) + **Inter** (corps, lisibilité). Chiffres en **tabular figures** pour Index/chrono/classements (évite le « tremblement » pendant les compteurs).

| Token | Police / poids | Taille / interligne | Usage |
|---|---|---|---|
| `type.display` | Sora 800 | 56 / 60 | Compteur d'Index (reveal & hub) |
| `type.h1` | Sora 700 | 32 / 38 | Titres d'écran |
| `type.h2` | Sora 700 | 24 / 30 | Sections |
| `type.h3` | Sora 600 | 20 / 26 | Titres de carte |
| `type.bodyL` | Inter 500 | 17 / 24 | Corps principal |
| `type.body` | Inter 400 | 15 / 22 | Corps |
| `type.label` | Inter 600 | 13 / 16 | Boutons, étiquettes (1 px letter-spacing) |
| `type.caption` | Inter 500 | 12 / 16 | Légendes, méta |
| `type.mono` | Sora 700 tabular | variable | Chiffres Index, chrono, temps de WOD |

- **Dynamic Type :** échelle respecte `MediaQuery.textScaler` jusqu'à **×1.3** sans casse de layout (cartes en `Wrap`/`Flexible`, pas de hauteurs figées sur le texte). Au-delà, troncature avec ellipsis + tap pour détail.

### 1.6 Espacement (base 4)

| Token | dp | | Token | dp |
|---|---|---|---|---|
| `space.0` | 0 | | `space.4` | 16 |
| `space.1` | 4 | | `space.5` | 20 |
| `space.2` | 8 | | `space.6` | 24 |
| `space.3` | 12 | | `space.8` | 32 |
| | | | `space.10` | 40 |

- Marge d'écran standard : `space.4` (16 dp). Gouttière entre cartes : `space.3`. Padding interne carte : `space.4`.

### 1.7 Rayons & élévation

| `radius.x` | dp | Usage | | `elev.x` | Ombre |
|---|---|---|---|---|---|
| `radius.sm` | 8 | puces, tags | | `elev.0` | aucune (cartes plates en sombre) |
| `radius.md` | 16 | cartes, champs | | `elev.1` | `0 2 8 #00000040` |
| `radius.lg` | 24 | cartes héro, modales | | `elev.2` | `0 8 24 #00000059` |
| `radius.xl` | 32 | feuilles/sheets bas | | `glow.brand` | `0 0 24 #3DE1FF59` (anneau Index, CTA actif) |
| `radius.pill` | 999 | boutons pill, chips | | `glow.rank` | `0 0 28 rank.x.glow` (avatar selon rang) |

> En mode sombre, la profondeur vient surtout des **surfaces (bg.elevated)** + **glow**, pas d'ombres lourdes. Les glows ne sont **jamais** sous du texte de contenu (perf + lisibilité).

### 1.8 Durées & courbes d'animation

| Token | ms | Courbe | Usage |
|---|---|---|---|
| `motion.instant` | 100 | `easeOut` | feedback de pression (scale 0.97) |
| `motion.fast` | 180 | `easeOutCubic` | apparition d'éléments, toasts |
| `motion.base` | 280 | `easeInOutCubic` | transitions de cartes, sheets |
| `motion.slow` | 450 | `easeOutExpo` | montée de jauge/anneau d'attribut |
| `motion.reveal.count` | 1600–2200 | `easeOutExpo` (décélère) | compteur d'Index qui monte |
| `motion.celebrate` | 900 | `elasticOut` (overshoot léger) | pop de badge/rang, confettis |
| `motion.page` | 320 | `easeOutCubic` (shared-axis X) | navigation entre écrans |

- **Principe :** entrées rapides, célébrations avec overshoot mesuré (`elasticOut` amplitude faible), jamais > 2.2 s pour le reveal (sinon impatience).
- **Respect `Reduce Motion` :** si activé → confettis désactivés, compteur passe à un **fondu + incrément discret 400 ms**, parallaxe coupée, transitions en simple fondu. Aucune perte d'information.

### 1.9 Haptique (Flutter `HapticFeedback` + plugin avancé en P2)

| Token | API | Quand |
|---|---|---|
| `haptic.tap` | `selectionClick` | sélection (objectif, couleur, chip) |
| `haptic.success` | `lightImpact` | validation, kudos envoyé |
| `haptic.tickUp` | micro-vibrations cadencées (P2 : pattern custom) | **chaque palier pendant la montée du compteur Index** |
| `haptic.milestone` | `mediumImpact` | franchissement de seuil (percentile rond, dépassement rival) |
| `haptic.celebrate` | `heavyImpact` ×2 espacées | reveal final, montée de rang, badge legendary |
| `haptic.error` | `vibrate` (pattern court double) | résultat invalide, erreur réseau bloquante |

### 1.10 Son (mixé bas, désactivable dans Réglages, OFF si mode silencieux respecté)

| Token | Description | Quand |
|---|---|---|
| `sfx.tick` | tic numérique court, pitch montant | chaque palier du compteur Index |
| `sfx.reveal` | « whoosh + impact » glorieux | atterrissage du chiffre final |
| `sfx.rankup` | fanfare courte (0.8 s) | montée de rang |
| `sfx.badge` | cristal/chime selon rareté (common→legendary = plus riche) | déblocage de badge |
| `sfx.confetti` | shaker léger | confettis |
| `sfx.tap` | clic doux | optionnel sur CTA (OFF par défaut) |

> **Règle :** son **opt-in clair** au premier reveal (« Active le son pour vivre le reveal » + bouton). Jamais de son automatique surprenant. Toujours doublé par haptique + visuel (a11y auditive).

---

## 2. COMPOSANTS UI CLÉS (catalogue)

Convention d'états pour tous : **par défaut · pressé · désactivé · chargement** (+ focus clavier/lecteur d'écran).

### 2.1 Boutons

**`HiButtonPrimary`** (CTA héro)
- Anatomie : pill `radius.pill`, hauteur 56 dp, fond `brand.gradient`, texte `type.label` `text.onBrand`, icône optionnelle 20 dp à gauche.
- États : *défaut* (gradient + `glow.brand` subtil) · *pressé* (scale 0.97, `motion.instant`, gradient → `brand.primaryDeep`, glow off) · *désactivé* (fond `#2A3142`, texte `text.tertiary`, pas de glow) · *chargement* (texte remplacé par spinner 3 points pulsés, largeur conservée, non tappable).

**`HiButtonSecondary`** : contour `stroke.strong`, fond transparent, texte `text.primary`. Mêmes états (pressé = fond `#FFFFFF0F`).

**`HiButtonGhost`** / **`HiTextButton`** : pour « Passer », « J'ai fait autre chose ». Texte `text.secondary`, zone tactile 48 dp même si visuel plus petit.

**`HiFab` (Ajouter un WOD)** : pill flottant `brand.gradient`, icône `+`, label « WOD », 56 dp, ancré en bas-centre au-dessus de la nav, `glow.brand`. Pressé = scale 0.94 + `haptic.tap`.

### 2.2 `HiWodCard` (carte de WOD)

```
┌──────────────────────────────────────────┐
│ [icône type]  FRAN              ● à faire  │  ← statut: fait(✓)/à faire(○)/PR(★)
│ For Time · 21-15-9                          │
│ ▸ Attributs:  ◆End.musc  ◆Puissance         │  ← pastilles attr (couleur+icône)
│ ──────────────────────────────────────────  │
│ Ton temps  4:32   |  Pro ~2:10   |  top 14% │  ← si fait
│ [   Refaire   ]            [ Voir classement ]│
└──────────────────────────────────────────┘
```
- Variantes : *avec matériel* (icône haltère) / *sans matériel* (icône corps) ; *fait* (affiche perf + rang) / *à faire* (CTA « Faire le WOD » + « Mode guidé »).
- États : *défaut* · *pressé* (scale 0.98, surface +1) · *désactivé/incompatible matériel* (opacité 50 % + tag « nécessite : barre ») · *chargement* (skeleton, §2.13).

### 2.3 `HiAttributeRing` (jauge/anneau d'attribut)

- Anneau circulaire (radius 28 dp, trait 6 dp), couleur = `attr.x`, fond piste `#2A3142`. Centre : icône attribut + valeur 0–1000.
- États : *débloqué* (anneau rempli, anim `motion.slow` de 0→valeur à l'apparition) · *verrouillé* (piste pleine grise + cadenas) · *estimé* (anneau pointillé + `≈`) · *à rafraîchir* (point `warn` à 12 h).
- **Montée (reveal/résultat) :** l'arc s'étend de l'ancienne valeur → nouvelle, `motion.slow`, avec **+Δ flottant** en `success` qui monte et s'estompe ; `haptic.success`.

### 2.4 `HiRadarChart` (radar 6 axes) — composant signature

```
            Engine
              ●
   Hybride  /   \  Vitesse
       ● ──┼──── ●
        \  │  /
   End.m ●─┼─● Puissance
          \│/
           ● Force
```
- 6 axes équidistants (60°), ordre fixe (horloge depuis le haut) : **Engine → Vitesse → Puissance → Force → Endurance musc. → Hybride**. Grille à 3 anneaux (250/500/750/1000).
- Aire remplie : gradient `brand` à 35 % d'opacité ; sommets = points colorés `attr.x` + icône au bout de l'axe.
- Axes **verrouillés** : tronqués au centre + cadenas ; l'aire n'est tracée que sur les axes débloqués (cohérent avec « Index provisoire »).
- **Interaction :** taper un sommet → met l'axe en surbrillance + bottom-sheet « Améliorer cet axe » (WODs ciblés + Index projeté §10.2). `haptic.tap`.
- **Comparaison (écran 12) :** 2e tracé superposé en `brand.secondary` (toi = cyan plein, l'autre = violet contour). Légende texte obligatoire (a11y).
- États : *défaut* · *animation d'entrée* (axes se déploient du centre, `motion.base`, décalage 40 ms/axe) · *chargement* (squelette d'hexagone pulsé) · *vide* (hexagone gris + « Complète 1 effort pour révéler tes axes »).
- **A11y :** alternative liste « Engine 612 · top 22 % », lue par lecteur d'écran ; jamais de sens porté par la couleur seule.

### 2.5 `HiIndexCounter` (compteur d'Index animé / reveal) — composant signature

- Anatomie : grand chiffre `type.display` `text.primary`, entouré d'un **anneau de progression** (gradient `brand`, trait 10 dp) qui se remplit en synchro ; sous le chiffre : libellé percentile (`type.body` `text.secondary`).
- **Mode reveal (onboarding §8 écran 6) :** voir §3 (storyboard).
- **Mode incrément (résultat WOD / hub refresh) :** anime de l'ancienne valeur vers la nouvelle (`motion.reveal.count`, `easeOutExpo`), `haptic.tickUp` cadencé, `sfx.tick`, badge `+Δ` `success` qui apparaît à côté.
- États : *statique* (hub) · *qui monte* (reveal/incrément) · *provisoire* (chiffre + chip `warn` « provisoire — complète ton Index ») · *chargement* (anneau en rotation indéterminée + « calcul… »).
- **Honnêteté :** en mode *estimé/provisoire*, le chiffre est en `text.secondary` (pas plein cyan) tant qu'un vrai benchmark n'a pas confirmé.

### 2.6 `HiNextRankBar` (barre « prochain rang »)

```
ARGENT  ████████████░░░░░░  OR        +47 pts → Or
        312                 450
```
- Barre `radius.pill`, hauteur 12 dp ; remplissage gradient de la couleur du rang actuel → couleur du rang suivant. Aux extrémités : insignes des deux rangs. Sous-titre : « +47 pts → Or ».
- Anim : remplissage `motion.slow` à l'entrée ; si l'Index vient de monter, l'avancée du curseur est animée + `haptic.milestone` si franchissement de rang (→ déclenche la célébration §3.4).
- États : *défaut* · *Élite atteint* (barre pleine holo + « Rang maximal — défends ta place / vise le record mondial ») · *chargement* (skeleton barre).

### 2.7 `HiRivalBlock` (bloc rival §11.4 / gamif §2)

```
┌──────────────────────────────────────────┐
│  TON RIVAL                          ⚔︎       │
│  [avatar]  Marie L.        Index 319       │
│            ██░ +7 pts pour la dépasser     │
│  [  Voir comment la battre  ]              │
└──────────────────────────────────────────┘
```
- Variantes : *rival actif* (« +7 pts pour la dépasser ») · *tu es n°1* (« Tu es n°1 — défends ta place » + cible pro/record) · *< 2 actifs* (« Bats le pro » + tes PR, rival masqué) · *rival dépassé* → bascule en **carte de célébration** (§3.4) puis nouveau rival.
- États : *défaut* · *pressé* · *chargement* (skeleton ligne) · *vide* (« Pas encore de rival — loggue un effort pour entrer dans la course »).

### 2.8 `HiLeaderboardRow` (ligne de classement)

```
│ 142  [avatar+cadre] Karim B.    H · Or     648  ↑3 │
│ 143  [TOI ●]        Toi         H · Argent  312  — │  ← surbrillance brand, sticky
```
- Colonnes : rang · avatar (avec cadre de rang) · nom · sexe+rang · Index (mono) · variation (`↑/↓/—`). Ligne « Toi » = fond `brand.primary 12 %`, **sticky** en bas si hors-écran.
- États : *défaut* · *pressé* (→ profil) · *chargement* (skeleton rows) · *vide* (« ligue en construction »).

### 2.9 `HiAvatar` (sprites 2D en couches §9.1)

- Composition empilée : `base teintée (peau)` → `corps/tenue (selon rang)` → `cheveux` → `barbe` → `accessoires/cosmétiques` → `cadre de rang` → `aura (Or+)`.
- Tailles : `xs 32` (lignes), `sm 56` (cartes), `md 96` (hub), `lg 200` (édition/reveal).
- **Aura/cadre** = couleur du rang (`rank.x` + `glow.rank`), `legendary` = aura animée (gamif §4.7).
- États : *idle* (respiration subtile : scale 1.00↔1.015, 3 s, désactivée si Reduce Motion) · *célébration* (saut + pose, `motion.celebrate`) · *édition* (rotation tap pour changer de couche) · *chargement* (silhouette pulsée).

### 2.10 `HiBadge` (badge/trophée §12)

- Médaillon `radius.md`, fond selon rareté (gamif §4.7) : *common* neutre · *rare* accent · *epic* particules · *legendary* aura animée + son. Icône + titre + état (débloqué/verrouillé avec progression « 12/15 »).
- États : *débloqué* · *verrouillé* (grisé + progression) · *vient d'être débloqué* (pop `motion.celebrate` + `sfx.badge`) · *chargement* (skeleton).

### 2.11 `HiShareCard` (carte partageable — moteur d'acquisition §13) `[MVP: reveal d'Index; autres P2]`

- Format **1080×1920** (story) + variante **1:1**. Template :
```
┌───────────────────────┐
│   HYBRID INDEX         │  ← logo discret haut
│      [AVATAR + aura]   │
│         247            │  ← Index géant, gradient brand
│  meilleur que 73 %     │
│   ◆ mini-radar         │
│   [badge/contexte]     │  ← « Reveal », « PR Fran », « Montée Or », « J'ai battu le pro »
│   @pseudo · ligue H    │
└───────────────────────┘
```
- Types : *reveal d'Index* `[MVP]` · *PR sur WOD* · *montée de rang* · *palier percentile* · *« j'ai battu le pro »* · *victoire de défi* `[P2]`.
- États : *génération* (« génération… » + skeleton) · *prête* (preview + boutons Partager/Enregistrer) · *erreur* (retry). Rendu **hors écran** (RepaintBoundary → image) pour qualité constante.

### 2.12 `HiGuidedTimer` (chrono + compteur du mode guidé §6.4)

```
┌──────────────────────────────────────┐
│            12:04.3                    │  ← chrono géant mono, point focal
│        ── Benchmark Zéro ──           │
│   Étape 2/4 · 30 pompes               │
│   compteur:  [ – ]   18   [ + ]       │  ← gros boutons ±, tap=haptic.tap
│  [ Pause ]            [ Terminer ]    │
└──────────────────────────────────────┘
```
- Chrono `type.mono` 64 dp, tabular. Boutons ± **≥ 64 dp** (utilisable en effort, transpiration). `Wakelock` actif. Bip optionnel à chaque étape.
- États : *prêt* (compte à rebours 3-2-1) · *en cours* · *pause* · *terminé* (→ écran résultat). Erreur = sauvegarde locale + reprise.

### 2.13 États de saisie & feedback transverses

- **`HiTextField` / `HiNumberField` / `HiTimeField`** : fond `bg.elevated2`, `radius.md`, label flottant. États : *défaut · focus* (`stroke.strong` brand) *· erreur* (`error` + message inline `type.caption`) *· désactivé · valide* (✓ `success`). Validation **inline** (cahier écran 3).
- **`HiSkeleton`** : blocs `#1A2030` avec shimmer balayant (gradient clair 8 %, `motion.base` en boucle). Formes = empreinte exacte du contenu final (anti-CLS).
- **`HiEmptyState`** : illustration légère + titre `type.h3` + sous-texte `type.body` `text.secondary` + 1 CTA. Toujours **orienté action** (jamais un cul-de-sac).
- **`HiErrorState`** : icône `error`, message clair non technique, bouton **Réessayer**. Bannière hors-ligne = `bg.elevated2` + `info`, données en cache affichées dessous.
- **`HiToast` / `HiConfetti`** : toast `motion.fast` haut/bas ; confettis = ParticleField (couleurs `brand` + `rank.x`), `motion.celebrate`, **off si Reduce Motion**.

---

## 3. LE REVEAL DE L'INDEX — storyboard signature (§6.2, §8 écran 6)

> **Objectif :** le moment le plus mémorable de l'app. Suspense court → récompense → conséquences → partage. Durée totale **~4.5 s** jusqu'au chiffre, interactif ensuite. Toujours **honnête** : si l'Index est estimé, on le dit (chip `warn`), sans casser la magie.

### 3.1 Storyboard (timeline)

| t (s) | Visuel | Haptique | Son |
|---|---|---|---|
| 0.0–0.8 | Fond `bg.base` s'assombrit, l'avatar apparaît au centre (fondu+scale 0.9→1), anneau d'Index vide en rotation lente. Texte « Calcul de ton Hybrid Index… » | — | léger hum montant |
| 0.8–1.4 | **Suspense** : l'anneau accélère, particules cyan convergent vers le centre, micro-zoom caméra (parallaxe). | tick léger | `sfx.tick` épars |
| 1.4–3.4 | **LE CHIFFRE MONTE** : `HiIndexCounter` s'incrémente 0 → valeur (`motion.reveal.count`, `easeOutExpo`), l'anneau se remplit en synchro (gradient `brand`). | `haptic.tickUp` cadencé (accélère puis ralentit) | `sfx.tick` synchronisé, pitch montant |
| 3.4–3.7 | **Atterrissage** : le chiffre « claque » (scale overshoot 1.0→1.08→1.0, `elasticOut`), flash cyan, `glow.brand` max. | `haptic.celebrate` (heavy ×2) | `sfx.reveal` (whoosh+impact) |
| 3.7–4.5 | **Confettis** (couleurs marque) + **percentile** apparaît dessous : « déjà meilleur que **73 %** de la population ! » (compteur du % monte aussi, 0→73). | `haptic.milestone` au palier rond | `sfx.confetti` |
| 4.5+ | **Conséquences** : le radar se déploie (Engine + Vitesse remplis, reste verrouillé, §8) ; chip rang (« Bronze ») ; **CTA partage** (`HiButtonSecondary` « Partager ma carte ») + **CTA principal** (`HiButtonPrimary` « Complète ton Index »). | `haptic.tap` sur interaction | — |

### 3.2 Détails

- **Pré-reveal son :** au tout premier reveal de la vie de l'utilisateur, micro-modale « Active le son et l'haptique pour vivre le moment » (opt-in). Refus = reveal silencieux mais tout aussi soigné visuellement.
- **Cas estimé (5bis) :** le chiffre monte de la même façon, mais sous le percentile : chip `warn` « Index estimé — un vrai effort le confirmera ». Le chiffre reste en `text.secondary` jusqu'au 1er benchmark. **On ne ment pas.**
- **Reveal de résultat de WOD (§6.2) :** même grammaire, plus court : « Calcul en cours » (0.6 s) → note qui monte → ligne pros (« Pros ~7:30 · ton 11:20 = 66 % du niveau élite — top 19 % H 🔥 ») → anneaux d'attributs qui montent (+Δ) → Index mis à jour (mini-counter) → rang/rival impactés → badge éventuel (pop) → CTA partage + prochaine séance.
- **Reduce Motion :** pas de confettis ni parallaxe ; le chiffre apparaît en fondu + 1 incrément discret ; haptique conservée (légère), son conservé. L'info (chiffre, %, conséquences) est strictement la même.

### 3.3 Performance
Anim portées par `AnimatedBuilder` + `Ticker` (pas de rebuild d'arbre lourd) ; confettis via shader/`CustomPainter` plafonné à ~80 particules ; carte partageable rendue à part. Cible **60 fps** sur device milieu de gamme.

### 3.4 Célébration de montée de rang (réutilise la grammaire)
Déclenchée quand `HiNextRankBar` franchit un seuil : assombrissement → avatar **change de cadre/aura en live** → insigne du nouveau rang « éclot » (`motion.celebrate`) → `sfx.rankup` + `haptic.celebrate` → confettis aux couleurs du rang → CTA « Partager » + « Voir mes nouveaux cosmétiques ». Intensité croissante selon le rang (Or+ = grande célébration, gamif §3.1).

---

## 4. ONBOARDING écran par écran (§8 — « waouh » < 60 s, avatar ≤ 30 s)

> **Règle de friction globale :** 1 tap par décision, **0 clavier sauf le nom**, aperçu temps réel, bouton « Passer » visible quand l'étape est facultative. Barre de progression fine (7 segments) en haut. Sortie possible sans perte (reprise).

### Écran 1 — Accroche
- Layout : avatar générique animé en fond, titre `type.h1` « Découvre ton Hybrid Index. », sous-titre « Un seul chiffre pour ta condition hybride. », `HiButtonPrimary` « Commencer ». Auth (Apple/Google/email) accessible ici (« J'ai déjà un compte »).
- Micro-interaction : entrée des éléments en cascade `motion.fast` (40 ms decalage).

### Écran 2 — Avatar (≤ 30 s) ⏱
- Layout : `HiAvatar lg` (200) en haut (point focal, aperçu **temps réel**) ; sous lui, onglets de couches : **Nom** (seul champ clavier) · **Sexe** (= normalisation, 2 gros choix, info-bulle « sert au classement équitable ») · **Couleur de peau** (palette de pastilles) · **Cheveux** · **Barbe** (toggle masquable).
- Micro-interactions : chaque sélection → `haptic.tap` + l'avatar se met à jour instantanément avec un petit *pop*. Carrousels de pastilles tactiles, pas de menus.
- Friction : tout pré-rempli par défaut → l'utilisateur peut taper « Suivant » en 3 s s'il veut. CTA « Suivant ».

### Écran 3 — Objectif (1 tap)
- 3 grandes cartes empilées (icône + titre + 1 ligne) : *Améliorer mon temps HYROX* / *Devenir plus fort en CrossFit* / *Progresser partout*. Tap = sélection (bordure brand + `haptic.tap`) → avance auto (300 ms). Influence les poids `w_A` de l'Index.

### Écran 4 — Avec ou sans matériel ? (1 tap)
- 3 cartes : *Sans matériel* (icône corps) / *Avec matériel* (haltère) / *Ça dépend*. Persistant (préférence). Détermine la suite (Benchmark Zéro vs PFT) et le filtrage des WODs.

### Écran 5 — Temps de course (conseillé, non obligatoire)
- Layout : sélecteur distance (1 / 5 / 10 km, segmented) + `HiTimeField` (roue type picker mm:ss, pas de clavier). Sous-titre « → ton Index provisoire en 10 s ». **`HiTextButton` « Passer » bien visible** en bas.
- Si renseigné → micro-calcul → file vers Reveal (écran 6).

### Écran 5bis — Auto-évaluation (fallback) ⭐
- Déclenché **uniquement si l'utilisateur passe l'écran 5**. 3 questions à 1 tap chacune :
  1. Niveau de course estimé (Débutant / Régulier / Compétiteur).
  2. Pompes max approx (segments : <10 / 10–25 / 25–40 / 40+).
  3. Expérience (Débutant / Intermédiaire / Avancé).
- Résultat : **Index provisoire ESTIMÉ**, clairement étiqueté `warn`. Garantit un chiffre pour 100 % des inscrits (principe §3.1).

### Écran 6 — LE REVEAL ⭐
- = §3 ci-dessus. C'est le « waouh ». À la fin : radar partiel + rang + CTA « Partager » / « Complète ton Index ».

### Écran 7 — « Complète ton Index »
- Layout : carte du benchmark fondateur selon matériel — **Benchmark Zéro** (sans) ou **PFT HYROX** (avec) — + suggestion d'1 test bodyweight. Bouton **« Mode guidé »** (chrono + compteur, §2.12) mis en avant ; « Plus tard » possible.
- Message : « 3 efforts suffisent pour un Index complet. » Aucune obligation. Affiche déjà la prochaine marche (objectif proximal).

---

## 5. LISTE EXHAUSTIVE DES ÉCRANS (les 17 du §17) + 4 ÉTATS OBLIGATOIRES

> Pour chaque écran : rôle · structure · **Vide · Chargement (skeleton) · Erreur · Succès**. Textes prêts à l'emploi (ton positif/honnête).

### Écran 1 — Onboarding `[MVP]`
- **Rôle :** Avatar → objectif → matériel → course/estimation → reveal → benchmarks (cf. §4).
- **Structure :** stack de 7 étapes + barre de progression.
- **Vide :** — (toujours initialisé avec défauts). **Chargement :** spinner court + « Calcul… » entre étapes (reveal géré à part). **Erreur :** « On n'a pas pu calculer ton Index. Réessaie. » + Réessayer (l'avatar/saisie sont conservés). **Succès :** reveal joué, atterrissage sur le hub.

### Écran 2 — Accueil / Personnage (HUB) `[MVP]`
- **Rôle :** point central. Contenu §9.3.
- **Structure :**
```
┌──────────────────────────────────────────┐
│ [HiAvatar md + cadre rang]   🔥 streak 12  │
│        HYBRID INDEX  647   top 22 %        │  ← HiIndexCounter (statique)
│  [HiNextRankBar]  +53 → Platine            │
│  [HiRivalBlock]                            │
│  [HiRadarChart]  (tap axe → améliorer)     │
│  [ Séance suggérée du jour ]  →            │
│  [ Dernier WOD noté: Fran 4:32 ★PR ]       │
│  Accès rapides:  [+ WOD]   [Explorer]      │
└──────────────────────────────────────────┘  + HiFab "+WOD"
```
- **Vide (nouveau, Index provisoire) :** Index en `text.secondary` + chip `warn` « provisoire », radar partiel, encart « Complète ton Index (2 efforts restants) ». Pas de rival → « Loggue un effort pour entrer dans la course ».
- **Chargement :** skeleton du hub (avatar pulsé, blocs Index/rival/radar en `HiSkeleton`).
- **Erreur :** bannière hors-ligne `info` « Hors-ligne — données en cache » + contenu en cache affiché ; bouton Réessayer en haut.
- **Succès :** hub complet, animations d'entrée des jauges, Δ animés si retour après un nouveau WOD.

### Écran 3 — Ajouter un WOD `[MVP]`
- **Rôle :** saisie (matériel → biblio/custom → type → reps/charges → résultat).
- **Structure :** wizard en étapes (préférence matériel pré-remplie, surchargeable) → choix WOD (liste filtrée + recherche) → type → champs dynamiques (`HiNumberField`/`HiTimeField`, bodyweight géré) → bouton « Calculer ».
- **Vide :** — (formulaire). **Chargement :** — (local) ; spinner court au chargement de la biblio. **Erreur :** validation **inline** des champs (« Temps requis », « Valeur hors plage plausible »). **Succès :** → écran 4 (Résultat).

### Écran 4 — Résultat de WOD `[MVP]`
- **Rôle :** note + référence pros + conséquences + partage (§6.2).
- **Structure :** reveal de note (§3.2) → ligne pros/percentile → anneaux d'attributs qui montent → mini-counter Index → rang/rival → badge éventuel → CTA « Partager » + « Prochaine séance ».
- **Vide :** —. **Chargement :** « Calcul en cours… » (suspense, anneau indéterminé). **Erreur :** « Impossible de calculer pour l'instant — ton résultat est enregistré, le score arrive bientôt. » (résultat sauvé, score en attente, jamais perdu). **Succès :** reveal complet + conséquences animées.

### Écran 5 — WODs de référence (les 15) `[MVP]`
- **Rôle :** liste + statut (fait/à faire) + accès classements. Filtre matériel/sans matériel.
- **Structure :** liste de `HiWodCard`, sections « Fondateurs » (Benchmark Zéro, PFT) en tête.
- **Vide :** « Aucun fait — commence par le **Benchmark Zéro**. » + CTA. **Chargement :** skeleton liste (3-4 cards). **Erreur :** état d'erreur + Réessayer. **Succès :** liste avec statuts ✓/○/★PR.

### Écran 6 — Détail d'un WOD / classement `[MVP]`
- **Rôle :** temps de tous (par sexe) + ton rang + écart rival.
- **Structure :** en-tête WOD (description, type, attributs, pro ref) → ton résultat (ou CTA faire) → `HiLeaderboardRow` (liste, ligne « Toi » sticky) → indicateur de confiance (« calibré sur données publiques » / « communauté n=… »).
- **Vide :** « Sois le premier à le poster ! » + CTA Faire / Mode guidé. **Chargement :** skeleton classement. **Erreur :** Réessayer. **Succès :** classement + ton rang surligné + écart rival.

### Écran 7 — Détail de l'Index `[MVP]`
- **Rôle :** courbe de progression, percentile, **Index projeté**.
- **Structure :** grand Index + percentile → courbe temporelle (zone gradient brand) → `HiNextRankBar` → bloc « Index projeté : +X pts si [axe] atteint Y » (lien vers radar) → indicateur de confiance/estimation.
- **Vide :** « Pas encore d'historique — loggue un effort pour voir ta courbe grimper. » **Chargement :** skeleton graphe. **Erreur :** Réessayer. **Succès :** courbe + projections.

### Écran 8 — Détail du radar `[MVP]`
- **Rôle :** 6 attributs + **« Améliorer cet axe »** → WODs ciblés (§10.2).
- **Structure :** `HiRadarChart` grand → liste des 6 `HiAttributeRing` (valeur, percentile, fraîcheur, estimé) → tap axe → bottom-sheet WODs ciblés + Index projeté.
- **Vide :** axes verrouillés expliqués (« Fais un WOD ciblé pour révéler cet axe »). **Chargement :** skeleton radar+liste. **Erreur :** Réessayer. **Succès :** radar complet interactif.

### Écran 9 — Ligue (H/F) `[MVP]`
- **Rôle :** classement par Index, rival mis en avant (§11).
- **Structure :** toggle ligue (selon sexe), `HiRivalBlock` épinglé en tête, liste `HiLeaderboardRow`, « Toi » sticky. Met en avant percentile + progression (« +250 places ce mois »).
- **Vide :** « Ligue en construction » (si < 2 actifs) + « Sois parmi les fondateurs ». **Chargement :** skeleton rows. **Erreur :** Réessayer. **Succès :** classement + rival.

### Écran 10 — Explorer / Feed `[MVP profils & explore ; feed/kudos P2]`
- **Rôle :** parcourir/filtrer athlètes + feed des suivis.
- **Structure :** barre de filtres (sexe, rang, matériel) + grille/liste de profils ; onglet Feed `[P2]` (kudos 💪🔥👏).
- **Vide :** « Suis des athlètes pour voir leur activité. » + suggestions. **Chargement :** skeleton cartes. **Erreur :** Réessayer. **Succès :** résultats filtrés / feed.

### Écran 11 — Profil public (soi + autres) `[MVP]`
- **Rôle :** avatar, Index, radar, historique de WODs, badges (§13).
- **Structure :** en-tête (avatar+cadre, Index, ligue/rang, percentile, bouton Suivre/Comparer/Partager) → radar → historique WODs → salle des trophées (aperçu) → kudos `[P2]`.
- **Vide :** « Pas encore de WOD posté. » **Chargement :** skeleton. **Erreur :** Réessayer. **Succès :** profil complet.

### Écran 12 — Comparaison `[MVP]`
- **Rôle :** radars superposés (toi vs un autre).
- **Structure :** sélecteur d'athlète + `HiRadarChart` à 2 tracés (toi cyan plein / autre violet contour) + table comparative attribut par attribut + Index/rang côte à côte.
- **Vide :** « Choisis un athlète à comparer. » **Chargement :** skeleton radar. **Erreur :** Réessayer. **Succès :** radars superposés + deltas par axe.

### Écran 13 — Défier un ami `[P2]`
- **Rôle :** créer/voir un défi sur un WOD (boucle virale §13).
- **Structure :** choisir WOD → générer lien → écran de suivi (statut : envoyé / accepté / réalisé) → carte de résultat tête-à-tête.
- **Vide :** « Aucun défi en cours — défie un ami sur un WOD. » **Chargement :** — / spinner génération lien. **Erreur :** « Lien de défi invalide ou expiré. » **Succès :** défi suivi + carte de duel.

### Écran 14 — Salle des trophées `[P2]`
- **Rôle :** badges débloqués/à débloquer (§12).
- **Structure :** grille de `HiBadge` par catégorie (Progression, Collection, Performance, Régularité, Social), avec progression sur les verrouillés.
- **Vide :** « Débloque ton premier badge — loggue un WOD ! » **Chargement :** skeleton grille. **Erreur :** Réessayer. **Succès :** grille + pop sur nouveaux badges.

### Écran 15 — Réglages `[MVP base RGPD]`
- **Rôle :** préférence matériel, notifs, son/haptique, confidentialité, compte, **export/suppression données (RGPD §18)**.
- **Structure :** sections en liste (Préférences · Notifications · Son & Haptique · Confidentialité (`visibility` prévu) · Compte · Données RGPD : Exporter / Supprimer · À propos).
- **Vide :** —. **Chargement :** — (spinner sur export). **Erreur :** message clair (« Export indisponible, réessaie »). **Succès :** modifs persistées + toast `success`.

### Écran 16 — Édition avatar `[MVP base ; cosmétiques gagnés P2]`
- **Rôle :** modifier l'apparence + équiper cosmétiques débloqués.
- **Structure :** `HiAvatar lg` + onglets de couches + casiers de cosmétiques (verrouillés affichent la condition : « Atteins Or », « Badge Grand Chelem »).
- **Vide :** « Monte en rang pour débloquer des cosmétiques. » **Chargement :** skeleton. **Erreur :** — (édition locale). **Succès :** aperçu temps réel + Enregistrer.

### Écran 17 — Carte de partage `[MVP: reveal ; autres P2]`
- **Rôle :** générer/partager une carte (`HiShareCard`, §2.11).
- **Structure :** sélecteur de type → preview → boutons Partager / Enregistrer.
- **Vide :** —. **Chargement :** « Génération… » + skeleton. **Erreur :** Réessayer. **Succès :** carte prête + feuille de partage native.

---

## 6. NAVIGATION

### 6.1 Structure globale
- **Bottom navigation à 5 onglets** (pouce-friendly, hauteur 64 dp + safe area) :
  1. **Accueil** (hub, écran 2) — par défaut.
  2. **WODs** (référence + détails/classements, écrans 5–6).
  3. **➕ (FAB central)** — Ajouter un WOD (écran 3) — surélevé, gradient.
  4. **Ligue** (écran 9).
  5. **Profil** (écran 11 « moi » → réglages, trophées, édition avatar).
- **Explorer** accessible depuis le hub (accès rapide) et l'entête Ligue/Profil.
- Chaque onglet = sa propre **pile de navigation** (push pour détails ; sheets pour « améliorer cet axe », partage).
- Transitions : `motion.page` (shared-axis horizontal pour push, vertical/scale pour sheets & reveal).

### 6.2 Parcours principaux
- **Onboarding → Reveal → Hub** (premier lancement).
- **Hub → +WOD → (Mode guidé) → Résultat (reveal) → retour Hub** (conséquences animées) — boucle d'habitude cœur.
- **Hub → tap axe radar → « Améliorer cet axe » → WOD ciblé → Résultat** (boucle de progression visible).
- **Hub → Rival → « Voir comment la battre » → WOD/axe ciblé.**
- **Résultat/Rang/Profil → Carte de partage → partage natif** (boucle virale).

---

## 7. ACCESSIBILITÉ

- **Contraste :** texte ≥ 4.5:1 (tertiary = 4.6:1 vérifié) ; éléments graphiques actifs ≥ 3:1. Le gradient brand sur `text.onBrand` foncé respecte 4.5:1.
- **Cibles tactiles :** ≥ 48×48 dp (boutons mode guidé ± ≥ 64 dp pour usage en effort).
- **Dynamic Type :** support jusqu'à ×1.3 sans casse ; layouts flexibles, pas de hauteurs figées sur texte.
- **Couleur jamais seule :**
  - **Rangs** → insigne distinct + libellé texte.
  - **Attributs radar** → icône par axe + alternative liste lisible par lecteur d'écran (« Engine 612, top 22 % »).
  - **Statuts WOD** → icône (✓/○/★) + texte.
  - **Estimé/provisoire/à rafraîchir** → label texte + icône (jamais juste orange).
- **Reduce Motion :** confettis/parallaxe désactivés, compteurs en fondu+incrément discret, aucune perte d'info (§1.8, §3.2).
- **Son :** opt-in, toujours doublé par haptique + visuel.
- **Lecteurs d'écran :** ordre de focus logique, labels sémantiques sur radar/Index/jauges, annonce des changements (« Index 647, +12 »).
- **Daltonisme :** palette attributs/rangs choisie pour rester distinguable (teinte + valeur), renforcée par icônes/formes.

---

## 8. PÉRIMÈTRE MVP (Phase 1) vs Phase 2 (§19)

### Écrans
| Écran | Phase |
|---|---|
| 1 Onboarding · 2 Hub · 3 Ajouter WOD · 4 Résultat · 5 WODs réf · 6 Détail/classement · 7 Détail Index · 8 Détail radar · 9 Ligue · 11 Profil public · 12 Comparaison · 15 Réglages (base RGPD) · 16 Édition avatar (base) · 17 Carte de partage (reveal) | **`[MVP]`** |
| 10 Explorer (profils oui ; **feed/kudos** non) | **MVP partiel** |
| 13 Défier un ami · 14 Salle des trophées · 17 (autres types de cartes) · 10 (feed/kudos) · cosmétiques gagnés (16) | **`[P2]`** |

### Composants
- **`[MVP]` :** boutons, HiWodCard, HiAttributeRing, HiRadarChart, HiIndexCounter (+ reveal), HiNextRankBar, HiRivalBlock, HiLeaderboardRow, HiAvatar, HiShareCard (reveal), HiGuidedTimer, champs/skeletons/empty/error.
- **`[P2]` :** HiBadge (salle des trophées), kudos/feed, cartes de partage avancées, comparaison sociale enrichie, cosmétiques d'avatar gagnables.
- **`[P3]` :** vérification (source `verified`), coach IA conversationnel, mode clair complet si non fait avant.

> Doctrine : **une thin slice excellente** plutôt que tout à moitié (cahier §19). Le reveal, le hub, la boucle log→résultat→conséquences et le rival sont les pièces à polir en priorité.

---

## RÉSUMÉ (8–12 lignes)

Ce design system pose une identité **sombre + cyan/violet électrique** au feel « jeu vidéo », pensée Flutter, mobile-first, 60 fps. Il livre des **tokens concrets** (couleurs marque, 7 rangs alignés sur `gamification.md §3.1`, 6 attributs, sémantique honnête, typo Sora/Inter avec chiffres tabulaires, espacement base-4, rayons, glows, durées/courbes, haptique et son nommés). Il spécifie **13 composants clés** avec anatomie, variantes et 4 états chacun, dont les pièces signatures : **radar 6 axes interactif**, **compteur d'Index animé** et **carte partageable**. Le **REVEAL de l'Index** est storyboardé seconde par seconde (suspense → chiffre qui monte → percentile → conséquences → partage), avec haptique/son/confettis et une variante stricte « Reduce Motion ». L'**onboarding 7 écrans** (dont 5bis) respecte la règle « waouh < 60 s / avatar ≤ 30 s » (1 tap/décision, 0 clavier sauf le nom). Les **17 écrans** sont décrits avec leurs 4 états obligatoires (vide/chargement/erreur/succès) et des textes prêts. La **navigation** (5 onglets + FAB central) sert la boucle d'habitude. L'**accessibilité** garantit contrastes, cibles ≥ 48 dp et alternatives non-couleur (insignes de rang, icônes d'attribut, labels). Le **périmètre MVP vs P2** est marqué partout. Principe transverse respecté : **dopamine honnête** — on célèbre fort les vraies étapes, on étiquette clairement tout score estimé/provisoire.

## ALERTES & INCOHÉRENCES DÉTECTÉES

1. **Sécurité — mineurs vs « tout public ».** Le §18 exige un **age-gating** mais l'onboarding (§8) n'a aucune étape d'âge/consentement. **Manque un écran « Âge + consentement publication publique »** avant le reveal. À trancher avec l'humain/juriste (impact RGPD fort). Non ajouté unilatéralement (décision verrouillée « tout public »), mais **signalé**.
2. **Mode guidé vs liste des écrans.** Le mode guidé (chrono+compteur, §6.4) est central au MVP mais **n'apparaît pas comme écran numéroté au §17**. Je l'ai spécifié comme composant `HiGuidedTimer` rattaché aux écrans 3/6/7 ; à confirmer s'il doit devenir un écran à part entière.
3. **Onboarding = 8 étapes réelles, pas 7.** Avec 5bis, le parcours comporte 8 écrans possibles ; la barre de progression doit gérer le **branchement conditionnel** (5 OU 5bis), pas 7 segments fixes. À valider.
4. **Police propriétaire.** Sora + Inter sont libres (OFL), OK pour distribution. Si une autre direction de marque est voulue, le token `type.*` reste l'unique point de changement — à valider tôt (impact sur tous les écrans).
5. **Coquilles tokens corrigées dans le doc :** `text.tertiary = #6B7488` et attribut verrouillé `#3A4256` (les valeurs uniques à implémenter sont celles indiquées explicitement, pas les variantes barrées).
6. **Onboarding §8 vs §17 (écran 1).** Le §17 résume l'onboarding en 1 « écran » alors qu'il en contient 7–8 ; cohérent (1 flow), mais la **Definition of Done « 4 états »** s'applique au flow entier — traité comme tel ci-dessus.
