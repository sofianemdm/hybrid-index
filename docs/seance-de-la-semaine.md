# Séance de la semaine — « Le Forgeron »

> Source d'autorité : agent sport-science (26 juin 2026). Remplace l'ancien **Profil Express**
> comme séance hebdomadaire mise en avant. Profil Express reste, lui, la **séance d'entrée de
> l'onboarding** (celle qui débloque l'Index estimé) ; ce n'est PAS le même rôle.

## Intention

Une séance **signature, intensive, 100 % sans matériel, ~15 min**, faisable partout (salon, parc,
chambre d'hôtel), qui « forge » le corps entier. Fédératrice : tout le monde peut la tenter, du
débutant (en scalant le volume / le cap) à l'avancé (en visant le chrono). Orientation **hybride**
dominante (cardio + gymnastique au poids de corps + transitions), exactement l'ADN de l'app.

## Fiche

| Champ | Valeur |
|---|---|
| `id` | `weekly-forgeron` |
| Nom | **Le Forgeron** |
| Matériel | **Aucun** (sans matériel) |
| Durée cible | **~15 min** (cap 15:00) |
| Intensité | Haute |
| `scoreType` | `time` (chrono ; reps au cap si non terminé) |
| Rx / Allégé | **NON** (aucune charge → rien à scaler ; cf. `wod-prescription.types.ts` `isScalable`) |
| Attribut primaire | `hybrid` |
| Attributs secondaires | `engine`, `muscular_endurance`, `power` |

Ajoutée à la bibliothèque dans `apps/api/src/modules/coach/sessions.data.ts` (entrée
`weekly-forgeron`, en tête du tableau `SESSIONS`).

## Structure détaillée

**Format : 3 tours pour le temps. Time cap 15:00.**

Chaque tour, à enchaîner sans repos imposé (fractionne librement) :

1. **200 m course** — ou, sans espace : **40 jumping jacks** sur place (équivalent cardio).
2. **15 burpees** — poitrine au sol, extension complète debout.
3. **25 air squats** — hanches sous les genoux.
4. **20 mountain climbers** — 10 par jambe (1 = un genou ramené).
5. **15 sit-ups** — amplitude complète.

**Score** = temps total pour boucler les 3 tours. Si le cap de 15:00 est atteint avant la fin :
score = nombre de répétitions complétées (mode AMRAP de repli).

### Volume total (3 tours)
600 m course (ou 120 jumping jacks) · 45 burpees · 75 air squats · 60 mountain climbers · 45 sit-ups.

### Calibrage de durée (estimation, à recalibrer sur la communauté — confiance *low*)
Débit intermédiaire approximatif : course 200 m ≈ 55 s · 15 burpees ≈ 45 s · 25 air squats ≈ 35 s ·
20 MC ≈ 25 s · 15 sit-ups ≈ 25 s · transitions ≈ 15 s → **≈ 3:20 / tour**, soit **~10 min** (bon
niveau) à **~14–15 min** (intermédiaire), cap **15:00**. Conforme à la cible « ~15 min ».

### Conseils de pacing (affichables)
Ne pars pas trop vite sur les burpees (c'est le piège). Vise une cadence régulière, respire dans
les air squats, garde les mountain climbers vifs mais propres. Découpe en mini-séries (ex. burpees
5+5+5) plutôt que d'aller à l'échec.

## Contribution aux attributs (poids)

Dérivés des mouvements (`movements.data.ts`) : burpee = engine/musc.end/power/hybrid ; air squat =
musc.end/power ; mountain climber ≈ engine + gainage ; sit-up = musc.end ; course 200 m =
engine + speed. Mélange + transitions = signature **hybride**.

| Attribut | Poids | Justification |
|---|---|---|
| `hybrid` | **1.0** (primaire) | Mélange cardio + gym + transitions, format métcon |
| `engine` | **0.9** | Burpees + course + mountain climbers : forte demande aérobie/anaérobie |
| `muscular_endurance` | **0.8** | Volume bodyweight (squats, sit-ups, burpees) |
| `power` | **0.4** | Burpees et squats dynamiques, composante explosive modérée |
| `speed` | **0.3** | Sprint 200 m + cadence mountain climbers |
| `strength` | **0.15** | Plancher : gainage / poussée au poids du corps (minimum garanti) |

Ces poids alimentent le tri de la bibliothèque par attribut (cf. `seances-attributs-spec.md`,
ligne `weekly-forgeron`).

## Notation (réutilise le barème existant)

`Le Forgeron` n'est **pas** un 16e WOD benchmark de l'Index (les 15 benchmarks restent inchangés).
Elle se note avec la **chaîne existante**, deux options selon l'implémentation retenue côté produit :

- **Via le moteur d'estimation** (`score-service` `computeEstimate`, `POST /v1/score/estimate`) :
  on décrit la séance en blocs de mouvements (`run` 200 m, `burpee` 15, `air_squat` 25,
  `mountain_climber`/`sit_up` …) avec `rounds: 3`, `scoreType: "time"`. Le service prédit
  champion/intermédiaire/occasionnel, construit la `pointTable` synthétique et note le temps de
  l'utilisateur (`confidence: "estimated"`). **Aucune donnée nouvelle requise.**
- **Si promue benchmark hebdo classable** (décision produit) : lui donner une `WodSexReference`
  (`wods.data.ts`) calée sur les médianes ci-dessus (H ≈ 600 s / F ≈ 690 s à `intensity high`,
  `pointTable` à recalibrer N≥200/sexe) + une `WodPrescription` `scalable: false`. **À ne faire que
  si le produit veut un classement dédié** ; sinon l'option estimation suffit.

> Le mouvement `mountain_climber` n'existe pas encore dans `movements.data.ts`. Pour la voie
> « estimation », soit l'ajouter (proche de `burpee` sans le saut : engine 0.5 / musc.end 0.3 /
> hybrid 0.2), soit substituer 40 montées de genoux / double-unders. **Décision produit** : ajouter
> le mouvement, ou jouer la séance comme un simple « libellé » non auto-noté (chrono manuel).

## Points nécessitant une décision produit

1. **Auto-notation** : voie « estimation » (recommandée, zéro nouvelle donnée) **ou** benchmark
   classable dédié ? Tant que non tranché, la séance est jouable au chrono manuel.
2. **Mouvement `mountain_climber`** : l'ajouter au registre, ou le remplacer par un mouvement déjà
   présent (montées de genoux) ?
3. **UI** : c'est la session principale qui déplace l'encart « séance de la semaine » vers la page
   Séances et le renomme. Ici on ne fournit que le **contenu** (fait).
