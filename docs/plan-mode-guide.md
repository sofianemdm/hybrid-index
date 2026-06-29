# Plan d'architecture — Lecteur de séance guidée (« Mode guidé »)

> Auteur : agent **architect**. Statut : PLAN À VALIDER avant code (règle de travail §1).
> Lot verrouillé : completion auto en fin de plan ; lecteur format-aware (WOD structuré) +
> mode simplifié (CoachSession texte) ; signaux = `SystemSound` + `HiHaptics` **uniquement**
> (zéro dépendance native) ; minuteur sur **horloge murale** (Stopwatch/DateTime), jamais
> d'accumulation `+= 100ms` ; resync au retour premier plan.

---

## 0. Constat sur l'existant (ce qu'on remplace / fait évoluer)

- `apps/mobile/lib/widgets/hi_guided_timer.dart` = chrono générique mono-phase. Deux défauts
  bloquants pour ce lot :
  1. **Accumulation `_elapsed += _tick`** (ligne 121) → dérive de temps interdite par la décision (4).
  2. **Mono-phase** (ready/running/paused/finished) : aucune notion de tours, de fenêtres
     travail/repos, de top de minute. Inutilisable pour AMRAP/EMOM/intervalles/Tabata.
  Il reste un bon **socle visuel** (chrono géant Rajdhani, halo respirant, barre de progression,
  contrôles, a11y, reduce-motion). On **réutilise le rendu**, on **remplace le moteur**.

- `coach_library_screen.dart` : bouton **« Marquer comme faite »** (`_markDone`, ligne 285) à
  **RETIRER** (décision 1). La complétion passe désormais par la fin du Mode guidé.

- Points d'entrée actuels du Mode guidé : seulement `coach_library_screen._openGuided`.
  Cibles d'intégration ajoutées : `wod_detail_screen.dart`, `league_screen._doWeekWod`
  (qui route déjà vers `WodDetailScreen`), WOD custom (même fiche).

---

## 1. Modèle `GuidedPlan` (structure normalisée qui pilote le lecteur)

Nouveau fichier **`apps/mobile/lib/features/guided/guided_plan.dart`** (logique pure, testable,
sans Flutter sauf `Duration`). Le lecteur ne lit JAMAIS un `WodDetail`/`CoachSession` directement :
il consomme un `GuidedPlan` déjà normalisé. C'est la frontière qui rend le moteur testable et
réutilisable depuis tous les points d'entrée.

```dart
enum GuidedPhaseKind { prep, work, rest, roundBreak, done }

/// Une phase atomique de la séance. Le lecteur déroule la liste `phases` dans l'ordre.
class GuidedPhase {
  final GuidedPhaseKind kind;
  /// Durée bornée de la phase. null = phase OUVERTE (count-up libre, l'athlète termine à la main) :
  /// utilisée pour for_time sans cap, pour le repos auto-réglé strength, etc.
  final Duration? duration;
  /// Libellé court affiché (ex. « Échauffe-toi », « TRAVAIL », « REPOS », « Tour 2 / 5 », « Minute 3 / 10 »).
  final String label;
  /// Consigne longue optionnelle (mouvements à enchaîner) affichée sous le chrono.
  final String? cue;
  /// Numéro de tour 1-based si la phase appartient à un tour (sinon null) — pour « Tour k/N ».
  final int? roundIndex;
  const GuidedPhase({required this.kind, this.duration, required this.label, this.cue, this.roundIndex});
}

/// Comment le chrono se comporte pendant une phase de travail :
/// - countUp  : le temps MONTE (for_time, strength, free-run) — pas de cible de phase.
/// - countDown: le temps DESCEND vers 0 (AMRAP total, fenêtre EMOM, travail interval/tabata).
enum GuidedClock { countUp, countDown }

class GuidedPlan {
  /// Format source ('for_time'|'amrap'|'emom'|'interval'|'tabata'|'strength'|'free') — pilote l'UI.
  final String format;
  final GuidedClock clock;
  /// Nombre de tours/rounds total si connu (affichage « Tour k/N »), sinon null.
  final int? totalRounds;
  /// Cap global de la séance en secondes (for_time/amrap), sinon null.
  final Duration? cap;
  /// Liste ORDONNÉE des phases. La dernière est toujours GuidedPhaseKind.done.
  final List<GuidedPhase> phases;
  /// Consignes générales (mouvements + charges) affichées en bas / au repos.
  final List<String> cues;
  /// La séance produit-elle un RÉSULTAT loguable (WOD) ? Si oui, wodId + scoreType pour router
  /// vers la saisie. Si non (CoachSession), coachSessionId pour créditer la série.
  final String? wodId;
  final String? scoreType;
  final String? coachSessionId;
  /// Compteur de tours manuel pertinent ? (for_time/amrap sans rounds machine-lisibles, mode simplifié).
  final bool manualRoundCounter;

  const GuidedPlan({
    required this.format,
    required this.clock,
    this.totalRounds,
    this.cap,
    required this.phases,
    this.cues = const [],
    this.wodId,
    this.scoreType,
    this.coachSessionId,
    this.manualRoundCounter = false,
  });
}
```

**Pourquoi des phases pré-calculées plutôt qu'un moteur paramétrique ?** Une liste de phases
linéaire rend la machine à états triviale (index courant + temps dans la phase), rend
`skip/précédent` gratuit (déplacer l'index), et se teste sans Flutter (on assert sur
`phases.length`, `kind`, `duration`). C'est l'arbitrage qualité>vitesse de la constitution.

---

## 2. Construction du plan par format (`GuidedPlanBuilder`)

Toujours dans `guided_plan.dart`, fonctions pures. Entrée = champs déjà disponibles (cf. §3).

### `for_time`
- `clock = countUp`. Une seule `GuidedPhase(work, duration: cap)` si `cap` connu (le chrono monte,
  s'arrête au cap), sinon `duration: null` (count-up libre, fin manuelle).
- `manualRoundCounter = true` (l'athlète tape « +1 tour » ; on n'a pas les reps en temps réel).
- `totalRounds` = `rounds` si exposé (cf. §3), sinon null (compteur libre).
- Dérivé de : `format=for_time`, `prescription.timeCapSec → cap`, `rounds → totalRounds`.

### `amrap`
- `clock = countDown`. UNE phase `work` avec `duration = cap` (durée AMRAP = le `timeCapSec`).
- `manualRoundCounter = true` (tally tours/reps réalisés pendant le décompte).
- Top sonore à 0 → `done`. Dérivé de : `prescription.timeCapSec` (obligatoire pour un AMRAP).

### `emom`
- `clock = countDown` par minute. On génère **N phases `work` de 60 s**, une par minute, chacune
  `label = "Minute k / N"`, `roundIndex = k`. N = `totalRounds` (nombre de minutes).
- Top de minute = transition de phase → signal (SystemSound + haptique) à chaque passage k→k+1.
- Dérivation de N : `rounds` si exposé ; sinon, repli = `cap / 60` ; sinon défaut documenté
  (10) avec bandeau « durée estimée ». **C'est le format qui motive le plus l'ajout API §3.**

### `interval` & `tabata`
- `clock = countDown` sur chaque fenêtre. Alternance **TRAVAIL → REPOS** répétée `rounds` fois.
  - `tabata` : work 20 s / rest 10 s × 8 (constantes canoniques si non fournies).
  - `interval` : work/rest depuis la structure si dispo, sinon valeurs par défaut documentées.
- Génère `2*rounds` phases (work,rest,work,rest,…), chaque work `roundIndex = k`,
  `label` alternant « TRAVAIL » / « REPOS », dernière `rest` éventuellement supprimée.
- Top à CHAQUE bascule travail/repos (signal distinct travail vs repos via deux sons système).

### `strength`
- `clock = countUp` pendant la série (l'athlète exécute ses reps), `rest` chronométré entre séries.
- Génère, pour `sets` séries : `work(open)` → `rest(duration: restSec)` → … La dernière série n'a
  pas de repos. `label = "Série k / N"`. Repos par défaut documenté (ex. 120 s) si non fourni.
- `manualRoundCounter = false` (on compte des séries, gérées par les phases).

### Mode simplifié (CoachSession texte) — `format = 'free'`
- Pas de structure machine-lisible (CoachSession = description texte seule). Plan minimal :
  - `clock = countDown` si `durationMin > 0` (cible = durée séance), sinon `countUp` libre.
  - UNE phase `work` (duration = durationMin ou null) + `cue = description`.
  - `manualRoundCounter = true` (compteur de tours manuel, optionnel pour l'athlète).
  - `coachSessionId` renseigné → completion via `/complete` (cf. §5).

Une `prep` (compte à rebours d'entrée « 3-2-1 GO », ex. 10 s, sautable) est préfixée à tous les
plans non-`free` pour caler le départ — phase `GuidedPhaseKind.prep`.

---

## 3. Disponibilité des données + ajout API minimal

**Audit (sources lues) :** `apps/api/.../wods.service.ts > detail()` et `models.dart > WodDetail`.

`detail()` renvoie, **pour TOUT WOD** (officiel + custom) :
- `type` (= le format brut : `for_time|amrap|emom|interval|tabata|strength|chipper|distance`),
- `prescription.format` (chaîne FR libre), `prescription.timeCapSec`, `prescription.blocks`,
  `prescription.weights`, `prescription.scoringNote`, `scalable`.

`rounds` (entier structuré) et la **structure interval/tabata/emom** (work/rest/sets) ne sont
exposés QU'AU CRÉATEUR via `editPayload` (custom). **Donc la structure n'est PAS disponible à tous.**
De plus `WodDetail.fromJson` **ne parse même pas `type`** aujourd'hui.

### Ajout API minimal (autorisé par la consigne)

Ajouter un bloc **`guided`** à la réponse de `GET /v1/wods/:id`, calculé côté serveur pour
**tous** les utilisateurs (pas seulement l'auteur), non sensible (c'est l'énoncé public) :

```jsonc
"guided": {
  "format": "emom",            // = wod.type normalisé
  "rounds": 10,                // wod.rounds ?? null
  "capSec": 600,               // prescription.timeCapSec ?? wod.timeCapSec ?? null
  "work": [                    // segments structurés QUAND ils existent (interval/tabata/emom)
    { "kind": "work", "durationSec": 20 },
    { "kind": "rest", "durationSec": 10 }
  ],
  "cues": ["21-15-9 Thrusters", "21-15-9 Tractions"]  // dérivé des blocks (reps + movement [+ detail])
}
```

- Implémentation : une fonction `buildGuided(wod, prescription)` dans `wods.service.ts`, appelée
  dans `detail()`, à côté de `prescription`. `cues` = `blocks.map(b => "${reps} ${movement}${detail?}")`.
- `work[]` n'est rempli que pour les formats à fenêtres ; sinon omis (le builder client retombe
  sur les constantes canoniques + `capSec`/`rounds`).
- **Aucune migration DB** : tout est dérivé de colonnes/prescriptions existantes.

Côté mobile :
- Ajouter `WodGuided` à `models.dart` (parse du bloc `guided`) + champ `guided` sur `WodDetail`.
- `GuidedPlanBuilder.fromWod(WodGuided, {scoreType, wodId})` et
  `GuidedPlanBuilder.fromCoachSession(CoachSession)`.

**Repli sans ajout API (sécurité de livraison) :** si le champ `guided` est absent (vieux back),
le builder dérive le plan du seul couple `type` + `prescription.timeCapSec` → for_time/amrap/free
fonctionnent ; emom/interval/tabata tombent en mode count-up + compteur manuel. v1 reste livrable.

---

## 4. Machine à états + horloge murale

Nouveau **`apps/mobile/lib/features/guided/guided_runner.dart`** (state) +
**`guided_player_screen.dart`** (UI, héritière visuelle de `HiGuidedTimer`).

### Horloge murale (décision 4 — non négociable)
- Source de temps = **`Stopwatch`** (monotone) ; le `Timer.periodic(100ms)` ne sert QU'À
  rafraîchir l'affichage, jamais à mesurer. À chaque tick :
  `elapsedInPhase = _stopwatch.elapsed - _phaseStartOffset` (et on retranche le temps de pause
  cumulé). **Jamais `+= 100ms`.**
- Le temps restant d'une phase bornée = `phase.duration - elapsedInPhase`. La bascule de phase est
  déclenchée par comparaison de temps réel, pas par comptage de ticks.

### États
`ready → prep? → (work/rest/roundBreak)* → done`. Le runner tient :
`currentPhaseIndex`, `_stopwatch`, `_pausedAccum`, `manualRounds`. Transitions :
- **pause** : `_stopwatch.stop()` (le temps gelé est exact, pas de dérive).
- **reprise** : `_stopwatch.start()`.
- **skip** : passe à `currentPhaseIndex + 1`, réinitialise l'offset de phase.
- **précédent** : `currentPhaseIndex - 1` (≥ 0).
- **fin de phase** : si `duration != null` et `elapsedInPhase >= duration` → avance ; signal.

### Resync au retour premier plan (`WidgetsBindingObserver`)
- Le `GuidedPlayerScreen` implémente `WidgetsBindingObserver`. Sur `AppLifecycleState.resumed`,
  on **recalcule** la phase courante à partir du `Stopwatch` (qui a continué de courir en arrière-plan
  si l'app n'a pas été tuée) : on « rejoue » les bascules de phase manquées et on resynchronise
  l'affichage. Le `Timer` UI est annulé sur `paused`/recréé sur `resumed` (économie batterie), le
  `Stopwatch` n'est jamais arrêté par le cycle de vie (seulement par la pause utilisateur).

### Signaux (décision 3 — `SystemSound` + `HiHaptics` UNIQUEMENT)
- `package:flutter/services.dart` → `SystemSound.play(SystemSoundType.click)` (déjà importé ailleurs,
  zéro dépendance). Combiné à `HiHaptics`. Table des signaux :
  - prep 3-2-1 : `HiHaptics.tap()` + `SystemSound.click` à chaque seconde finale.
  - top de minute (EMOM) / bascule travail↔repos : `HiHaptics.impact()` + `SystemSound.click`.
  - début TRAVAIL : `HiHaptics.impact()` ; début REPOS : `HiHaptics.tap()` (distinction tactile).
  - fin de plan (`done`) : `HiHaptics.celebrate()` + `SystemSound.alert`.
- Respect reduce-motion pour le halo (déjà géré par le socle visuel). Le son reste (information,
  pas décoration) ; haptique inchangée.

---

## 5. Complétion (retrait de « Marquer comme faite » + auto-completion)

### Retrait
- Supprimer le bouton **« Marquer comme faite »** et `_markDone` de `coach_library_screen.dart`.
  La carte ne garde qu'une action primaire **« Mode guidé »**.

### Auto-completion en fin de plan (`done`)
Le runner expose `onCompleted(GuidedPlan, Duration elapsed)`. Comportement selon la nature :

- **CoachSession (`coachSessionId != null`)** : appel **automatique**
  `api.completeCoachSession(id)` (best-effort, idempotent/jour — déjà en place). Feedback :
  `Celebration` + SnackBar honnête (série créditée vs synchro échouée), repris tel quel de
  l'ancien `_markDone`. **Aucune saisie de résultat** (pas de WOD/barème).

- **WOD loguable (`wodId != null`)** : à `done`, le lecteur **propose la saisie du résultat**
  (route existante `WodResultEntryScreen(wodId, scoreType, scalable)`), **pré-remplie** quand le
  format donne le résultat « gratuitement » :
  - for_time avec chrono → `rawResult = elapsed` (secondes) pré-rempli ;
  - amrap/strength/reps → champ vide + `manualRounds` proposé comme amorce.
  Si l'athlète **annule** la saisie : on ne ment pas (pas de log), mais la **série est créditée**
  via le même mécanisme de complétion guidée (la séance a bien été FAITE). Décision : « proposer la
  saisie OU au moins marquer fait » → on fait **les deux** (saisie proposée, fait garanti).

Flux : `GuidedPlayerScreen.pop(result)` renvoie un `GuidedOutcome { completed, elapsed, loggedWodId? }`
au point d'entrée, qui décide du refresh (la fiche WOD / la ligue se rafraîchissent déjà au retour).

---

## 6. Intégration — un point d'entrée uniforme

Helper unique **`apps/mobile/lib/features/guided/guided_entry.dart`** :

```dart
Future<GuidedOutcome?> startGuided(BuildContext context, {
  required GuidedPlan plan,   // construit par GuidedPlanBuilder.fromWod / .fromCoachSession
});
// + 2 fabriques de confort :
Future<GuidedOutcome?> startGuidedForWod(BuildContext, WodDetail);
Future<GuidedOutcome?> startGuidedForSession(BuildContext, CoachSession);
```

Câblage des cibles :
- **`coach_library_screen`** : bouton « Mode guidé » → `startGuidedForSession`.
- **`wod_detail_screen`** : nouveau bouton primaire « Mode guidé » (à côté de « Faire cette
  épreuve » `_doWod`) → `startGuidedForWod(d)` ; au retour `completed`, refresh comme `_doWod`.
- **`league_screen._doWeekWod`** : inchangé (route vers `WodDetailScreen` qui porte désormais le
  bouton). Pas de duplication.
- **WOD custom** : même `WodDetailScreen` → marche via le repli `guided`/`type` (§3).

---

## 7. Découpage en incréments

### v1 — livré maintenant (vérifiable)
1. **API** : bloc `guided` sur `GET /v1/wods/:id` + test (`wods.spec.ts`).
2. **Modèle + builder** : `guided_plan.dart` (`GuidedPlan`, `GuidedPhase`, `GuidedPlanBuilder`)
   + `WodGuided` dans `models.dart`. **Tests unitaires purs** sur les 6 formats + free + repli
   (couverture élevée : c'est de la logique, règle §4).
3. **Runner horloge murale** : `guided_runner.dart` (Stopwatch, pause/reprise/skip/précédent,
   bascule de phase) + tests sur l'avance de phase et l'absence de dérive.
4. **UI** : `guided_player_screen.dart` (réemploi du rendu de `HiGuidedTimer` : chrono géant,
   halo, barre, contrôles) + bandeau de phase (label/roundIndex), compteur manuel, consignes.
   Signaux SystemSound+HiHaptics, resync `WidgetsBindingObserver`.
5. **Complétion** : auto `/complete` (CoachSession) ; proposition de saisie + fait garanti (WOD).
6. **Intégration** : `guided_entry.dart` + câblage coach_library / wod_detail. Retrait de
   « Marquer comme faite ».
7. **i18n** : nouvelles clés (labels de phase, « Tour k/N », « Minute k/N », TRAVAIL/REPOS,
   skip/précédent, compteur de tours) dans les 5 fichiers ARB/localizations à la main + `flutter gen-l10n`.

### Différé (documenté, hors v1)
- Structure `interval`/`tabata`/`emom` finement paramétrable côté **builder de WOD custom**
  (saisie work/rest/sets) — v1 utilise les constantes canoniques + `rounds`/`cap`.
- Maintien d'écran allumé (wakelock) — nécessiterait une dépendance native → reporté
  (incompatible décision 3 pour l'instant ; à arbitrer produit).
- Audio riche (voix/bips custom) — exclu par décision 3.
- `HiGuidedTimer` : conservé en v1 (repli), supprimé une fois toutes les cibles migrées.

---

## Résumé des décisions

- `GuidedPlan` = **liste de phases pré-calculées** + métadonnées de format ; le lecteur ne voit
  jamais un `WodDetail` brut. Frontière testable, machine à états triviale.
- Le serveur expose un bloc **`guided`** sur `GET /v1/wods/:id` (dérivé, sans migration) car la
  structure (rounds/work/rest) n'est aujourd'hui PAS disponible aux non-auteurs. Repli client si
  le champ est absent → v1 livrable même sans le back.
- **Horloge murale** via `Stopwatch` ; le `Timer` ne fait que rafraîchir l'écran. Resync sur
  `resumed`. **Aucune accumulation de ticks.**
- Signaux = **`SystemSound` + `HiHaptics`** seulement. **Zéro nouvelle dépendance.**
- « Marquer comme faite » **retiré** ; complétion **auto** en fin de plan (CoachSession → `/complete` ;
  WOD → saisie proposée + fait garanti).
- **Un** helper d'entrée `startGuided*` réutilisé par coach_library, wod_detail, league (via la fiche),
  WOD custom.

## Fichiers / ajouts prévus

**Création (mobile)**
- `apps/mobile/lib/features/guided/guided_plan.dart` — modèle + builder (logique pure).
- `apps/mobile/lib/features/guided/guided_runner.dart` — machine à états + horloge murale.
- `apps/mobile/lib/features/guided/guided_player_screen.dart` — UI du lecteur.
- `apps/mobile/lib/features/guided/guided_entry.dart` — helper d'entrée + `GuidedOutcome`.
- Tests : `apps/mobile/test/guided_plan_test.dart`, `apps/mobile/test/guided_runner_test.dart`.

**Modification (mobile)**
- `apps/mobile/lib/data/models.dart` — `WodGuided` + champ `guided` (+ parse `type`) sur `WodDetail`.
- `apps/mobile/lib/features/coach/coach_library_screen.dart` — retrait « Marquer comme faite » /
  `_markDone` ; bouton unique « Mode guidé ».
- `apps/mobile/lib/features/wods/wod_detail_screen.dart` — bouton « Mode guidé » + refresh au retour.
- `apps/mobile/lib/widgets/hi_guided_timer.dart` — conservé en repli v1 (rendu réutilisé), retiré à terme.
- i18n : `app_fr.arb`, `app_en.arb`, `app_localizations.dart`, `_fr.dart`, `_en.dart` (édition manuelle + `gen-l10n`).

**Modification (API)**
- `apps/api/src/modules/wods/wods.service.ts` — `buildGuided(wod, prescription)` + champ `guided` dans `detail()`.
- `apps/api/test/wods.spec.ts` — couverture du bloc `guided` (formats + cues + repli).
