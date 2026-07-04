# Design — Authentification v1 (« Athlete League »)

Spec design de l'écran de **connexion + création de compte**, reconstruit après le wipe
(`branche wipe-auth`). Objectif : **10/10 AAA**, thème **sombre** calé À L'IDENTIQUE sur le
design system existant (`lib/theme/tokens.dart`), sobre, rapide, premium.

> Portée : cette spec couvre **email + mot de passe** (le cœur). Les boutons sociaux
> (Google/Apple) sont **placés visuellement** mais marqués **phase 2** — ils ne bloquent rien.

---

## 0. Rappels du design system (source : `tokens.dart`, `app_theme.dart`)

Couleurs (thème sombre `kHiDark`, valeurs exactes) :
- Fond : `bgBase #090B11` ; ambiant (dégradé) `bgAmbient #0E1420`.
- Surfaces : `bgElevated #11151F`, `bgElevated2 #1A1F2D` (fond des champs), `bgElevatedHi #232A3B`.
- Contours : `strokeSubtle #14FFFFFF` (8 %), `strokeStrong #29FFFFFF` (16 %), `strokeBrand #732BD4F5`.
- Marque : `brandPrimary #2BD4F5` (cyan), `brandPrimaryDeep #0A8FB3`, `brandGradient` (135°, primary→deep).
- Texte : `textPrimary #F2F5FA`, `textSecondary #A7B0C0`, `textTertiary #7E8597` (AA), `textOnBrand #04121A`.
- États : `success #34E29B`, `error #FF5470`, `warn #FFB23F`, `info #6FB3FF`.
- `accentVictory #C6FF4A` (lime) : **interdit en UI de repos** — célébrations uniquement.

Typo (`HiType`) : Rajdhani = data/titres data ; Inter = corps/UI.
- `titleXL` 26/w800, `titleL` 22/w800, `titleM` 17/w700, `body` 15/w500, `bodyStrong` 15/w700,
  `label` 13/w600, `caption` 12/w500, `button` 16/w700, `overline` 12/w700 (Rajdhani, tracking 2.5).

Espacements (`HiSpace`) : xxs 2, xs 4, sm 8, md 16, **gutter 20** (marge d'écran), lg 24, xl 32,
xxl 48, xxxl 64. Rayons (`HiRadius`) : sm 12, **md 16 (boutons/champs)**, lg 20 (cartes),
xl 28 (héros). Tap min (`HiTap.minTarget`) : **48 dp**.

Ombres (`HiShadow`) : `e1`/`e2` cartes ; `glowBrand(alpha)` halo cyan. Motion (`HiMotion`) :
`fast 180ms`, `base 280ms`, courbes `enter=easeOutCubic`, `emphasis=easeOutBack`.

Composants réutilisés tels quels : `HiButton` (CTA gradient, `loading` intégré, height 52,
radius md, scale 0.96 au press), `HiButtonSecondary` (surface + contour), `HiGhostButton`
(texte cyan, actions discrètes), `ErrorRetry` (état plein page réseau), `HiPressable`.

`InputDecorationTheme` global (déjà défini) : `filled`, `fillColor = bgElevated2`,
`hintStyle = textTertiary`, `labelStyle = textSecondary`, bordure radius **md 16**,
`focusedBorder = brandPrimary width 1.5`. **On s'aligne dessus** pour le nouveau champ.

---

## 1. Parcours global (flow)

Principe AAA : **un seul écran** porte tout, avec une **bascule segmentée** Connexion / Inscription.
Zéro carrousel, zéro étape inutile. On enchaîne sur l'onboarding avatar existant après création.

```
                 (WEB) Landing web/index.html  ──clic « Commencer »──┐
                                                                     ▼
   AuthGate (app.dart) ── profil == null ─────────────►  [A] AuthScreen (Connexion / Inscription)
                                                              │            │
                          ┌───────────────────────────────────┘            │
             Connexion OK │                                   Inscription OK │
                          ▼                                                  ▼
                    HomeShell (app)                          [Onboarding avatar existant]
                                                          onbAvatarTitle → dice_avatar_screen
                                                          → Profil Express → HomeShell
                          ▲
        [B] Mot de passe oublié ─(3 sous-étapes déjà i18n : email → code → nouveau mdp)─┘
```

Détails :
- **AuthGate** (`app.dart`, `_AuthPlaceholder` actuel) : quand la session n'a pas de profil,
  on route vers **`[A] AuthScreen`** (remplace le placeholder temporaire).
- **Connexion réussie** → `HomeShell` (l'app charge le profil complet existant).
- **Inscription réussie** → on branche l'**onboarding avatar déjà en place** :
  clés i18n `onbAvatarTitle` / `onbAvatarSubtitle` → `features/avatar/dice_avatar_screen.dart`
  → Profil Express (séance d'entrée sur l'Accueil) → `HomeShell`.
  L'auth **ne recrée pas** l'avatar : elle passe la main au flux existant.
- **Mot de passe oublié** → `[B]` (3 sous-étapes, libellés déjà présents : `authForgotIntro`,
  `authForgotCode`, `authForgotNewPassword`, `authForgotConfirm`, `authForgotDone`).

Enchaînement **web ↔ landing** : la landing `web/index.html` reste peinte jusqu'au premier
frame Flutter (`notifyLandingReady()` via `hiOnFlutterReady`). `[A] AuthScreen` reprend
**exactement** les tokens de la landing (nuit `#090B11`, cyan `#2BD4F5`, Rajdhani/Inter,
même dégradé de fond) → la transition landing→auth est **invisible** (aucun saut de couleur,
aucun flash blanc). L'appel `notifyLandingReady()` se fait au `initState` d'`AuthScreen`.

---

## 2. Écran par écran (layout précis, ASCII)

### [A] AuthScreen — écran unique Connexion / Inscription

Fond : `bgBase #090B11` + dégradé ambiant radial haut (`bgAmbient` centre) identique aux autres
écrans (réutiliser `HiAmbientBackground` si présent, sinon `RadialGradient` bgAmbient→bgBase).
Contenu **centré verticalement**, `SafeArea`, scrollable (`SingleChildScrollView`) pour éviter
tout overflow clavier. Marge horizontale : `HiSpace.gutter` (20). Largeur de contenu **max 420**
(centré) — indispensable pour le web pleine largeur.

```
┌──────────────────────────────────────────────┐
│                                               │  ← SafeArea, dégradé ambiant
│                                               │
│                  ▟ ATHLETE                    │  logo/wordmark (Rajdhani, tracking)
│                    LEAGUE                      │
│                                               │  HiSpace.xl
│         Rejoins la Ligue.                     │  titleXL / textPrimary  (accroche)
│         Trouve ton Index.                     │
│                                               │  HiSpace.lg
│   ┌─────────────────────────────────────┐    │
│   │  Connexion   │    Inscription        │    │  ← segment (pill), 44dp haut
│   └─────────────────────────────────────┘    │
│                                               │  HiSpace.lg
│   ┌─ Pseudo ───────────────────────┐         │  (INSCRIPTION seulement — animé)
│   │ 👤  ex. IronWolf                │         │
│   └─────────────────────────────────┘         │
│                                       HiSpace.md│
│   ┌─ Email ────────────────────────┐          │
│   │ ✉  toi@exemple.com             │          │
│   └─────────────────────────────────┘         │
│                                       HiSpace.md│
│   ┌─ Mot de passe ─────────────────┐          │
│   │ 🔒  ••••••••              👁    │          │  œil afficher/masquer
│   └─────────────────────────────────┘         │
│                     Mot de passe oublié ?     │  HiGhostButton, aligné droite (CONNEXION)
│                                       HiSpace.lg│
│   ┌─────────────────────────────────────┐    │
│   │           Se connecter              │    │  HiButton (gradient), height 52
│   └─────────────────────────────────────┘    │
│                                       HiSpace.lg│
│   ───────────────  ou  ───────────────        │  séparateur (phase 2)
│                                       HiSpace.md│
│   ┌─ Continuer avec Google ──────────┐  ⓿     │  HiButtonSecondary (phase 2, désactivé)
│   ┌─ Continuer avec Apple  ──────────┐  ⓿     │
│                                       HiSpace.lg│
│   En créant un compte, tu acceptes    │        │  caption/textTertiary (INSCRIPTION)
│   les CGU et la Politique.            │        │  liens cyan soulignés
│                                               │
└──────────────────────────────────────────────┘
```

Structure verticale exacte (haut → bas) :

| Bloc | Style | Espacement après |
|---|---|---|
| Wordmark « ATHLETE / LEAGUE » | Rajdhani, `displayS`-like, `letterSpacing 4`, textPrimary ; « LEAGUE » en `brandPrimary` | `HiSpace.xl` |
| Accroche (2 lignes) | `HiType.titleXL`, textPrimary | `HiSpace.lg` |
| **Segment** Connexion/Inscription | pill, hauteur 44, voir §3 | `HiSpace.lg` |
| Champ **Pseudo** (inscription seule) | `HiTextField`, prefix `person_outline` | `HiSpace.md` |
| Champ **Email** | `HiTextField`, prefix `mail_outline`, keyboard email | `HiSpace.md` |
| Champ **Mot de passe** | `HiTextField`, prefix `lock_outline`, suffix œil | `HiSpace.xs` |
| Lien **Mot de passe oublié ?** (connexion seule) | `HiGhostButton`, aligné droite | `HiSpace.lg` |
| **CTA primaire** (Se connecter / Créer mon compte) | `HiButton`, largeur pleine | `HiSpace.lg` |
| Séparateur « ou » (phase 2) | voir §3 | `HiSpace.md` |
| Boutons sociaux (phase 2, désactivés opacity .5) | `HiButtonSecondary` × 2, gap `HiSpace.sm` | `HiSpace.lg` |
| Mention légale (inscription seule) | `caption` textTertiary + liens cyan | — |

Hiérarchie / point focal : **le CTA primaire** (gradient cyan + `glowBrand`) est le seul élément
lumineux « plein » → point focal unique. Le wordmark est présent mais discret (contour/texte).

### [B] Mot de passe oublié (3 sous-étapes, libellés déjà en i18n)

Même fond/gabarit. Push par-dessus `[A]` (transition slide `HiMotion.base`, `enter`).
AppBar minimal (flèche retour, titre `authForgotTitle`).

```
Étape 1 — Email          Étape 2 — Code           Étape 3 — Nouveau mdp
┌───────────────┐        ┌───────────────┐        ┌───────────────┐
│ authForgotIntro│        │ Code reçu par │        │ Nouveau mdp   │
│               │        │ email (6 chif)│        │ (8+)   👁      │
│ [✉ Email    ] │        │ [ _ _ _ _ _ _]│        │ [🔒 ········] │
│ [Envoyer code]│        │ [Vérifier]    │        │ [Changer mdp] │
└───────────────┘        └───────────────┘        └───────────────┘
  authForgotSent (bandeau success) → passe étape 2
```

Succès final : bandeau `success` « authForgotDone » → retour auto à `[A]` en mode **Connexion**,
email pré-rempli.

---

## 3. Composants UI

| Composant | Statut | Détail |
|---|---|---|
| `HiButton` | **existe** | CTA primaire (gradient, `loading`, glow). Réutilisé tel quel. |
| `HiButtonSecondary` | **existe** | Boutons sociaux (phase 2) + « Réessayer ». |
| `HiGhostButton` | **existe** | Lien « Mot de passe oublié ? », liens légaux. |
| `ErrorRetry` | **existe** | État d'erreur **plein écran** (échec de chargement initial, très rare ici). |
| `HiPressable` | **existe** | Scale au press pour le segment. |
| **`HiTextField`** | **À CRÉER** | Champ de saisie designé (voir ci-dessous). |
| **`HiAuthSegment`** | **À CRÉER** | Bascule pill Connexion / Inscription. |
| **`HiSocialButton`** | **À CRÉER (phase 2)** | Variante de `HiButtonSecondary` + logo. |
| **`HiFormBanner`** | **À CRÉER** | Bandeau d'erreur/succès inline (haut du formulaire). |
| **`HiOrDivider`** | **À CRÉER** | Séparateur « ligne — ou — ligne ». |

### `HiTextField` (nouveau — s'aligne sur `inputDecorationTheme`)
- Container height **56**, radius `HiRadius.md` (16), fond `bgElevated2 #1A1F2D`.
- Bordure : repos `strokeSubtle` ; **focus** `brandPrimary` width 1.5 + très léger `glowBrand(0.15)` ;
  **erreur** `error #FF5470` width 1.5 ; **valide** (optionnel) `success` width 1.5.
- Prefix : icône `outline` en `textTertiary` (focus → `brandPrimary`), taille 20, padding gauche `md`.
- Label flottant **au-dessus** (style `HiType.label` textSecondary) OU placeholder (hint `textTertiary`).
  Choix retenu : **label au-dessus** (plus lisible, moins de saut au focus).
- Suffix optionnel (œil mot de passe) : `IconButton` 48×48, `visibility_outlined` /
  `visibility_off_outlined`, `textSecondary`.
- Texte saisi : `HiType.body` `textPrimary`, curseur `brandPrimary`.
- **Message d'aide/erreur** sous le champ : `HiType.caption`, couleur `error` (erreur) /
  `textTertiary` (aide), hauteur réservée pour éviter le saut de layout.

### `HiAuthSegment` (nouveau)
- Container pill (radius `pill`), fond `bgElevated2`, contour `strokeSubtle`, height **44**.
- 2 onglets. Indicateur actif : « thumb » animé (`AnimatedAlign`, `HiMotion.base`, `emphasis`)
  fond `brandGradient` sous le libellé actif, texte actif `textOnBrand`, inactif `textSecondary`.
- Tap → change de mode ; les champs se réarrangent en **AnimatedSize + fade** (`HiMotion.base`).

### `HiFormBanner` (nouveau)
- Pleine largeur, radius `HiRadius.sm` (12), padding `md`.
- Erreur : fond `error @ 12%`, contour `error @ 40%`, icône `error_outline` + texte
  `HiType.body` `error`/`textPrimary`. Succès : mêmes règles avec `success`.
- Apparition : `AnimatedSize` + fade (`HiMotion.fast`). Auto-scroll vers le haut.

### `HiOrDivider` (nouveau)
- `Row`: `Expanded(Divider strokeSubtle)` — texte `authOr` (« ou ») `caption` `textTertiary`
  padding `md` — `Expanded(Divider)`.

### `HiSocialButton` (phase 2)
- Clone de `HiButtonSecondary` avec logo à gauche (asset Google/Apple), label plein.
- **Phase 1 : rendu en `opacity .5`, `onPressed:null`**, sous-titre `caption` « Bientôt ».

---

## 4. TOUS les états (par écran)

### Champs (`HiTextField`)
| État | Rendu |
|---|---|
| **Repos** | Bordure `strokeSubtle`, prefix `textTertiary`, hint `textTertiary`. |
| **Focus** | Bordure `brandPrimary` 1.5 + `glowBrand(0.15)`, prefix `brandPrimary`. Haptique `selectionClick`. |
| **Rempli valide** | Bordure `strokeStrong` (repos) ; check `success` discret en suffix (email/pseudo OK). |
| **Erreur validation live** | Bordure `error`, message caption `error` sous le champ. |
| **Désactivé (pendant submit)** | `IgnorePointer` + opacity .6. |

Validation **en direct** (au `onChanged`, mais message affiché seulement après 1er blur ou 1re
tentative — pas de rouge pendant la frappe initiale) :
- Email : regex simple `^\S+@\S+\.\S+$` → « Entre un email valide. »
- Mot de passe : `length >= 8` → « 8 caractères minimum. » (aligné sur `authPassword` « (8+) »).
- Pseudo (inscription) : 3–20 car., alphanumérique + `_` → « 3 à 20 caractères, sans espace. »

### CTA primaire
| État | Rendu |
|---|---|
| **Inactif** | `onPressed:null` tant qu'un champ requis est vide/invalide → opacity .5 (géré par `HiButton`). |
| **Actif** | Gradient + `glowBrand(0.28)`. |
| **Chargement** | `HiButton(loading:true)` → spinner `textOnBrand`, champs désactivés. Haptique `mediumImpact` au tap. |

### Erreurs serveur (bandeau `HiFormBanner` en haut du formulaire, pas de SnackBar pour l'auth)
| Cas | Source | Message (FR) |
|---|---|---|
| Email/pseudo déjà pris (inscription) | 409 → `authConflict` | « Cet email ou ce pseudo est déjà utilisé. » + focus auto sur le champ concerné si connu. |
| Identifiants invalides (connexion) | 401 | **NOUVELLE clé** `authInvalidCredentials` : « Email ou mot de passe incorrect. » |
| Réseau / timeout | pas de réponse | **NOUVELLE clé** `authNetworkError` : « Connexion impossible. Vérifie ta connexion et réessaie. » (cf. `messagingErrorNetwork`). |
| Autre / 500 | fallback | `authGenericFail` : « Connexion impossible pour le moment. Réessaie dans un instant. » |

Règle projet respectée : **jamais** de `Text('$e')` brut. Toute erreur passe par un libellé i18n.

### Succès + transition
- **Connexion** : haptique `mediumImpact`, le CTA garde le spinner → fondu sortant `HiMotion.base`
  vers `HomeShell` (pas de confetti : la connexion n'est pas un « moment de dopamine »).
- **Inscription** : haptique `mediumImpact`, transition slide vers **l'onboarding avatar**
  (`onbAvatarTitle`). La **célébration** (confetti/lime) est réservée au **reveal de l'Index**
  en fin d'onboarding — **pas** à la création de compte (dopamine honnête).

### États globaux de l'écran `[A]`
- **Vide / repos** : l'écran par défaut ci-dessus (formulaire prêt, CTA inactif).
- **Chargement initial** : aucun appel réseau requis pour PEINDRE `[A]` → pas de skeleton ;
  on affiche l'écran instantanément (perf/60fps). Le `_Splash` couvre le boot avant `AuthGate`.
- **Erreur** : gérée **inline** (bandeau), l'écran reste utilisable. `ErrorRetry` plein écran
  réservé au cas extrême où même l'écran ne peut se construire (non attendu ici).
- **Succès** : voir transitions ci-dessus.

---

## 5. Micro-interactions, animations, haptique, accessibilité

Animations (toutes ≤ `HiMotion.base`, 60 fps) :
- **Entrée d'écran** : contenu en `fade + translateY 12→0`, `HiMotion.base`, `enter`. Wordmark
  puis accroche puis formulaire en **stagger** léger (+40 ms chacun).
- **Bascule segment** : thumb `AnimatedAlign` (`emphasis`, overshoot léger) ; le champ Pseudo
  apparaît/disparaît via `AnimatedSize` + fade ; le lien « oublié » et la mention légale
  crossfadent selon le mode.
- **Focus champ** : bordure + glow en `HiMotion.fast`.
- **Bandeau d'erreur** : `AnimatedSize` + fade `HiMotion.fast` + **shake** horizontal léger
  (±6 px, 2 oscillations) sur le formulaire à l'échec serveur (signal clair, non agressif).
- **Œil mot de passe** : crossfade d'icône `HiMotion.fast`.

Haptique (cohérente avec l'app) :
- `HapticFeedback.selectionClick()` au focus d'un champ et au switch de segment.
- `HapticFeedback.mediumImpact()` au tap du CTA (submit).
- `HapticFeedback.lightImpact()` OU vibrate court à l'échec (accompagne le shake).
- **Aucune** haptique « victoire » ici (réservée au reveal Index).

Accessibilité :
- Contrastes AA vérifiés : textPrimary/bgBase, textSecondary/bgBase (≥ 4.5:1), textTertiary
  ajusté `#7E8597` (AA), error/bgElevated2 lisible, textOnBrand sur gradient cyan (AAA).
- Cibles tactiles ≥ **48 dp** : CTA height 52, œil `IconButton` 48×48, segment 44 (acceptable
  HIG 44/Material ; on élargit la zone tap à 48 via `InkWell`/`constraints`).
- `Semantics` : champs labellisés (`labelText`), CTA `button`, œil `Semantics(label: 'Afficher
  le mot de passe' / 'Masquer le mot de passe')`, bandeau erreur `liveRegion:true` (annoncé).
- `autofillHints` : email `[AutofillHints.email]` ; mot de passe `[AutofillHints.password]`
  (connexion) / `[AutofillHints.newPassword]` (inscription) → gestionnaires de mdp natifs.
- `textInputAction` : email → `next`, pseudo → `next`, mdp → `done` (submit). Clavier email
  = `TextInputType.emailAddress`, mdp `obscureText:true`.
- Respect `MediaQuery.textScaler` (pas de hauteur figée sur les textes ; champs en `minHeight`).

---

## 6. Textes FR exacts (à mettre / compléter dans `app_fr.arb`)

**Déjà présents (réutiliser)** :
`authLogIn` « Connexion », `authSignUp` « Inscription », `authSignInAction` « Se connecter »,
`authCreateAccount` « Créer mon compte », `authUsername` « Pseudo », `authEmail` « Email »,
`authPassword` « Mot de passe (8+) », `authForgotLink` « Mot de passe oublié ? »,
`authOr` « ou », `authConflict` « Cet email ou ce pseudo est déjà utilisé. »,
`authGenericFail` « Connexion impossible pour le moment. Réessaie dans un instant. »,
`authLegalNotice` « En créant un compte, tu acceptes : », plus les clés `authForgot*`.

**À AJOUTER** :
```json
"authTagline": "Rejoins la Ligue.\nTrouve ton Index.",
"authEmailHint": "toi@exemple.com",
"authUsernameHint": "ex. IronWolf",
"authPasswordHint": "8 caractères minimum",
"authShowPassword": "Afficher le mot de passe",
"authHidePassword": "Masquer le mot de passe",
"authInvalidEmail": "Entre un email valide.",
"authPasswordTooShort": "8 caractères minimum.",
"authUsernameInvalid": "3 à 20 caractères, sans espace.",
"authInvalidCredentials": "Email ou mot de passe incorrect.",
"authNetworkError": "Connexion impossible. Vérifie ta connexion et réessaie.",
"authContinueGoogle": "Continuer avec Google",
"authContinueApple": "Continuer avec Apple",
"authSocialSoon": "Bientôt",
"authTermsLink": "CGU",
"authPrivacyLink": "Politique de confidentialité",
"authNoAccountSwitch": "Pas encore de compte ? Inscris-toi",
"authHaveAccountSwitch": "Déjà un compte ? Connecte-toi"
```
(Les deux dernières servent de lien texte alternatif sous le CTA si on veut doubler le segment ;
optionnel — le segment reste la bascule primaire.)

---

## 7. Résumé « à créer » pour l'implémentation
- Widgets neufs : `HiTextField`, `HiAuthSegment`, `HiFormBanner`, `HiOrDivider`,
  `HiSocialButton` (phase 2).
- Écran : `AuthScreen` (mode Connexion/Inscription) + `ForgotPasswordScreen` (3 sous-étapes, i18n prête).
- Branchement : `app.dart` `AuthGate` → remplacer `_AuthPlaceholder` par `AuthScreen` ;
  inscription réussie → onboarding avatar existant (`dice_avatar_screen`) → `HomeShell` ;
  connexion réussie → `HomeShell`. `notifyLandingReady()` appelé à l'`initState` d'`AuthScreen`.
- i18n : ajouter les clés du §6 (fr + en).
```
```
```
