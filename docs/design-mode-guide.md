# Design — Mode guidé (lecteur de séance plein écran, format-aware)

> Auteur : Designer UI/UX — Athlete League. Cible : développeur Flutter qui remplace/fait
> évoluer `apps/mobile/lib/widgets/hi_guided_timer.dart`.
> Tokens uniquement (`HiColors`/`HiType`/`HiSpace`/`HiRadius`/`HiMotion`/`HiShadow`/`HiTap`,
> `HiHaptics`). Signaux = `SystemSound` (`package:flutter/services.dart`) + `HiHaptics`
> UNIQUEMENT. Aucune dépendance native nouvelle. Minuteur sur horloge murale (`DateTime`/
> `Stopwatch`), jamais d'accumulation `+= 100ms`.

---

## 0. Intention & vocabulaire

Le Mode guidé est le **compagnon d'effort** : on pose le téléphone, on lit l'essentiel d'un
coup d'œil (transpiration, bras tendus, lumière de salle), on est porté par les signaux
sonores/haptiques. Il doit donner la même sensation « instrument de sport » que le reste de
l'app — Rajdhani tabulaire, cyan signature, lime réservé à la victoire.

Deux niveaux d'entrée :

| Source | Données | Lecteur |
|---|---|---|
| **WOD structuré** (`WodDetail.prescription`, `WeeklyChallenge.prescription`, WOD custom via `WodEditPayload`) | `format` ∈ {`for_time`, `amrap`, `emom`, `interval`, `tabata`, `strength`} + `blocks` + `timeCapSec` + `rounds` | **Format-aware complet** (§1–§3) |
| **CoachSession** | `description` (texte libre) + `durationMin` | **Mode simplifié** (§4.5) |

**Décision produit verrouillée appliquée ici** : plus de bouton « marquer comme faite ». La
complétion (crédit de série via `POST /v1/coach/sessions/:id/complete`, ou le log de résultat
pour un WOD) se déclenche **automatiquement à l'entrée dans l'état TERMINÉ** — pas d'action
manuelle supplémentaire (voir §3.3 et §6).

Lexique à l'écran :
- **Phase** : segment de temps homogène — `WORK` (travail) ou `REST` (repos).
- **Tour** (round) : répétition complète du bloc (for_time, intervalles).
- **Minute** : segment d'une minute (EMOM).
- **Set** : série de force (strength).

---

## 1. LAYOUT (squelette commun à tous les formats)

Plein écran, `Scaffold` `backgroundColor: HiColors.bgBase`, `SafeArea`, padding
`HiSpace.gutter`. **Garder l'écran allumé pendant la course** (`WakelockPlus` n'est PAS une dépendance
autorisée ici → utiliser uniquement ce qui existe ; si rien n'est dispo, ne pas l'ajouter — noté
en §10 comme limite connue). Colonne verticale, de haut en bas :

```
┌─────────────────────────────────────────────┐
│ [✕]                          FOR TIME · RX    │  (A) Barre d'en-tête
│                                               │
│  ████████████░░░░░░░░░░░░░░░░░░  4:12 / 20:00  │  (B) Barre de progression séance
│                                               │
│            ┌───────────────────┐              │
│            │    ●  TRAVAIL      │              │  (C) Bandeau PHASE (pleine largeur)
│            └───────────────────┘              │
│                                               │
│                                               │
│                 12:48                          │  (D) CHRONO géant (point focal)
│                                               │
│              Tour 3 / 5                        │  (E) Compteur tour / minute / set
│                                               │
│                                               │
│  ┌─────────────────────────────────────────┐  │
│  │  ▶ 21  Thrusters            43 kg         │  │  (F) Panneau CONSIGNES
│  │    21  Pull-ups                            │  │     (élément courant surligné)
│  │    15  Thrusters …                         │  │
│  └─────────────────────────────────────────┘  │
│                                               │
│  [  Pause  ]   [ Tour +1 ]   [  Terminer  ]    │  (G) Contrôles
└─────────────────────────────────────────────┘
```

### (A) Barre d'en-tête
- Gauche : bouton fermer (`Icons.close_rounded`, `iconSize 28`, `HiColors.textSecondary`,
  cible ≥ `HiTap.minTarget`). En course → confirme l'abandon (§5, dialogue « Quitter la
  séance ? »). En prep/terminé → ferme directement.
- Droite : **chip de format** en `HiType.overline` `HiColors.textTertiary` (ex. `FOR TIME`),
  suivi d'un point médian et du tag Rx/Scaled si pertinent (`· RX` en `HiColors.brandPrimary`,
  `· SCALED` en `HiColors.textTertiary`). Sert d'ancrage mental (« je sais ce que je fais »).

### (B) Barre de progression de séance
- Réutiliser exactement la `_ProgressBar` existante (piste `HiColors.bgElevated2`, remplissage
  `HiColors.brandGradient`, `HiRadius.pill`, hauteur 10). Animée `HiMotion.base`/`enter`, figée
  en reduce-motion.
- À droite de la barre, libellé tabulaire `temps écoulé / total` en `HiType.caption`
  `HiColors.textTertiary` (ex. `4:12 / 20:00`). Pour les formats sans total connu (AMRAP sans
  cap, for_time sans cap) : afficher seulement l'écoulé et garder la barre **pleine** (repère
  présent mais non quantifié, comme le chrono libre actuel).

### (C) Bandeau PHASE
Le composant qui change le plus d'un format à l'autre. Pastille pleine largeur, `HiRadius.lg`,
hauteur ~56, centrée :
- **TRAVAIL** : fond `HiColors.success.withValues(alpha: 0.16)`, bordure
  `HiColors.success.withValues(alpha: 0.5)` (1.5px), texte `HiColors.success`, libellé en
  `HiType.titleM`, précédé d'un point plein `●` 10px de la même couleur.
- **REPOS** : fond `HiColors.warn.withValues(alpha: 0.16)`, bordure
  `HiColors.warn.withValues(alpha: 0.5)`, texte `HiColors.warn`. Sous-titre optionnel en
  `HiType.caption` : « Prépare-toi » dans les 3 dernières secondes.
- Formats **sans phases auto** (for_time, amrap, strength libre) : pas de bandeau WORK/REST
  permanent — on affiche à la place un bandeau neutre discret (fond `HiColors.bgElevated`,
  texte `HiColors.textSecondary`) avec l'état (« EN COURS », « EN PAUSE ») OU on masque le
  bandeau et on laisse le chrono respirer. **Choix retenu : masquer** pour for_time/amrap (pas
  de phase = pas de bruit visuel) ; **afficher REPOS** pour strength entre les sets.

Couleur travail = `HiColors.success` (vert, « avance »), couleur repos = `HiColors.warn`
(orange ambré, « tiens-toi prêt / souffle »). On n'utilise JAMAIS `accentVictory` (lime) ici —
réservé au TERMINÉ (Memory : lime = dopamine uniquement). On n'utilise pas `error` (rouge) pour
le repos : le repos n'est pas une faute.

### (D) Chrono géant — point focal
- `HiType.displayXL` `fontSize: 96` (comme l'existant), figures tabulaires garanties par le
  token. Couleur :
  - en cours : `HiColors.textPrimary` ;
  - **3 dernières secondes d'une phase chronométrée** (countdown intra-phase EMOM/interval/
    tabata) : couleur de la phase (success/warn) pour annoncer le basculement ;
  - TERMINÉ : `HiColors.accentVictory`.
- Halo respirant (`HiShadow.glowBrand`) repris de l'existant, désactivé en reduce-motion et hors
  état « running ».
- Format de l'affichage : `mm:ss` par défaut ; bascule `h:mm:ss` au-delà de 60 min. Pour EMOM/
  intervalles, le chrono central affiche **le décompte de la phase en cours** (temps restant
  dans la minute/l'intervalle), pas l'horloge globale — celle-ci vit dans la barre (B).

### (E) Compteur de tour / minute / set
Sous le chrono, `HiType.numericM` `HiColors.textSecondary`, libellé localisé :
- for_time / intervalles : « Tour 3 / 5 » (`guidedRoundOf`)
- EMOM : « Minute 4 / 12 » (`guidedMinuteOf`)
- tabata : « Tour 5 / 8 » (`guidedRoundOf`)
- strength : « Série 2 / 5 » (`guidedSetOf`)
- AMRAP : « Tours : 6 » (`guidedRoundsDone`, sans total — on compte ce qu'on fait)
- for_time sans rounds connus : masqué.

### (F) Panneau CONSIGNES
Carte `HiColors.bgElevated`, `HiRadius.lg`, bordure `HiColors.strokeSubtle`, `HiShadow.e1`,
padding `HiSpace.md`. Liste les `blocks` de la prescription (`reps` + `movement` + charge issue
des `weights` selon le sexe & Rx/Scaled).
- Ligne courante (selon le tour/minute) **mise en avant** : fond
  `HiColors.brandPrimary.withValues(alpha: 0.12)`, marqueur `▶` (`Icons.play_arrow_rounded`)
  `HiColors.brandPrimary` à gauche, texte `HiType.bodyStrong` `HiColors.textPrimary`.
- Lignes secondaires : `HiType.body` `HiColors.textSecondary`, pas de marqueur.
- Reps en `HiType.numericM` (Rajdhani) à gauche pour la lisibilité d'effort ; mouvement en
  Inter ; charge alignée à droite en `HiType.label` `HiColors.textTertiary` (ex. `43 kg`).
- Si > 4 lignes : panneau scrollable interne (max-height ~ 30% écran) ; **ne jamais** pousser
  les contrôles hors écran.
- CoachSession (texte) : panneau affiche la `description` en `HiType.body`, scrollable, sans
  surlignage de ligne (pas de structure machine).

### (G) Contrôles (zone basse, toujours visible, jamais sous le pli)
Boutons d'effort ≥ 64 dp de haut (au-dessus du minimum a11y de 48). Réutiliser `HiButton` /
`HiButtonSecondary` / `HiGhostButton`. Disposition selon l'état (§4) et le format (§2).

---

## 2. VARIANTES PAR FORMAT

Pour chaque format : ce qui est **mis en avant**, le **bandeau phase**, le **chrono central**,
le **compteur**, le **bouton spécifique**.

### 2.1 `for_time` — « le plus vite possible »
- **Chrono central** : COMPTE LE TEMPS ÉCOULÉ (monte). C'est le score → il est roi.
- **Phase** : aucune (masqué). Pas de WORK/REST automatique.
- **Compteur** : « Tour x / N » si `rounds` connus ; sinon masqué.
- **Bouton spécifique** : **« Tour +1 »** (`HiButtonSecondary`, `Icons.add_rounded`, central).
  Chaque tap : `HiHaptics.tap()`, incrémente le tour, fait avancer la ligne surlignée du panneau
  consignes (rotation cyclique sur les blocs), met à jour la barre (B) si total connu, annonce
  « Tour 3 » au lecteur d'écran. Au dernier tour, le bouton devient implicitement le moment de
  « Terminer » (on n'auto-termine pas : l'athlète clôt en franchissant la ligne).
- **Cap** : si `timeCapSec` fourni, la barre (B) se remplit vers le cap ; à l'atteinte → signal
  fort + état TERMINÉ (capped), le chrono se fige sur le cap.
- Contrôles : `[Pause] [Tour +1] [Terminer]`.

### 2.2 `amrap` — « autant de tours que possible en T »
- **Chrono central** : COMPTE À REBOURS depuis `timeCapSec` (la durée EST le cadre). À 0 →
  TERMINÉ automatique (signal fort).
- **Phase** : masquée (effort continu).
- **Compteur** : « Tours : 6 » (incrémenté à la main).
- **Bouton spécifique** : **« Tour +1 »** — c'est le score de l'AMRAP. Même comportement que
  for_time (haptique + avance la consigne + annonce).
- Mise en avant : le **rebours** + le **compteur de tours** côte à côte (le tours est presque
  aussi important que le chrono).
- Contrôles : `[Pause] [Tour +1] [Terminer]`.

### 2.3 `emom` — « every minute on the minute »
- **Phases AUTOMATIQUES** : chaque minute = une phase WORK. Le moteur découpe `rounds` (= nombre
  de minutes) en segments de 60 s. **Pas de REST explicite** (le repos est le temps qu'il reste
  dans la minute après avoir fini les reps) — mais on peut afficher un mini-état « Repos »
  passif si la prescription distingue work/rest (rare ; par défaut WORK pendant 60 s).
- **Chrono central** : COMPTE À REBOURS de la minute en cours (60 → 0), se réarme à chaque
  minute. Les 3 dernières secondes : chiffres en `HiColors.warn` + tic sonore.
- **Compteur** : « Minute 4 / 12 ».
- **Consignes** : ligne surlignée = le mouvement de cette minute (si l'EMOM alterne par minute,
  ex. min impaires / paires → on fait tourner les blocs).
- **Transition de minute** : signal de phase (flash + son + haptique medium) + annonce
  « Minute 5 ».
- Pas de bouton « Tour +1 » (auto). Contrôles : `[Pause] [Skip] [Terminer]`. « Skip » saute à la
  minute suivante (utile si l'athlète finit en avance et veut enchaîner — `HiHaptics.tap`).
- À la dernière minute écoulée → TERMINÉ auto.

### 2.4 `interval` / `tabata` — phases WORK/REST alternées et automatiques
- **Le cœur du format-aware.** Le moteur alterne automatiquement WORK puis REST selon le schéma :
  - **tabata** : schéma fixe 20 s WORK / 10 s REST × 8 tours (valeurs par défaut si non précisé).
  - **interval** : durées WORK/REST issues de la prescription (ex. 60 s / 30 s × `rounds`). Si
    non spécifiées, fallback raisonnable (ex. 40/20) ; à confirmer avec l'API/sport-science.
- **Bandeau PHASE (C)** très visible : alterne TRAVAIL (vert) ↔ REPOS (orange). C'est l'élément
  qu'on lit de loin.
- **Chrono central** : COMPTE À REBOURS de la phase en cours. 3-2-1 final coloré.
- **Compteur** : « Tour 5 / 8 ».
- **Transition WORK→REST et REST→WORK** : chaque bascule = signal de phase complet (flash de la
  couleur entrante en plein écran bref + `SystemSound` + `HiHaptics.impact()`), annonce vocale
  « Repos » / « Travail ».
- Pas de bouton manuel (tout auto). Contrôles : `[Pause] [Skip] [Terminer]` (« Skip » saute la
  phase courante).
- Fin du dernier REST (ou dernier WORK selon schéma) → TERMINÉ auto.

### 2.5 `strength` — « séries lourdes, repos long »
- **Orienté SETS + REPOS**, pas course contre la montre.
- **Chrono central** : sert de **minuteur de repos** entre les séries. Après avoir validé un set
  (« Série faite »), il démarre un COMPTE À REBOURS de repos (défaut 120 s, paramétrable). À 0 →
  signal « C'est reparti » + WORK.
- **Phase** : pendant le repos → bandeau REPOS (orange) avec rebours ; pendant l'effort →
  bandeau neutre « EN COURS » ou masqué (l'athlète gère son set, on ne chronomètre pas la
  poussée).
- **Compteur** : « Série 2 / 5 ».
- **Consignes** : mouvement + charge (`load`/kg) très lisibles (c'est l'info utile).
- **Bouton spécifique** : **« Série faite »** (`HiButton`, `Icons.check_rounded`) → enregistre le
  set, lance le minuteur de repos, surligne la série suivante. Bouton secondaire « +30 s repos »
  / « Passer le repos » pendant le rebours.
- Contrôles (effort) : `[Série faite]` pleine largeur ; (repos) : `[+30 s] [Passer le repos]`.
- Après la dernière série → TERMINÉ.

### Tableau de synthèse

| Format | Chrono central | Phases auto | Compteur | Bouton clé | Fin |
|---|---|---|---|---|---|
| for_time | écoulé ↑ | non | Tour x/N | **Tour +1** | manuelle (ou cap) |
| amrap | rebours ↓ | non | Tours: n | **Tour +1** | auto (T=0) |
| emom | rebours minute ↓ | oui (par minute) | Minute x/N | Skip | auto |
| interval | rebours phase ↓ | oui (WORK/REST) | Tour x/N | Skip | auto |
| tabata | rebours phase ↓ | oui (20/10×8) | Tour x/8 | Skip | auto |
| strength | rebours repos ↓ | repos seulement | Série x/N | **Série faite** | manuelle |

---

## 3. SIGNAUX & FEEL

Tous les signaux passent par **deux canaux simultanés** (visuel + non-visuel) pour rester
perceptibles téléphone à terre, en musique, mains moites.

### 3.1 Banque de signaux (à centraliser dans un helper privé `_GuidedSignals`)
| Évènement | Visuel | Son (`SystemSound`) | Haptique (`HiHaptics`) |
|---|---|---|---|
| Tic de décompte (3,2,1 avant GO ; 3 dernières s de phase) | chiffre coloré + pulse léger | `SystemSoundType.click` | `tap()` |
| GO / début de phase WORK | flash vert plein écran (140 ms) | `SystemSoundType.alert` | `impact()` |
| Début de phase REPOS | flash orange plein écran (140 ms) | `SystemSoundType.click` | `success()` (light) |
| Transition de tour/minute | bandeau pulse | `SystemSoundType.click` | `tap()` |
| TERMINÉ | burst lime (`HiShadow.glowVictory`) + scale-in | `SystemSoundType.alert` | `celebrate()` |
| Pause / Reprise | aucun flash | `click` | `tap()` |

> Note plateforme : `SystemSoundType` n'expose que `click` et `alert` (pas de bibliothèque de
> sons). On joue sur la combinaison son+haptique pour différencier les évènements. C'est
> volontaire et conforme à la contrainte « aucune dépendance native ».

### 3.2 Compte à rebours 3-2-1 avant GO
À chaque passage de PRÉP → EN COURS (et au démarrage de chaque phase WORK des formats à phases),
overlay plein écran : grand chiffre `HiType.displayXL fontSize: 160` centré, `3 → 2 → 1 → GO`,
un tic son+haptique par chiffre, « GO » en `HiColors.accentVictory`. 1 s par étape (horloge
murale). En reduce-motion : pas d'animation de scale, mais les chiffres défilent quand même
(c'est de l'info, pas de la déco) et les tics son/haptique sont conservés.

### 3.3 État TERMINÉ célébratoire
- Chrono passe en `HiColors.accentVictory`, halo `HiShadow.glowVictory` (burst lime — seul
  endroit autorisé), `HiHaptics.celebrate()`, `SystemSoundType.alert`.
- Titre « Séance terminée » `HiType.titleL` lime, sous-titre récap : temps total / tours / sets
  selon format (`HiType.body`).
- **Complétion automatique** (verrouillé) : à l'entrée dans TERMINÉ, le lecteur appelle le
  callback de complétion (CoachSession → `completeCoachSession`; WOD → ouvre la saisie de
  résultat OU log direct, selon le point d'intégration). L'écran montre l'état de ce crédit :
  - en cours : petit spinner + « Validation… » ;
  - succès série : chip `HiColors.success` « Série créditée 🔥 » ;
  - échec réseau : `HiColors.warn` « Pas pu enregistrer — réessayer » + bouton retry (l'effort
    n'est jamais perdu silencieusement).
- Boutons : `[Terminer]` (ferme, renvoie le `Duration`/résultat au parent) + `[Refaire]`
  (`HiGhostButton`, réinitialise à PRÉP). Pas de bouton « marquer comme faite ».

### 3.4 Flash de phase
Overlay `IgnorePointer` couvrant l'écran, couleur de la phase entrante à `alpha 0.22`, qui
s'estompe en `HiMotion.fast` (`exit`). Supprimé entièrement en reduce-motion (le son+haptique+le
bandeau qui change de couleur suffisent).

---

## 4. ÉTATS

Machine à états : `prep → countdown → running → (paused) → finished`. (`countdown` = l'overlay
3-2-1 ; intercalé à chaque (re)démarrage et à chaque début de phase WORK pour les formats à
phases ; configurable « rebours d'entrée » uniquement au tout premier GO si l'utilisateur a
désactivé les rebours par phase — par défaut ON.)

### 4.1 PRÉP (`prep`)
- Chrono affiche la valeur de départ (durée cible, ou `00:00` for_time).
- Bandeau phase masqué ; panneau consignes visible (l'athlète lit le plan avant de lancer).
- Aperçu en tête : nom de séance `HiType.titleM` `HiColors.textSecondary`, durée estimée,
  format. Toggle **son** (§5) accessible ici.
- Contrôle : `[Démarrer]` pleine largeur (`HiButton`, `Icons.play_arrow_rounded`).

### 4.2 COMPTE À REBOURS (`countdown`)
- Overlay 3-2-1 (§3.2). Tappable « Passer » (`HiGhostButton` discret en bas) → GO immédiat.

### 4.3 EN COURS (`running`)
- Halo respirant actif (hors reduce-motion). Tous les signaux de phase actifs.
- Contrôles selon format (§2).

### 4.4 PAUSE (`paused`)
- Chrono figé (l'horloge murale est gelée : on mémorise l'instant de pause et on décale la
  référence au reprise — voir §7). Halo statique. Bandeau phase grisé (`alpha 0.5`).
- Overlay léger « EN PAUSE » `HiType.overline` `HiColors.textTertiary`.
- Contrôles : `[Reprendre]` (relance par un mini 3-2-1 court OU direct selon réglage ; défaut :
  reprise directe pour ne pas casser le rythme) + `[Réinitialiser]` (`HiGhostButton`) +
  `[Terminer]` (`HiButtonSecondary`).

### 4.5 MODE SIMPLIFIÉ (CoachSession texte)
Même squelette, dégradé :
- **Chrono** : rebours sur `durationMin` si fournie, sinon chrono libre (montant) — exactement
  le comportement actuel de `HiGuidedTimer`.
- **Phase** : masquée (pas de structure).
- **Compteur** : compteur de tour **MANUEL** facultatif, libellé « Tours : n » + bouton
  « Tour +1 » (`HiButtonSecondary`) — laissé à l'athlète qui veut suivre ses tours. S'il ne tape
  jamais, le compteur reste à 0 et est discret.
- **Consignes** : `description` texte intégrale, scrollable, `HiType.body`. Pas de surlignage.
- **Fin** : TERMINÉ → `completeCoachSession` auto (crédit série). Récap = temps total + tours
  comptés.
- Contrôles : EN COURS `[Pause] [Tour +1] [Terminer]` ; le `[Tour +1]` est optionnel et peut
  être masqué si on juge le bruit inutile (proposition : le garder, discret).

### 4.6 États transverses (vide / erreur)
- Prescription absente ou `blocks` vide sur un WOD censé être structuré → **repli en mode
  simplifié** (chrono + consignes texte si dispo, sinon chrono seul). Ne jamais planter ni
  afficher un panneau vide.
- Erreur de complétion en TERMINÉ → traité en §3.3 (warn + retry), l'écran reste utilisable.

---

## 5. A11Y + REDUCE-MOTION + SON

### 5.1 Lecteur d'écran (annonces de phase via liveRegion)
- Le bandeau PHASE (C) est un `Semantics(liveRegion: true, label: …)`. À chaque changement de
  phase, le label change (« Travail », « Repos ») → annoncé automatiquement par TalkBack/
  VoiceOver. **Throttle** : ne pas ré-annoncer plus d'une fois par phase.
- Le compteur (E) est aussi `liveRegion` pour annoncer « Tour 3 », « Minute 5 », « Série 2 ».
  Pour éviter le spam, n'annoncer que les changements entiers (pas chaque seconde).
- Le chrono (D) reste **exclu** de la sémantique seconde par seconde (sinon flot continu
  insupportable) : on garde le pattern actuel `Semantics(label: a11yGuidedTimerValue(...))` +
  `ExcludeSemantics` sur le texte, et on **n'actualise le label que toutes les 5 s** ou sur
  évènement de phase.
- Les 3-2-1 : annoncés (« Trois », « Deux », « Un », « C'est parti ») via liveRegion de
  l'overlay.

### 5.2 Cibles tactiles
- Bouton fermer & toggles ≥ `HiTap.minTarget` (48). Boutons d'effort (Démarrer/Pause/Terminer/
  Tour +1/Série faite) ≥ 64 (cohérent avec le widget actuel). Espacement ≥ `HiSpace.md` entre
  boutons adjacents pour éviter les mistaps en sueur.

### 5.3 Reduce-motion (`MediaQuery.disableAnimationsOf`)
Quand actif :
- **Pas de flash** de phase, **pas de pulse** de halo, **pas de scale** sur le 3-2-1, transitions
  de barre/bandeau **instantanées** (`AnimatedContainer` → set direct, comme la `_ProgressBar`
  existante le fait déjà).
- **Conservés** : tous les signaux **haptiques** et **sonores** (ce sont des infos d'effort, pas
  de la déco), le changement de **couleur** des bandeaux (instantané), les **annonces** lecteur
  d'écran, le décompte 3-2-1 (chiffres qui défilent sans animation).
- Le halo passe en statique `value 0.5` (déjà le comportement de `_syncPulse`).

### 5.4 Toggle son ON/OFF
- Icône `Icons.volume_up_rounded` / `Icons.volume_off_rounded` en haut à droite de la barre (A),
  cible ≥ 48, `Semantics` button avec label « Activer/Couper le son ». État persistant (préférence
  locale, ex. `SharedPreferences`) pour ne pas le redemander.
- OFF coupe **uniquement** `SystemSound` ; l'haptique reste (sauf si l'OS l'a désactivée). Aucun
  réglage haptique séparé pour rester simple — l'haptique respecte déjà les réglages système.
- Le contraste des bandeaux WORK/REST est vérifié AA : `success`/`warn` en texte sur fond
  `bgBase`/élevé sont déjà calibrés AA dans les deux thèmes (cf. commentaires `tokens.dart`).

---

## 6. INTÉGRATION (pour le dev) — contrat d'API du widget

Faire évoluer `HiGuidedTimer` (ou créer `HiGuidedPlayer` à côté et le faire pointer par les
écrans cités). Signature proposée :

```dart
HiGuidedPlayer.push(
  context,
  title: wod.name,
  format: 'interval',                  // null/inconnu → mode simplifié
  blocks: prescription.blocks,         // List<WodBlock>
  weights: prescription.weights,       // pour afficher la charge selon sex + rx/scaled
  sex: 'male',
  scaled: false,
  rounds: prescription /* timeCap */,  // rounds / timeCapSec selon format
  timeCapSec: prescription.timeCapSec,
  durationMin: coach.durationMin,      // fallback simplifié / amrap
  descriptionText: coach.description,  // CoachSession → mode simplifié
  onCompleted: () => api.completeCoachSession(id), // OU log WOD ; appelé en TERMINÉ
);
```

Points d'entrée à brancher (remplacer l'appel `HiGuidedTimer.push` existant) :
- `coach_library_screen.dart` : `_openGuided` → passe `descriptionText` + `durationMin`. **Retirer
  le bouton « marquer comme faite »** (la complétion est désormais auto en TERMINÉ via
  `onCompleted`).
- `wod_detail_screen.dart` : bouton « Mode guidé » à partir de `WodDetail.prescription`.
- `league_screen.dart` `_doWeekWod` : lance le lecteur sur la prescription du WOD imposé.
- WOD custom : `WodEditPayload` (type + blocks + rounds + timeCapSec) → mêmes champs.

Le widget reste autonome (pas de Riverpod requis) ; il rend `onCompleted` idempotent côté appel
(ne pas double-créditer si l'utilisateur fait « Refaire » puis re-termine — gérer un flag « déjà
crédité pour ce run »).

---

## 7. MINUTEUR (horloge murale — verrouillé)

- Garder un `Stopwatch` OU une référence `DateTime startedAt` ; à chaque tick UI (`Timer.periodic`
  100 ms, **pour rafraîchir l'affichage seulement**), calculer
  `elapsed = DateTime.now().difference(_startWall) - _pausedAccumulated`. **Ne jamais** faire
  `_elapsed += tick` (dérive garantie).
- **Pause** : mémoriser `_pauseStart = DateTime.now()` ; à la reprise, `_pausedAccumulated +=
  now - _pauseStart`.
- **Phases** (emom/interval/tabata) : calculer la phase courante et le reste **à partir de
  l'écoulé réel** (`elapsed`) et du schéma, pas d'un compteur incrémental. Ainsi un tick raté ou
  un retour de veille ne désynchronise rien.
- **Retour au premier plan** (`WidgetsBindingObserver.didChangeAppLifecycleState` →
  `AppLifecycleState.resumed`) : recalculer immédiatement `elapsed`, la phase, le tour ; rejouer
  un éventuel signal de phase manqué **une seule fois** (pas de rafale), resynchroniser
  l'affichage. En background, le `Timer` peut être suspendu par l'OS — c'est sans conséquence
  puisque l'état dérive de l'horloge murale.

---

## 8. LIBELLÉS i18n (à créer — FR + EN)

À ajouter dans `app_fr.arb`, `app_en.arb`, `app_localizations.dart` + `_fr` + `_en` (édition
manuelle, puis `flutter gen-l10n`). Préfixe `guided…` (cohérent avec `guidedTimer…` existant).

| Clé | FR | EN |
|---|---|---|
| `guidedPhaseWork` | Travail | Work |
| `guidedPhaseRest` | Repos | Rest |
| `guidedPhasePrepare` | Prépare-toi | Get ready |
| `guidedStateRunning` | En cours | In progress |
| `guidedStatePaused` | En pause | Paused |
| `guidedRoundOf` | Tour {current} / {total} | Round {current} / {total} |
| `guidedMinuteOf` | Minute {current} / {total} | Minute {current} / {total} |
| `guidedSetOf` | Série {current} / {total} | Set {current} / {total} |
| `guidedRoundsDone` | Tours : {count} | Rounds: {count} |
| `guidedAddRound` | Tour +1 | Round +1 |
| `guidedSetDone` | Série faite | Set done |
| `guidedRest` | Repos | Rest |
| `guidedAddRest` | +30 s repos | +30s rest |
| `guidedSkipRest` | Passer le repos | Skip rest |
| `guidedSkip` | Passer | Skip |
| `guidedStart` | Démarrer | Start |
| `guidedPause` | Pause | Pause |
| `guidedResume` | Reprendre | Resume |
| `guidedFinish` | Terminer | Finish |
| `guidedReset` | Réinitialiser | Reset |
| `guidedRedo` | Refaire | Redo |
| `guidedGo` | C'est parti ! | Go! |
| `guidedCountdownGo` | GO | GO |
| `guidedDone` | Séance terminée | Workout complete |
| `guidedTotalTime` | Temps total {time} | Total time {time} |
| `guidedStreakCredited` | Série créditée 🔥 | Streak credited 🔥 |
| `guidedValidating` | Validation… | Saving… |
| `guidedCreditFailed` | Impossible d'enregistrer — réessayer | Couldn't save — retry |
| `guidedQuitTitle` | Quitter la séance ? | Quit the workout? |
| `guidedQuitBody` | Ta progression de cette séance sera perdue. | Your progress for this workout will be lost. |
| `guidedQuitConfirm` | Quitter | Quit |
| `guidedQuitCancel` | Continuer | Keep going |
| `guidedSoundOn` | Couper le son | Mute sound |
| `guidedSoundOff` | Activer le son | Unmute sound |
| `guidedClose` | Fermer | Close |
| `a11yGuidedPhaseWork` | Travail | Work |
| `a11yGuidedPhaseRest` | Repos | Rest |
| `a11yGuidedRound` | Tour {n} | Round {n} |
| `a11yGuidedMinute` | Minute {n} | Minute {n} |
| `a11yGuidedSet` | Série {n} | Set {n} |
| `a11yGuidedCountdown` | {n} | {n} |

Réutiliser les `guidedTimer…` existants si déjà présents (`guidedTimerClose`, `guidedTimerStart`,
etc.) plutôt que dupliquer — au dev de mutualiser. Le format chip (FOR TIME, AMRAP…) réutilise les
`wodFmt…` déjà localisés (`wodFmtForTime`, `wodFmtAmrap`, `wodFmtEmom`, `wodFmtInterval`,
`wodFmtTabata`, `wodFmtStrength`).

---

## 9. CHECKLIST DEV (Definition of Done UI)

- [ ] Minuteur horloge murale + resync `resumed` (jamais `+= tick`).
- [ ] Bandeau phase WORK=`success` / REST=`warn`, contraste AA, `liveRegion`.
- [ ] Chrono `HiType.displayXL` tabulaire, lime uniquement en TERMINÉ.
- [ ] Variantes des 6 formats branchées sur `format` (fallback simplifié si inconnu/vide).
- [ ] Signaux = `SystemSound` + `HiHaptics` seulement ; double canal ; throttle annonces.
- [ ] Reduce-motion : flash/pulse/scale coupés, haptique+son+annonces conservés.
- [ ] Toggle son persistant ; cibles ≥ 48 (≥ 64 pour l'effort).
- [ ] Complétion **auto** en TERMINÉ (idempotente) ; états validation/succès/échec gérés.
- [ ] Aucun bouton « marquer comme faite » nulle part.
- [ ] i18n FR+EN ajouté ; `flutter gen-l10n` passe.

## 10. Limites connues / à confirmer
- Schémas WORK/REST de `interval` (et reps par minute d'EMOM alternant) ne sont peut-être pas
  encodés dans `WodBlock` aujourd'hui (qui est `reps`+`movement`+`detail`). **À cadrer avec
  l'architecte/sport-science** : soit la prescription porte ces durées, soit le lecteur applique
  des défauts (tabata 20/10×8 ; interval 40/20 ; emom 60 s) et le `detail` textuel guide
  l'athlète. Le mode simplifié est le filet de sécurité quand la structure manque.
- Maintien de l'écran allumé : aucune dépendance native autorisée → si le projet n'a pas déjà de
  solution, l'écran peut s'éteindre. À signaler comme dette si gênant en test terrain.

---

## Résumé des décisions visuelles clés
1. **Un squelette, six visages.** Même layout (en-tête / barre séance / bandeau phase / chrono
   géant / compteur / consignes / contrôles) ; seuls le chrono (écoulé vs rebours vs rebours de
   phase), le bandeau phase, le compteur et le bouton clé changent par format.
2. **Couleurs d'effort sémantiques** : TRAVAIL = `success` (vert, avance), REPOS = `warn`
   (orange, souffle), jamais de rouge (le repos n'est pas une faute). **Lime = TERMINÉ
   uniquement** (dopamine), conforme à la règle de l'app.
3. **Chrono Rajdhani tabulaire roi**, halo cyan respirant ; 3 dernières secondes colorées par la
   phase pour annoncer la bascule.
4. **3-2-1 → GO** plein écran avant chaque WORK ; **TERMINÉ célébratoire** (burst lime,
   `celebrate()`), avec **complétion automatique** (plus de « marquer comme faite »).
5. **Signaux double canal** son (`SystemSound`) + haptique (`HiHaptics`), sans dépendance native ;
   visuel en bonus, retiré en reduce-motion mais son/haptique/annonces conservés.
6. **Minuteur horloge murale** + resync au premier plan (zéro dérive).
7. **Mode simplifié** pour CoachSession (chrono + texte + tour manuel) = filet de sécurité aussi
   pour tout WOD sans prescription structurée.
8. **Accessibilité native** : bandeaux phase & compteur en `liveRegion` (annonces « Travail »,
   « Repos », « Tour 3 »), chrono exclu du flot seconde-par-seconde, cibles ≥ 48 / 64,
   toggle son.
