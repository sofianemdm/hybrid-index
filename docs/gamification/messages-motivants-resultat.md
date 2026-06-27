# Messages motivants post-résultat — Spec gamification

> Statut : spec verrouillée pour implémentation. Ce document définit des RÈGLES et des CHAÎNES
> exactes ; les ingénieurs implémentent. Source de vérité produit : `docs/cahier-des-charges.md`
> (§3-4, §11-12, §14). Aligné sur le code réel : `wods.service.ts` (prédiction),
> `scoring.service.ts` (`predictResult`), `apps/mobile/lib/widgets/celebration.dart`.

## 0. Contexte technique (ce qui existe déjà)

- Endpoint `GET /v1/wods/:id/prediction` renvoie `{ predictedRaw: number | null, scoreType }`.
  - `predictedRaw` est le résultat brut prédit POUR CET UTILISATEUR (secondes / reps / kg).
  - `predictedRaw === null` quand l'Index n'est pas exploitable pour ce WOD : aucun attribut
    cible débloqué (Index incomplet) **ou** course à distance libre. ⇒ on tombe dans le **§4
    (pas de prédiction)**.
- **Sens de la métrique** (déterminant pour classer le résultat). Dans `scoring.service.ts` :
  `dir = scoreType === "time" ? -1 : 1`.
  - `scoreType === "time"` → **plus BAS = mieux** (un chrono qu'on cherche à baisser).
  - `scoreType ∈ { "reps", "load", "distance" }` → **plus HAUT = mieux**.
  - (`distance` en course libre ⇒ `predictedRaw = null`, donc en pratique les cas « avec
    prédiction » sont `time`, `reps`, `load`.)
- Widget de célébration (signature réelle, à respecter telle quelle) :
  ```dart
  Celebration.show(
    context,
    title:    '...',                       // requis
    subtitle: '...',                       // = le "body" de cette spec
    intensity: CelebrationIntensity.medium, // enum: light | medium | strong
  );
  ```
  > L'humain a parlé d'intensités « low/medium/high » : l'enum RÉEL est
  > `light | medium | strong`. Cette spec utilise les noms réels. Mapping : low→light,
  > high→strong.
  - `light` n'ouvre PAS de plein écran : juste un haptic succès (le caller affiche un accent
    inline). À réserver aux paliers bas.
  - Anti-fatigue intégré : une 2e célébration `strong` dans la même session est
    automatiquement rétrogradée en `medium`. On s'appuie dessus, on ne le contourne pas.

---

## 1. Calcul de l'écart et seuils des 5 paliers

### 1.1 Écart relatif normalisé (toujours « + = mieux que prévu »)

On calcule un **gain relatif** `g`, exprimé en %, normalisé pour que **`g > 0` signifie
TOUJOURS « meilleur que la prédiction »**, quel que soit le sens de la métrique :

```
// actual = résultat saisi par l'utilisateur ; predicted = predictedRaw
if (scoreType == 'time') {
  // plus bas = mieux  → battre la prédiction = chrono plus petit
  g = (predicted - actual) / predicted * 100;
} else {
  // reps / load / distance : plus haut = mieux
  g = (actual - predicted) / predicted * 100;
}
```

- `g = +8` → 8 % MIEUX que prédit (8 % plus rapide, ou 8 % de reps/kg en plus).
- `g = -12` → 12 % MOINS bien que prédit.
- Garde-fous : si `predicted <= 0` ou `predicted == null` ⇒ **§4**. Clamp `actual` aux bornes
  physiologiques est déjà fait en amont (anti-triche §5.5), on consomme la valeur telle quelle.

### 1.2 Table des seuils

| Palier | Nom interne | Condition sur `g` | Intuition |
|---|---|---|---|
| **1** | `farBetter` | `g >= +6 %` | Bien mieux que prévu |
| **2** | `better` | `+2 % <= g < +6 %` | Mieux que prévu |
| **3** | `onTarget` | `-2 % < g < +2 %` | Pile la prédiction |
| **4** | `below` | `-10 % < g <= -2 %` | Moins bien |
| **5** | `wayBelow` | `g <= -10 %` | Très décevant |

### 1.3 Justification des chiffres (fondé sur la science de la motivation)

- **Bande « pile » de ±2 % (palier 3).** La prédiction `predictedRaw` est un point estimé issu
  d'un modèle ; la variabilité intra-individuelle d'une perf (sommeil, échauffement, mesure
  manuelle) est couramment de 2-3 %. En-deçà de 2 %, parler de « mieux » ou « moins bien »
  serait du **bruit présenté comme du signal** → ce serait du *dark pattern de flatterie* (ou
  de culpabilisation) injustifié. *Principe : feedback de MAÎTRISE honnête — on ne célèbre pas
  une différence non significative (Deci & Ryan, feedback informationnel crédible).*
- **Seuil de victoire à +6 % (palier 1) plutôt que +10 %.** Battre sa propre prédiction
  personnalisée de 6 % est une perf réellement notable et **réalisable** : un objectif
  atteignable mais exigeant maximise la motivation (zone proximale de développement). Mettre la
  barre trop haut rendrait le « gros message » quasi inatteignable et donc absent → on perd
  l'effet de renforcement. *Principe : objectifs spécifiques + difficiles mais atteignables
  (Locke & Latham, goal-setting theory).*
- **Plancher « très décevant » à -10 % (palier 5).** En dessous de -10 %, ce n'est plus une
  séance « un peu en dessous » : c'est très probablement un mauvais jour (fatigue, maladie,
  matériel). On bascule alors sur un message de **récupération**, jamais de jugement. *Principe :
  attribution adaptative — rattacher l'échec à une cause temporaire et contrôlable (« mauvais
  jour ») protège le sentiment de compétence (Dweck, growth mindset).*
- **Asymétrie -2/-10 vs +2/+6.** La fenêtre « moins bien » (palier 4) est plus large que la
  fenêtre « mieux » (palier 2) côté positif, parce qu'on veut que **passer juste sous la
  prédiction reste encourageant et orienté progrès**, pas alarmant. *Principe : on amortit le
  feedback négatif (aversion à la perte) pour éviter le découragement et l'abandon (SDT —
  préserver la motivation autonome).*

---

## 2. Contenus par palier (title + body, 2-3 variantes)

> Règle de pioche : choisir **uniformément au hasard** parmi les variantes du palier retenu.
> Ton : ultra-pro, factuel, orienté EFFORT/PROGRÈS (jamais le talent : « tu es doué » est
> proscrit — *Dweck : louer le processus, pas le trait*). Tutoiement.
> Placeholders disponibles : `{gain}` = `g` arrondi en valeur absolue, sans signe
> (ex. « 7 % »). `{wodName}` = nom de la séance. Ne PAS afficher de chiffre dans les paliers 3
> (non significatif) ni 5 (contre-productif d'enfoncer le clou).

### Palier 1 — `farBetter` (g >= +6 %) — « Bien mieux que prévu »

| # | title | body |
|---|---|---|
| a | `Performance d'exception` | `Tu as battu ta prédiction de {gain}. Ce n'est pas la chance : c'est ton travail qui parle. Note ce que tu as fait de bien aujourd'hui.` |
| b | `Tu as explosé le plafond` | `{gain} au-dessus de ce qu'on attendait de toi. Ton niveau réel vient de prendre de l'avance sur le modèle. Continue exactement comme ça.` |
| c | `Bien au-dessus de la cible` | `Prédiction pulvérisée de {gain}. Ce genre de séance, c'est la preuve concrète que ta préparation paie.` |

*Principe : feedback de compétence + attribution interne contrôlable (effort/préparation) — on
ancre la réussite dans le processus reproductible, pas dans un coup de chance (SDT + Dweck).*

### Palier 2 — `better` (+2 % <= g < +6 %) — « Mieux que prévu »

| # | title | body |
|---|---|---|
| a | `Au-dessus de la cible` | `{gain} de mieux que ta prédiction. Tu progresses dans la bonne direction, et ça se voit.` |
| b | `Solide. Tu prends le dessus` | `Tu as dépassé ce qui était attendu de {gain}. Garde ce rythme, c'est exactement comme ça qu'on monte.` |
| c | `Mieux que prévu` | `+{gain} sur la prédiction. Petit écart, vraie progression : capitalise dessus à ta prochaine séance.` |

*Principe : renforcer un progrès modéste mais réel sans le survendre — crédibilité du feedback
(feedback informationnel, Deci & Ryan).*

### Palier 3 — `onTarget` (-2 % < g < +2 %) — « Pile la prédiction »

| # | title | body |
|---|---|---|
| a | `Pile dans la cible` | `Tu as fait exactement le temps prévu pour toi. Atteindre sa cible, c'est déjà une réussite : ton niveau et ta perf sont alignés.` |
| b | `Objectif atteint` | `Tu as tenu la prédiction au plus juste. C'est de la régularité maîtrisée — la base de toute vraie progression.` |
| c | `Dans le mille` | `Tu as réalisé la perf attendue pour ton niveau. Solide et fiable : maintenant, vise un cran au-dessus.` |

> Adapter « le temps prévu » → « le score prévu » / « la perf prévue » selon `scoreType`
> (`time` = « temps », `reps`/`load` = « score »). Voir §3.3.

*Principe : atteindre exactement un objectif est une réussite de MAÎTRISE en soi ; on la valide
explicitement (« objectif atteint ») au lieu de la traiter comme un non-événement (goal-setting
+ sentiment de compétence).*

### Palier 4 — `below` (-10 % < g <= -2 %) — « Moins bien »

| # | title | body |
|---|---|---|
| a | `Séance dans la boîte` | `Un peu en dessous de ta cible aujourd'hui, mais tu l'as terminée — et c'est ça qui compte. On sait que tu peux faire mieux : la prochaine sera meilleure.` |
| b | `Bravo, c'est noté` | `Pas ton meilleur jour sur {wodName}, mais chaque répétition compte dans ta progression. Tu as la marge pour repasser au-dessus.` |
| c | `Tu as fait le travail` | `Résultat un peu sous ta prédiction, mais l'important c'est que tu sois venu(e). On est sûrs que tu peux faire mieux la prochaine fois.` |

*Principe : on félicite l'EFFORT et la présence (pas le résultat), on cadre l'écart comme
temporaire et surmontable (« la prochaine sera meilleure ») → préserve l'auto-efficacité et
encourage la persévérance (Bandura ; Dweck « yet »).*

### Palier 5 — `wayBelow` (g <= -10 %) — « Très décevant / mauvais jour »

| # | title | body |
|---|---|---|
| a | `Mauvais jour, ça arrive` | `Loin de ton niveau habituel aujourd'hui — et ce n'est pas grave. Le corps a ses jours sans. Repose-toi, et reviens retenter {wodName} en forme : tu vaux bien mieux que ça.` |
| b | `Ce n'était pas ton jour` | `Cette perf ne reflète pas ce dont tu es capable. Fatigue, sommeil, journée chargée : ça compte. Reviens sur {wodName} quand tu seras au top.` |
| c | `On range cette séance` | `Jour sans, tout simplement. L'avoir terminée malgré tout, c'est déjà du mental. Récupère bien et retente {wodName} reposé(e) — tu feras nettement mieux.` |

> Jamais de chiffre ici, jamais de honte. On nomme la cause externe/temporaire et on invite au
> RETOUR (pas à l'abandon) après récupération.

*Principe : attribution adaptative de l'échec (cause instable, externe, temporaire) + cadrage
récupération — protège la compétence perçue et évite le décrochage (Dweck ; SDT). Engagement
SAIN : on valorise le repos, jamais le forçage.*

---

## 3. Mapping intensité de célébration

### 3.1 Table de mapping

| Palier | Intensité `CelebrationIntensity` | Plein écran ? | Haptics | Justification |
|---|---|---|---|---|
| 1 `farBetter` | `strong` | Oui + confettis | success (fort) | Le pic de dopamine doit être RARE et MÉRITÉ → réservé au vrai dépassement. |
| 2 `better` | `medium` | Oui | success | Célébration franche mais non maximale, pour garder `strong` désirable. |
| 3 `onTarget` | `medium` | Oui | success | Atteindre sa cible MÉRITE une vraie reconnaissance plein écran (sinon « pile » = non-événement). |
| 4 `below` | `light` | Non (accent inline) | success léger | On reconnaît l'effort sans fanfare ; pas de plein écran qui sonnerait faux. |
| 5 `wayBelow` | `light` | Non (accent inline) | **neutre/aucun** | Surtout PAS de confettis sur un mauvais jour — ce serait une fausse note insultante. |

### 3.2 Pourquoi cette répartition (rareté de la récompense)

- Réserver `strong` au seul palier 1 préserve sa **valeur de signal**. *Principe : récompense
  variable + rareté — une célébration maximale distribuée à tout va perd son pouvoir (Hooked,
  récompense de soi ; économie de la dopamine).*
- L'anti-fatigue natif (`strong` → `medium` à la 2e fois dans la session) renforce ça
  gratuitement : sur une session de plusieurs WODs, seul le PREMIER vrai dépassement déclenche
  le plein feu. On s'appuie dessus, on ne le contourne pas.
- Paliers 4-5 en `light` (haptique seul, accent inline) : la honte et le bruit sont des dark
  patterns. On ne « punit » jamais visuellement une contre-perf. *Principe : zéro dark pattern
  (engagement sain).*

### 3.3 Pseudo-code de déclenchement (côté résultat enregistré)

```dart
// pred = predictedRaw du WOD ; actual = valeur saisie ; scoreType depuis la prédiction.
if (pred == null) {
  // -> §4 (pas de prédiction). Pas de plein écran, encouragement neutre inline.
  showNeutralEncouragement();
  return;
}

final g = (scoreType == 'time')
    ? (pred - actual) / pred * 100
    : (actual - pred)  / pred * 100;

final tier = _classify(g); // farBetter / better / onTarget / below / wayBelow
final msg  = _pick(tier);  // pioche uniforme parmi les variantes du palier

// metricWord : 'time' -> 'temps' ; sinon -> 'score'  (pour les libellés du palier 3)
final body = msg.body
    .replaceAll('{gain}', '${g.abs().round()} %')
    .replaceAll('{wodName}', wodName);

switch (tier) {
  case Tier.farBetter:
    Celebration.show(context, title: msg.title, subtitle: body,
        intensity: CelebrationIntensity.strong);
  case Tier.better:
  case Tier.onTarget:
    Celebration.show(context, title: msg.title, subtitle: body,
        intensity: CelebrationIntensity.medium);
  case Tier.below:
  case Tier.wayBelow:
    Celebration.show(context, title: msg.title, subtitle: body,
        intensity: CelebrationIntensity.light); // pas de plein écran : accent inline + haptic
}
```

> Arrondi de `{gain}` : `g.abs().round()`. Si après arrondi `{gain}` vaut `0 %` dans un palier
> 1/2 (cas limite improbable vu les seuils), afficher la variante sans chiffre — sécurité :
> préférer les variantes 1a/2b qui restent cohérentes sans nombre, ou recalculer en n'arrondissant
> pas à zéro (afficher au moins « 1 % »).

---

## 4. Cas SANS prédiction (`predictedRaw == null`)

Survient quand l'Index n'est pas encore exploitable pour ce WOD (attributs cibles non
débloqués) ou course à distance libre. On NE compare rien — on **félicite la saisie** et on
**pointe vers le déblocage** de l'estimation personnalisée (investissement, boucle Hooked).

- Intensité : `light` (haptique succès), pas de plein écran : il n'y a pas de « victoire » à
  proclamer, juste un résultat enregistré.
- Pas de comparaison, pas de chiffre, ton positif et tourné vers l'avant.

| # | title | body |
|---|---|---|
| a | `Résultat enregistré` | `Belle séance, c'est dans la boîte. Encore quelques entraînements et on pourra te dire exactement où tu te situes — et te prédire tes prochains chronos.` |
| b | `C'est noté, continue` | `Chaque résultat enregistré rapproche ton Index complet. Bientôt, on te donnera une cible personnalisée à battre sur chaque séance.` |

*Principe : INVESTISSEMENT (Hooked) — l'utilisateur perçoit qu'enregistrer fait grandir une
valeur stockée (son Index, sa future prédiction), ce qui charge le prochain tour de boucle. Ton
de maîtrise et de progrès, jamais de FOMO punitif.*

---

## 5. Récapitulatif implémentable (table unique)

| Palier | Condition `g` | Intensité | Chiffre affiché ? | `{wodName}` utilisé ? |
|---|---|---|---|---|
| 1 farBetter | `g >= +6` | strong | oui (`{gain}`) | non |
| 2 better | `+2 <= g < +6` | medium | oui (`{gain}`) | non |
| 3 onTarget | `-2 < g < +2` | medium | non | non |
| 4 below | `-10 < g <= -2` | light | non | oui (variantes b/c) |
| 5 wayBelow | `g <= -10` | light (haptic neutre) | non | oui |
| — pas de pred | `predictedRaw == null` | light | non | non |

### Garanties « zéro dark pattern »
- Aucune honte, aucune culpabilisation, aucun FOMO punitif sur les paliers bas.
- La bande ±2 % empêche toute fausse flatterie / faux reproche sur du bruit de mesure.
- Le pic `strong` est rare (palier 1 + anti-fatigue de session) → dopamine honnête.
- Palier 5 invite au REPOS et au retour, jamais au forçage → engagement sain.
- Tous les contenus louent l'EFFORT/le PROCESSUS, jamais le talent inné (growth mindset).
