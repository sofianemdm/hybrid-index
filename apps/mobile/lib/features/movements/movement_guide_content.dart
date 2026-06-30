// GUIDE DES MOUVEMENTS — contenu pédagogique pour grands débutants (FR + EN).
//
// Autorité : sport-science. Ce fichier ne contient AUCUNE logique de score ni de réseau :
// uniquement du texte pédagogique consommé par l'UI du guide des mouvements.
//
// Couverture : tous les `movementId` réellement utilisés par les 15 WODs benchmark, les 5 WODs
// « Ligue du mois » et les 8 stations HYROX (voir apps/score-service/src/wods/*.data.ts), plus
// quelques mouvements voisins du catalogue movements.data.ts pour anticiper les futures séances.
//
// Forme de données (simple à consommer par le widget) :
//   - `MovementGuide` porte les DEUX langues. Chaque champ de texte est une `Map<String,_>`
//     indexée par code langue ('fr' / 'en'). L'UI lit `guide.steps[locale]` etc.
//   - `svgAsset` pointe vers l'illustration (générée en parallèle). Le fichier peut ne pas
//     exister encore : l'UI doit gérer l'absence (placeholder).
//   - `movementGuideFor(id)` applique d'abord un alias (variantes mètres → variante reps) puis
//     renvoie `null` si aucune fiche : l'UI affiche alors un état « fiche bientôt disponible ».
//
// Langues supportées : 'fr' (défaut) et 'en'. Toute langue inconnue retombe sur 'fr'.

/// Langue par défaut quand la locale demandée n'a pas de traduction.
const String kMovementGuideFallbackLang = 'fr';

/// Une fiche pédagogique bilingue pour UN mouvement.
class MovementGuide {
  const MovementGuide({
    required this.id,
    required this.name,
    required this.steps,
    required this.cues,
    required this.mistakes,
    required this.beginner,
    required this.svgAsset,
  });

  /// Identifiant = `movementId` côté score-service (ex. "push_up").
  final String id;

  /// Nom affiché, par langue. Ex. { 'fr': 'Pompe', 'en': 'Push-up' }.
  final Map<String, String> name;

  /// 3 à 5 étapes « comment faire », de la position de départ à l'exécution. Par langue.
  final Map<String, List<String>> steps;

  /// 2-3 points clés / sécurité (dos, genoux, respiration…). Par langue.
  final Map<String, List<String>> cues;

  /// 2-3 erreurs fréquentes à éviter. Par langue.
  final Map<String, List<String>> mistakes;

  /// Version facile / scaling (pompe sur genoux, traction élastique, squat sur boîte…). Par langue.
  final Map<String, String> beginner;

  /// Chemin de l'illustration SVG. Peut ne pas encore exister sur disque.
  final String svgAsset;

  // ---- Accès tolérants à la langue (retombent sur la langue par défaut) ----

  String nameIn(String lang) => name[lang] ?? name[kMovementGuideFallbackLang] ?? id;

  List<String> stepsIn(String lang) =>
      steps[lang] ?? steps[kMovementGuideFallbackLang] ?? const <String>[];

  List<String> cuesIn(String lang) =>
      cues[lang] ?? cues[kMovementGuideFallbackLang] ?? const <String>[];

  List<String> mistakesIn(String lang) =>
      mistakes[lang] ?? mistakes[kMovementGuideFallbackLang] ?? const <String>[];

  String beginnerIn(String lang) =>
      beginner[lang] ?? beginner[kMovementGuideFallbackLang] ?? '';
}

/// Convention de chemin pour les illustrations (les SVG sont générés en parallèle).
String movementSvgAsset(String id) => 'assets/movements/$id.svg';

/// Variantes (distance / calories) qui partagent la même fiche que le mouvement de base.
/// Mapping de secours : un id sans fiche propre est résolu vers son équivalent.
const Map<String, String> _movementAlias = {
  'lunge_m': 'lunge',
  'burpee_broad_jump_m': 'burpee_broad_jump',
  'row_cal': 'row',
  'sprint': 'run',
  'thruster_db': 'thruster',
};

/// Récupère la fiche d'un mouvement, en appliquant les alias. `null` si aucune fiche
/// (l'UI doit alors afficher un état « fiche bientôt disponible » sans planter).
MovementGuide? movementGuideFor(String movementId) {
  final direct = movementGuides[movementId];
  if (direct != null) return direct;
  final alias = _movementAlias[movementId];
  if (alias != null) return movementGuides[alias];
  return null;
}

/// Normalise un libellé (id snake_case OU nom libre FR/EN) pour la résolution par nom :
/// minuscules, accents retirés, ponctuation/espaces réduits. « Wall ball (lancer au mur) » →
/// « wall ball lancer au mur » ; « pull_up » → « pull up ».
String _normalizeMovementKey(String raw) {
  var s = raw.toLowerCase().trim();
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'œ': 'oe',
    '’': ' ', "'": ' ', '-': ' ', '_': ' ', '&': ' ',
  };
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    buf.write(accents[ch] ?? ch);
  }
  s = buf.toString();
  // Ne garde que lettres/chiffres/espaces, puis compacte les espaces.
  s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Index inverse nom normalisé → movementId (construit une fois, à la 1re demande).
/// Couvre l'id, le nom FR et le nom EN de chaque fiche, plus les alias de variantes.
Map<String, String>? _nameToIdIndex;
Map<String, String> _buildNameIndex() {
  final idx = <String, String>{};
  movementGuides.forEach((id, g) {
    idx[_normalizeMovementKey(id)] = id;
    idx[_normalizeMovementKey(g.nameIn('fr'))] = id;
    idx[_normalizeMovementKey(g.nameIn('en'))] = id;
  });
  _movementAlias.forEach((from, to) {
    if (movementGuides.containsKey(to)) idx[_normalizeMovementKey(from)] = to;
  });
  return idx;
}

/// Résout un libellé de mouvement (id OU nom libre FR/EN tel qu'écrit dans la prescription d'un
/// WOD) vers son `movementId` de fiche. `null` si rien ne correspond (l'UI ignore alors ce libellé).
/// Tolérant : essaie d'abord la résolution directe par id/alias, puis l'index par nom, enfin une
/// correspondance par préfixe de mot (ex. « Course à pied 400 m » → « course a pied » → run).
String? resolveMovementId(String label) {
  if (label.trim().isEmpty) return null;
  // 1) Déjà un id (ou un alias d'id) ?
  if (movementGuides.containsKey(label)) return label;
  final alias = _movementAlias[label];
  if (alias != null) return alias;
  // 2) Index par nom normalisé.
  final index = _nameToIdIndex ??= _buildNameIndex();
  final key = _normalizeMovementKey(label);
  if (key.isEmpty) return null;
  final exact = index[key];
  if (exact != null) return exact;
  // 3) Correspondance par préfixe : le libellé commence par un nom connu (« Burpees » → burpee).
  String? best;
  int bestLen = 0;
  index.forEach((name, id) {
    if (name.length > bestLen && (key == name || key.startsWith('$name ') || name.startsWith('$key '))) {
      best = id;
      bestLen = name.length;
    }
  });
  return best;
}

/// Mappe une liste ordonnée de libellés (ids ou noms libres) vers des fiches existantes, en
/// dédupliquant tout en préservant l'ordre d'apparition. Les libellés non résolus sont ignorés.
List<MovementGuide> resolveMovementGuides(Iterable<String> labels) {
  final seen = <String>{};
  final out = <MovementGuide>[];
  for (final label in labels) {
    final id = resolveMovementId(label);
    if (id == null || !seen.add(id)) continue;
    final g = movementGuides[id];
    if (g != null) out.add(g);
  }
  return out;
}

/// Catalogue des fiches, indexé par `movementId`.
final Map<String, MovementGuide> movementGuides = {
  // =====================================================================================
  // GYMNASTIQUE / POIDS DE CORPS
  // =====================================================================================
  'push_up': MovementGuide(
    id: 'push_up',
    svgAsset: movementSvgAsset('push_up'),
    name: const {'fr': 'Pompe', 'en': 'Push-up'},
    steps: const {
      'fr': [
        'Mains au sol un peu plus larges que les épaules, bras tendus, corps en planche.',
        'Gaine le ventre et serre les fessiers : tête, dos et talons forment une ligne droite.',
        'Plie les coudes et descends la poitrine vers le sol, coudes vers l’arrière (pas écartés).',
        'Frôle le sol, puis pousse fort pour revenir bras tendus.',
      ],
      'en': [
        'Hands on the floor slightly wider than your shoulders, arms straight, body in a plank.',
        'Brace your stomach and squeeze your glutes: head, back and heels form one straight line.',
        'Bend the elbows and lower your chest toward the floor, elbows back (not flared out).',
        'Touch near the floor, then push hard to return to straight arms.',
      ],
    },
    cues: const {
      'fr': [
        'Garde le corps en planche : les hanches ne montent ni ne s’affaissent.',
        'Coudes serrés vers le corps (~45°) pour protéger les épaules.',
        'Inspire en descendant, souffle en poussant.',
      ],
      'en': [
        'Keep the body in a plank: hips neither pike up nor sag down.',
        'Tuck elbows toward the body (~45°) to protect the shoulders.',
        'Inhale on the way down, exhale as you push.',
      ],
    },
    mistakes: const {
      'fr': [
        'Hanches qui tombent (dos creux) : signe que le gainage lâche.',
        'Amplitude partielle : la poitrine ne descend pas assez bas.',
        'Coudes trop écartés en T : douloureux pour les épaules.',
      ],
      'en': [
        'Hips sagging (arched back): a sign the core has switched off.',
        'Partial range: the chest doesn’t come down far enough.',
        'Elbows flared out in a T: hard on the shoulders.',
      ],
    },
    beginner: const {
      'fr': 'Pompe sur les genoux (genoux au sol, même ligne hanches-épaules), ou mains '
          'surélevées sur un banc / mur pour réduire la charge.',
      'en': 'Push-up on the knees (knees down, same hip-to-shoulder line), or hands elevated '
          'on a bench / wall to reduce the load.',
    },
  ),

  'pull_up': MovementGuide(
    id: 'pull_up',
    svgAsset: movementSvgAsset('pull_up'),
    name: const {'fr': 'Traction', 'en': 'Pull-up'},
    steps: const {
      'fr': [
        'Attrape la barre paumes vers l’avant, mains largeur d’épaules, bras tendus.',
        'Serre les omoplates et gaine le ventre : pas de balancier.',
        'Tire en amenant la poitrine vers la barre, coudes vers le bas.',
        'Menton au-dessus de la barre, puis redescends bras tendus, sous contrôle.',
      ],
      'en': [
        'Grip the bar with palms facing away, hands shoulder-width, arms straight.',
        'Pull the shoulder blades together and brace your core: no swinging.',
        'Pull by bringing your chest toward the bar, elbows driving down.',
        'Chin over the bar, then lower under control to straight arms.',
      ],
    },
    cues: const {
      'fr': [
        'Commence chaque rep bras totalement tendus (amplitude complète).',
        'Gaine le ventre pour éviter de te cambrer.',
        'Tire avec le dos, pas seulement les bras.',
      ],
      'en': [
        'Start every rep from fully straight arms (full range).',
        'Brace the core to avoid over-arching.',
        'Pull with your back, not just your arms.',
      ],
    },
    mistakes: const {
      'fr': [
        'Demi-tractions : le menton ne passe pas la barre.',
        'Balancier excessif pour « voler » la rep.',
        'Descente non contrôlée (on se laisse tomber).',
      ],
      'en': [
        'Half pull-ups: chin doesn’t clear the bar.',
        'Excessive swinging to “steal” the rep.',
        'Uncontrolled drop on the way down.',
      ],
    },
    beginner: const {
      'fr': 'Traction assistée à l’élastique (élastique sur la barre, pied/genou dedans), ou '
          'tractions australiennes (barre basse, corps incliné, pieds au sol).',
      'en': 'Band-assisted pull-up (band over the bar, foot/knee in it), or ring/bar rows '
          '(low bar, body angled, feet on the floor).',
    },
  ),

  'chest_to_bar': MovementGuide(
    id: 'chest_to_bar',
    svgAsset: movementSvgAsset('chest_to_bar'),
    name: const {'fr': 'Traction poitrine à la barre', 'en': 'Chest-to-bar pull-up'},
    steps: const {
      'fr': [
        'Suspension à la barre, bras tendus, prise largeur d’épaules ou un peu plus large.',
        'Serre les omoplates et gaine fort le tronc.',
        'Tire explosivement en tirant les coudes vers le bas et l’arrière.',
        'Touche la barre avec le haut de la poitrine, puis redescends bras tendus.',
      ],
      'en': [
        'Hang from the bar, arms straight, grip shoulder-width or slightly wider.',
        'Set the shoulder blades and brace the trunk hard.',
        'Pull explosively, driving the elbows down and back.',
        'Touch the bar with your upper chest, then lower to straight arms.',
      ],
    },
    cues: const {
      'fr': [
        'Il faut tirer plus haut qu’une traction classique : initie le mouvement vite.',
        'Garde le corps gainé pour transmettre la puissance.',
        'Contact net poitrine-barre à chaque rep.',
      ],
      'en': [
        'You must pull higher than a regular pull-up: start the movement fast.',
        'Keep the body braced to transfer power.',
        'Clear chest-to-bar contact on every rep.',
      ],
    },
    mistakes: const {
      'fr': [
        'Toucher avec le menton/cou au lieu de la poitrine.',
        'Manquer de hauteur en fin de série quand la fatigue arrive.',
        'Cambrer le bas du dos pour compenser.',
      ],
      'en': [
        'Touching with chin/neck instead of the chest.',
        'Losing height late in the set as fatigue sets in.',
        'Arching the lower back to compensate.',
      ],
    },
    beginner: const {
      'fr': 'Maîtrise d’abord la traction menton-barre. Ensuite, version élastique pour gagner '
          'la hauteur supplémentaire jusqu’à la poitrine.',
      'en': 'Master the chin-over-bar pull-up first. Then use a band to gain the extra height '
          'needed to reach chest-to-bar.',
    },
  ),

  'ring_muscle_up': MovementGuide(
    id: 'ring_muscle_up',
    svgAsset: movementSvgAsset('ring_muscle_up'),
    name: const {'fr': 'Muscle-up aux anneaux', 'en': 'Ring muscle-up'},
    steps: const {
      'fr': [
        'Suspension aux anneaux en prise « fausse prise » (poignet par-dessus l’anneau).',
        'Tire fort en amenant les anneaux le long du corps, coudes vers l’arrière.',
        'Au plus haut, bascule rapidement le buste vers l’avant pour passer au-dessus des anneaux.',
        'Termine en poussant (dips) jusqu’à bras tendus en appui, puis redescends sous contrôle.',
      ],
      'en': [
        'Hang from the rings with a “false grip” (wrist over the ring).',
        'Pull hard, keeping the rings close to your body, elbows driving back.',
        'At the top, quickly roll your chest forward to get above the rings (transition).',
        'Finish by pressing (dip) to straight arms in support, then lower under control.',
      ],
    },
    cues: const {
      'fr': [
        'La fausse prise est la clé : elle permet la transition sans temps mort.',
        'Garde les anneaux proches du corps pendant toute la traction.',
        'Mouvement avancé : aborde-le seulement après tractions + dips solides.',
      ],
      'en': [
        'The false grip is key: it makes the transition possible without a dead stop.',
        'Keep the rings close to the body throughout the pull.',
        'Advanced move: only attempt it once your pull-ups + dips are solid.',
      ],
    },
    mistakes: const {
      'fr': [
        'Anneaux trop loin du corps : la transition devient impossible.',
        'Vouloir « monter à la force des bras » sans bascule du buste.',
        'Épaules pas échauffées : risque de blessure.',
      ],
      'en': [
        'Rings too far from the body: the transition becomes impossible.',
        'Trying to muscle up by arm strength alone without the chest roll.',
        'Shoulders not warmed up: injury risk.',
      ],
    },
    beginner: const {
      'fr': 'Travaille les briques : tractions hautes (poitrine aux anneaux), dips aux anneaux, '
          'et transitions assistées pieds au sol ou à l’élastique.',
      'en': 'Build the pieces: high pull-ups (chest to rings), ring dips, and assisted '
          'transitions with feet on the floor or with a band.',
    },
  ),

  'handstand_push_up': MovementGuide(
    id: 'handstand_push_up',
    svgAsset: movementSvgAsset('handstand_push_up'),
    name: const {'fr': 'Pompe en équilibre (HSPU)', 'en': 'Handstand push-up'},
    steps: const {
      'fr': [
        'En équilibre contre un mur, mains au sol un peu plus larges que les épaules.',
        'Corps gainé, fessiers serrés, regard entre les mains.',
        'Plie les coudes et descends la tête vers le sol, coudes légèrement vers l’avant.',
        'La tête frôle le sol, puis pousse jusqu’aux bras tendus.',
      ],
      'en': [
        'Kick up to a handstand against a wall, hands slightly wider than the shoulders.',
        'Body braced, glutes squeezed, eyes between your hands.',
        'Bend the elbows and lower your head toward the floor, elbows slightly forward.',
        'Head touches near the floor, then press back to straight arms.',
      ],
    },
    cues: const {
      'fr': [
        'Garde le ventre gainé pour ne pas te cambrer contre le mur.',
        'Crée un triangle stable tête-mains au sol.',
        'Mouvement avancé : maîtrise d’abord le maintien en équilibre.',
      ],
      'en': [
        'Keep the core braced so you don’t arch against the wall.',
        'Form a stable head-and-hands triangle on the floor.',
        'Advanced move: master the handstand hold first.',
      ],
    },
    mistakes: const {
      'fr': [
        'Cambrer le bas du dos contre le mur.',
        'Amplitude partielle : la tête ne descend pas au sol.',
        'Mains trop écartées ou trop serrées.',
      ],
      'en': [
        'Arching the lower back against the wall.',
        'Partial range: the head doesn’t reach the floor.',
        'Hands too wide or too narrow.',
      ],
    },
    beginner: const {
      'fr': 'Pompe en pic (« pike push-up ») pieds surélevés sur un banc, ou développé haltères '
          'au-dessus de la tête pour bâtir la force d’épaules.',
      'en': 'Pike push-up with feet elevated on a bench, or dumbbell overhead press to build '
          'shoulder strength.',
    },
  ),

  'toes_to_bar': MovementGuide(
    id: 'toes_to_bar',
    svgAsset: movementSvgAsset('toes_to_bar'),
    name: const {'fr': 'Pointes de pieds à la barre', 'en': 'Toes-to-bar'},
    steps: const {
      'fr': [
        'Suspension à la barre, bras tendus, mains largeur d’épaules.',
        'Gaine le ventre et engage les épaules (épaules « actives »).',
        'Replie le bassin et monte les jambes pour toucher la barre avec les pointes de pieds.',
        'Redescends sous contrôle, sans te laisser tomber.',
      ],
      'en': [
        'Hang from the bar, arms straight, hands shoulder-width.',
        'Brace your core and engage the shoulders (“active” shoulders).',
        'Tuck the pelvis and raise your legs to touch the bar with your toes.',
        'Lower under control, without letting yourself drop.',
      ],
    },
    cues: const {
      'fr': [
        'Le mouvement part des abdos : enroule le bassin.',
        'Garde les épaules engagées pour stabiliser la suspension.',
        'Souffle en montant les jambes.',
      ],
      'en': [
        'The movement starts from the abs: curl the pelvis.',
        'Keep the shoulders engaged to stabilise the hang.',
        'Exhale as you raise the legs.',
      ],
    },
    mistakes: const {
      'fr': [
        'Balancier sauvage sans contrôle des abdos.',
        'Jambes pliées qui ne touchent pas la barre.',
        'Bras qui se plient au lieu de rester tendus.',
      ],
      'en': [
        'Wild swinging with no abdominal control.',
        'Bent legs that don’t reach the bar.',
        'Arms bending instead of staying straight.',
      ],
    },
    beginner: const {
      'fr': 'Relevés de genoux suspendu (genoux vers la poitrine), ou relevés de jambes allongé '
          'au sol pour renforcer les abdos.',
      'en': 'Hanging knee raises (knees to chest), or lying leg raises on the floor to build '
          'abdominal strength.',
    },
  ),

  'sit_up': MovementGuide(
    id: 'sit_up',
    svgAsset: movementSvgAsset('sit_up'),
    name: const {'fr': 'Relevé de buste (sit-up)', 'en': 'Sit-up'},
    steps: const {
      'fr': [
        'Allongé sur le dos, plante des pieds au sol (ou semelles l’une contre l’autre).',
        'Mains derrière la tête ou croisées sur la poitrine.',
        'Enroule la colonne et remonte le buste jusqu’à toucher les genoux ou le sol devant.',
        'Redescends sous contrôle, vertèbre par vertèbre.',
      ],
      'en': [
        'Lie on your back, feet flat on the floor (or soles together).',
        'Hands behind your head or crossed on your chest.',
        'Curl the spine and lift your torso until you reach your knees or the floor in front.',
        'Lower under control, one vertebra at a time.',
      ],
    },
    cues: const {
      'fr': [
        'Enroule la colonne plutôt que de tirer d’un bloc.',
        'Ne tire pas sur la nuque avec les mains.',
        'Souffle en montant.',
      ],
      'en': [
        'Roll the spine up rather than yanking as one block.',
        'Don’t pull on your neck with your hands.',
        'Exhale as you come up.',
      ],
    },
    mistakes: const {
      'fr': [
        'Tirer sur la nuque (douleur cervicale).',
        'Utiliser l’élan des bras au lieu des abdos.',
        'Décoller les pieds par manque de gainage.',
      ],
      'en': [
        'Pulling on the neck (cervical strain).',
        'Using arm momentum instead of the abs.',
        'Feet lifting off due to weak bracing.',
      ],
    },
    beginner: const {
      'fr': 'Crunch à amplitude réduite (seulement les omoplates décollent), bras croisés sur '
          'la poitrine.',
      'en': 'Short-range crunch (only the shoulder blades lift), arms crossed on the chest.',
    },
  ),

  'air_squat': MovementGuide(
    id: 'air_squat',
    svgAsset: movementSvgAsset('air_squat'),
    name: const {'fr': 'Squat au poids du corps', 'en': 'Air squat'},
    steps: const {
      'fr': [
        'Debout, pieds largeur de hanches, pointes légèrement vers l’extérieur.',
        'Gaine le ventre, poitrine haute, regard devant.',
        'Pousse les hanches vers l’arrière et plie les genoux pour descendre.',
        'Descends jusqu’à ce que les hanches passent sous les genoux, puis remonte en poussant dans les talons.',
      ],
      'en': [
        'Stand with feet hip-width, toes turned slightly out.',
        'Brace your core, chest tall, eyes forward.',
        'Push your hips back and bend the knees to descend.',
        'Drop until the hips go below the knees, then stand by driving through the heels.',
      ],
    },
    cues: const {
      'fr': [
        'Garde les talons au sol et le poids réparti sur tout le pied.',
        'Genoux alignés avec les pointes de pieds (ne rentrent pas).',
        'Dos droit et poitrine ouverte tout du long.',
      ],
      'en': [
        'Keep your heels down and weight spread across the whole foot.',
        'Knees track over the toes (don’t cave inward).',
        'Flat back and open chest throughout.',
      ],
    },
    mistakes: const {
      'fr': [
        'Talons qui décollent (poids vers les orteils).',
        'Genoux qui rentrent vers l’intérieur.',
        'Squat trop haut : les hanches ne passent pas sous les genoux.',
      ],
      'en': [
        'Heels lifting (weight on the toes).',
        'Knees caving inward.',
        'Squatting too high: hips don’t break below the knees.',
      ],
    },
    beginner: const {
      'fr': 'Squat sur boîte : descends t’asseoir légèrement sur une chaise/boîte puis relève-toi. '
          'Tu contrôles la profondeur et la trajectoire.',
      'en': 'Box squat: sit lightly back onto a chair/box, then stand. You control the depth '
          'and the path.',
    },
  ),

  'mountain_climber': MovementGuide(
    id: 'mountain_climber',
    svgAsset: movementSvgAsset('mountain_climber'),
    name: const {'fr': 'Grimpeur (mountain climber)', 'en': 'Mountain climber'},
    steps: const {
      'fr': [
        'Position de planche haute : mains sous les épaules, corps gainé en ligne droite.',
        'Garde les hanches basses et stables.',
        'Ramène un genou vers la poitrine, puis change de jambe en cadence.',
        'Alterne rapidement : 1 rep = une montée de genou.',
      ],
      'en': [
        'High plank position: hands under the shoulders, body braced in a straight line.',
        'Keep your hips low and stable.',
        'Drive one knee toward your chest, then switch legs in rhythm.',
        'Alternate quickly: 1 rep = one knee drive.',
      ],
    },
    cues: const {
      'fr': [
        'Garde les hanches basses : pas de « pic » vers le haut.',
        'Épaules au-dessus des mains, gainage actif.',
        'Respire en rythme avec la cadence.',
      ],
      'en': [
        'Keep the hips low: no “pike” upward.',
        'Shoulders over the hands, active core.',
        'Breathe in rhythm with the cadence.',
      ],
    },
    mistakes: const {
      'fr': [
        'Hanches qui montent (on perd la planche).',
        'Genoux qui ne montent pas assez haut.',
        'Mains trop en avant des épaules.',
      ],
      'en': [
        'Hips rising (you lose the plank).',
        'Knees not coming up high enough.',
        'Hands too far ahead of the shoulders.',
      ],
    },
    beginner: const {
      'fr': 'Ralentis la cadence et/ou pose les mains sur un banc surélevé pour réduire la charge '
          'sur les épaules.',
      'en': 'Slow the cadence and/or place your hands on an elevated bench to reduce the load '
          'on the shoulders.',
    },
  ),

  'lunge': MovementGuide(
    id: 'lunge',
    svgAsset: movementSvgAsset('lunge'),
    name: const {'fr': 'Fente marchée', 'en': 'Walking lunge'},
    steps: const {
      'fr': [
        'Debout, gainage actif, regard devant.',
        'Fais un grand pas en avant et descends en pliant les deux genoux.',
        'Le genou arrière frôle le sol ; le genou avant reste au-dessus de la cheville.',
        'Pousse dans le talon avant pour avancer et enchaîner sur l’autre jambe.',
      ],
      'en': [
        'Stand tall, core engaged, eyes forward.',
        'Take a big step forward and lower by bending both knees.',
        'The back knee gently touches the floor; the front knee stays over the ankle.',
        'Drive through the front heel to step forward onto the other leg.',
      ],
    },
    cues: const {
      'fr': [
        'Buste droit, ne te penche pas en avant.',
        'Le genou avant suit la pointe du pied (ne rentre pas).',
        'Contact léger du genou arrière, sans choc.',
      ],
      'en': [
        'Keep your torso upright, don’t lean forward.',
        'The front knee tracks over the toes (no cave-in).',
        'Light back-knee contact, no slamming.',
      ],
    },
    mistakes: const {
      'fr': [
        'Genou avant qui dépasse loin devant les orteils.',
        'Buste penché vers l’avant.',
        'Pas trop court qui surcharge le genou avant.',
      ],
      'en': [
        'Front knee shooting far past the toes.',
        'Torso tipping forward.',
        'Too short a step, overloading the front knee.',
      ],
    },
    beginner: const {
      'fr': 'Fente statique (sans avancer, on remonte sur place), ou fente à amplitude réduite '
          'en se tenant à un appui pour l’équilibre.',
      'en': 'Static split-squat lunge (return on the spot, no walking), or shorter-range lunge '
          'holding a support for balance.',
    },
  ),

  'burpee': MovementGuide(
    id: 'burpee',
    svgAsset: movementSvgAsset('burpee'),
    name: const {'fr': 'Burpee', 'en': 'Burpee'},
    steps: const {
      'fr': [
        'Debout, puis accroupis-toi et pose les mains au sol.',
        'Renvoie les pieds en arrière pour arriver en planche, poitrine au sol.',
        'Ramène les pieds vers les mains et relève-toi.',
        'Termine par un petit saut avec les mains au-dessus de la tête.',
      ],
      'en': [
        'Stand, then squat down and place your hands on the floor.',
        'Kick your feet back into a plank, chest to the floor.',
        'Jump your feet back toward your hands and stand up.',
        'Finish with a small jump, hands overhead.',
      ],
    },
    cues: const {
      'fr': [
        'Garde un rythme régulier et respirable plutôt que de partir trop vite.',
        'Gaine le ventre quand tu poses la poitrine au sol.',
        'Reçois le saut genoux souples.',
      ],
      'en': [
        'Keep a steady, breathable pace rather than starting too fast.',
        'Brace your core when your chest hits the floor.',
        'Land the jump with soft knees.',
      ],
    },
    mistakes: const {
      'fr': [
        'Hanches qui s’affaissent quand la poitrine touche le sol.',
        'Partir trop vite et exploser cardio en 30 secondes.',
        'Oublier le saut / l’extension complète debout.',
      ],
      'en': [
        'Hips sagging when the chest hits the floor.',
        'Going out too fast and gassing out in 30 seconds.',
        'Skipping the jump / full standing extension.',
      ],
    },
    beginner: const {
      'fr': 'Burpee « step-back » : pose les pieds en arrière un par un (sans sauter), pas de '
          'poitrine au sol, monte sur la pointe au lieu de sauter.',
      'en': 'Step-back burpee: walk your feet back one at a time (no jump), skip the chest-to-floor, '
          'rise onto your toes instead of jumping.',
    },
  ),

  'burpee_broad_jump': MovementGuide(
    id: 'burpee_broad_jump',
    svgAsset: movementSvgAsset('burpee_broad_jump'),
    name: const {'fr': 'Burpee saut en longueur', 'en': 'Burpee broad jump'},
    steps: const {
      'fr': [
        'Fais un burpee complet : descente poitrine au sol, retour debout.',
        'En te relevant, fléchis légèrement les jambes et balance les bras.',
        'Saute le plus loin possible vers l’avant, à pieds joints.',
        'Réceptionne genoux souples, puis enchaîne le burpee suivant.',
      ],
      'en': [
        'Perform a full burpee: chest to floor, back to standing.',
        'As you stand, dip slightly and swing your arms.',
        'Jump forward as far as you can, feet together.',
        'Land with soft knees, then chain into the next burpee.',
      ],
    },
    cues: const {
      'fr': [
        'Sers-toi des bras pour gagner de la distance au saut.',
        'Réception amortie : genoux et hanches qui plient.',
        'Garde un rythme gérable, c’est très cardio.',
      ],
      'en': [
        'Use your arms to add distance on the jump.',
        'Cushion the landing: knees and hips bend.',
        'Keep a manageable pace — it’s very taxing.',
      ],
    },
    mistakes: const {
      'fr': [
        'Réception jambes raides (choc dans les genoux).',
        'Sauter peu loin par peur de la fatigue.',
        'Bâcler le burpee en oubliant la poitrine au sol.',
      ],
      'en': [
        'Stiff-legged landing (impact through the knees).',
        'Tiny jumps out of fear of fatigue.',
        'Rushing the burpee and skipping chest-to-floor.',
      ],
    },
    beginner: const {
      'fr': 'Burpee step-back + petit saut court (ou un simple pas en avant) au lieu du grand '
          'saut en longueur.',
      'en': 'Step-back burpee + a short hop (or a simple step forward) instead of the full '
          'broad jump.',
    },
  ),

  'box_jump': MovementGuide(
    id: 'box_jump',
    svgAsset: movementSvgAsset('box_jump'),
    name: const {'fr': 'Saut sur boîte', 'en': 'Box jump'},
    steps: const {
      'fr': [
        'Place-toi face à la boîte, pieds largeur de hanches, à une longueur de pied.',
        'Fléchis légèrement les jambes et balance les bras vers l’arrière.',
        'Saute en projetant les bras vers l’avant et atterris des deux pieds sur la boîte.',
        'Tiens-toi debout, hanches tendues, puis redescends (saut ou step-down).',
      ],
      'en': [
        'Face the box, feet hip-width, about a foot’s length away.',
        'Dip slightly and swing your arms back.',
        'Jump, throwing your arms forward, and land on the box with both feet.',
        'Stand tall with hips extended, then come down (jump or step-down).',
      ],
    },
    cues: const {
      'fr': [
        'Réception souple sur toute la surface du pied, genoux fléchis.',
        'Hanches complètement tendues debout sur la boîte.',
        'En cas de fatigue, descends en marchant (step-down) pour épargner les tendons.',
      ],
      'en': [
        'Soft landing on the whole foot, knees bent.',
        'Fully extend the hips standing on top of the box.',
        'When tired, step down to spare your tendons.',
      ],
    },
    mistakes: const {
      'fr': [
        'Réception jambes raides ou en boule (genoux écrasés).',
        'Ne pas se redresser complètement sur la boîte.',
        'Rebondir sans contrôle (risque de rater la boîte, tibias).',
      ],
      'en': [
        'Stiff or over-collapsed landing (knees crushed).',
        'Not standing fully tall on the box.',
        'Rebounding without control (risk of missing the box, shins).',
      ],
    },
    beginner: const {
      'fr': 'Step-up sur boîte basse (on monte un pied puis l’autre, sans saut), ou saut sur une '
          'boîte plus basse.',
      'en': 'Step-up on a low box (one foot then the other, no jump), or jump onto a lower box.',
    },
  ),

  'squat_jump': MovementGuide(
    id: 'squat_jump',
    svgAsset: movementSvgAsset('squat_jump'),
    name: const {'fr': 'Squat sauté', 'en': 'Squat jump'},
    steps: const {
      'fr': [
        'Debout, pieds largeur de hanches, gainage actif.',
        'Descends en squat (hanches sous les genoux), poitrine haute.',
        'Pousse explosivement dans les pieds et saute en décollant du sol.',
        'Réceptionne en douceur et enchaîne directement le squat suivant.',
      ],
      'en': [
        'Stand with feet hip-width, core engaged.',
        'Drop into a squat (hips below knees), chest tall.',
        'Drive explosively through your feet and jump off the ground.',
        'Land softly and flow straight into the next squat.',
      ],
    },
    cues: const {
      'fr': [
        'Réception amortie : genoux et hanches absorbent le choc.',
        'Cherche l’explosivité à la remontée, pas juste la vitesse.',
        'Garde le dos droit même fatigué.',
      ],
      'en': [
        'Cushioned landing: knees and hips absorb the impact.',
        'Aim for explosiveness on the way up, not just speed.',
        'Keep your back flat even when tired.',
      ],
    },
    mistakes: const {
      'fr': [
        'Réception raide (impact dans les genoux).',
        'Squat trop peu profond pour « gagner » des reps.',
        'Genoux qui rentrent à la poussée.',
      ],
      'en': [
        'Stiff landing (impact in the knees).',
        'Shallow squat to “game” the reps.',
        'Knees caving in on the drive.',
      ],
    },
    beginner: const {
      'fr': 'Squat au poids du corps avec une simple extension sur la pointe des pieds (sans '
          'décoller), ou squats sautés en réduisant l’amplitude.',
      'en': 'Bodyweight squat with a calf raise at the top (no jump), or squat jumps with a '
          'shorter range of motion.',
    },
  ),

  'double_under': MovementGuide(
    id: 'double_under',
    svgAsset: movementSvgAsset('double_under'),
    name: const {'fr': 'Double saut à la corde', 'en': 'Double-under'},
    steps: const {
      'fr': [
        'Corde à sauter réglée à ta taille, mains près des hanches.',
        'Saute sur place, jambes presque tendues, pointes de pieds.',
        'Fais tourner la corde DEUX fois sous tes pieds en un seul saut, par un coup de poignets.',
        'Garde un rythme régulier et reste sur place.',
      ],
      'en': [
        'Rope sized to your height, hands near your hips.',
        'Jump in place, legs nearly straight, on the balls of your feet.',
        'Spin the rope TWICE under your feet in a single jump, using a flick of the wrists.',
        'Keep a steady rhythm and stay in one spot.',
      ],
    },
    cues: const {
      'fr': [
        'Le travail vient des poignets, pas des bras.',
        'Saut un peu plus haut mais bref, pas de « pédalage ».',
        'Garde les coudes proches du corps.',
      ],
      'en': [
        'The work comes from the wrists, not the arms.',
        'Jump a touch higher but briefly, no “cycling” the legs.',
        'Keep your elbows close to the body.',
      ],
    },
    mistakes: const {
      'fr': [
        'Plier les jambes vers l’arrière (kick) en sautant.',
        'Faire de grands cercles avec les bras.',
        'Se déplacer en avant à chaque saut.',
      ],
      'en': [
        'Kicking the heels back while jumping.',
        'Making big circles with the arms.',
        'Drifting forward with each jump.',
      ],
    },
    beginner: const {
      'fr': 'Maîtrise d’abord le saut simple (single-under) régulier, puis essaie « simple-simple-'
          'double » pour intégrer le double progressivement.',
      'en': 'Master steady single-unders first, then try “single-single-double” to phase in the '
          'double gradually.',
    },
  ),

  'wall_walk': MovementGuide(
    id: 'wall_walk',
    svgAsset: movementSvgAsset('wall_walk'),
    name: const {'fr': 'Montée au mur (wall walk)', 'en': 'Wall walk'},
    steps: const {
      'fr': [
        'Départ en planche, poitrine au sol, pieds contre le bas du mur.',
        'Pousse sur les bras et commence à monter les pieds le long du mur.',
        'Marche en même temps avec les mains vers le mur jusqu’à être quasi vertical.',
        'Reviens en sens inverse, sous contrôle, jusqu’à la planche au sol.',
      ],
      'en': [
        'Start in a plank, chest on the floor, feet against the base of the wall.',
        'Press up on your arms and start walking your feet up the wall.',
        'At the same time, walk your hands toward the wall until nearly vertical.',
        'Reverse the movement under control back to the floor plank.',
      ],
    },
    cues: const {
      'fr': [
        'Gaine fort le ventre : ne cambre pas le bas du dos.',
        'Avance les mains et les pieds de façon coordonnée.',
        'Garde les bras tendus et solides.',
      ],
      'en': [
        'Brace the core hard: don’t arch the lower back.',
        'Move hands and feet in a coordinated way.',
        'Keep your arms straight and strong.',
      ],
    },
    mistakes: const {
      'fr': [
        'Bas du dos cambré (gainage qui lâche).',
        'Mains qui restent loin du mur en haut.',
        'Descente non contrôlée.',
      ],
      'en': [
        'Arched lower back (core gives out).',
        'Hands staying far from the wall at the top.',
        'Uncontrolled descent.',
      ],
    },
    beginner: const {
      'fr': 'Monte seulement à mi-hauteur (planche inclinée), ou tiens une planche haute + pompe '
          'en pic pour bâtir la force d’épaules.',
      'en': 'Walk up only halfway (incline plank), or hold a high plank + pike push-ups to build '
          'shoulder strength.',
    },
  ),

  'pistol_squat': MovementGuide(
    id: 'pistol_squat',
    svgAsset: movementSvgAsset('pistol_squat'),
    name: const {'fr': 'Squat sur une jambe (pistol)', 'en': 'Pistol squat'},
    steps: const {
      'fr': [
        'Debout sur une jambe, l’autre tendue devant toi, bras devant pour l’équilibre.',
        'Gaine le ventre, poitrine haute.',
        'Descends lentement sur la jambe d’appui en gardant l’autre jambe tendue devant.',
        'Hanche sous le genou, puis remonte en poussant dans le talon.',
      ],
      'en': [
        'Stand on one leg, the other extended in front, arms forward for balance.',
        'Brace your core, chest tall.',
        'Lower slowly on the standing leg, keeping the other leg straight out front.',
        'Hip below the knee, then stand by driving through the heel.',
      ],
    },
    cues: const {
      'fr': [
        'Talon d’appui bien ancré au sol.',
        'Genou d’appui suit la pointe de pied (ne rentre pas).',
        'Contrôle la descente, ne te laisse pas tomber.',
      ],
      'en': [
        'Keep the standing heel firmly planted.',
        'The working knee tracks over the toes (no cave-in).',
        'Control the descent, don’t drop.',
      ],
    },
    mistakes: const {
      'fr': [
        'Talon qui décolle (perte d’équilibre vers l’avant).',
        'Genou qui rentre vers l’intérieur.',
        'Se laisser tomber sans contrôle en bas.',
      ],
      'en': [
        'Heel lifting (falling forward).',
        'Knee caving inward.',
        'Crashing into the bottom without control.',
      ],
    },
    beginner: const {
      'fr': 'Pistol assisté : tiens un poteau / une sangle d’une main, ou descends t’asseoir sur '
          'une boîte sur une jambe puis relève-toi.',
      'en': 'Assisted pistol: hold a pole / strap with one hand, or sit down to a box on one leg '
          'then stand back up.',
    },
  ),

  // =====================================================================================
  // HALTÉROPHILIE / CHARGE
  // =====================================================================================
  'thruster': MovementGuide(
    id: 'thruster',
    svgAsset: movementSvgAsset('thruster'),
    name: const {'fr': 'Thruster', 'en': 'Thruster'},
    steps: const {
      'fr': [
        'Barre en position de front squat : sur le haut de la poitrine, coudes hauts.',
        'Pieds largeur d’épaules, gainage actif.',
        'Descends en front squat complet (hanches sous les genoux).',
        'Remonte explosivement et enchaîne sans temps mort en poussant la barre au-dessus de la tête, bras tendus.',
      ],
      'en': [
        'Bar in the front-rack: on the upper chest, elbows high.',
        'Feet shoulder-width, core braced.',
        'Drop into a full front squat (hips below knees).',
        'Stand up explosively and, in one motion, drive the bar overhead to straight arms.',
      ],
    },
    cues: const {
      'fr': [
        'Un seul mouvement fluide : la poussée des jambes lance la barre vers le haut.',
        'Coudes hauts dans le squat pour garder la barre stable.',
        'Verrouille les bras et la tête « traverse » sous la barre en fin de poussée.',
      ],
      'en': [
        'One fluid motion: leg drive launches the bar upward.',
        'Keep elbows high in the squat to keep the bar stable.',
        'Lock the arms and let your head “pass through” under the bar at the finish.',
      ],
    },
    mistakes: const {
      'fr': [
        'Marquer un arrêt entre le squat et la poussée (perte d’élan).',
        'Coudes qui tombent dans le squat (barre qui roule en avant).',
        'Ne pas verrouiller les bras en haut.',
      ],
      'en': [
        'Pausing between the squat and the press (losing momentum).',
        'Elbows dropping in the squat (bar rolls forward).',
        'Not locking the arms out at the top.',
      ],
    },
    beginner: const {
      'fr': 'Thruster avec une barre à vide, des haltères légers, ou même sans charge pour '
          'apprendre le timing jambes-bras.',
      'en': 'Thruster with an empty bar, light dumbbells, or even no load to learn the leg-to-arm '
          'timing.',
    },
  ),

  'wall_ball': MovementGuide(
    id: 'wall_ball',
    svgAsset: movementSvgAsset('wall_ball'),
    name: const {'fr': 'Wall ball (lancer au mur)', 'en': 'Wall ball'},
    steps: const {
      'fr': [
        'Face au mur, médecine-ball tenu sous le menton, coudes sous la balle.',
        'Descends en squat complet, dos droit.',
        'Remonte explosivement et lance la balle vers une cible haute sur le mur.',
        'Rattrape la balle en l’absorbant et enchaîne directement le squat suivant.',
      ],
      'en': [
        'Facing the wall, hold the medicine ball under your chin, elbows under the ball.',
        'Drop into a full squat, flat back.',
        'Stand up explosively and throw the ball to a high target on the wall.',
        'Catch the ball, absorbing it, and flow straight into the next squat.',
      ],
    },
    cues: const {
      'fr': [
        'La puissance vient des jambes, les bras ne font que guider/lancer.',
        'Squat complet à chaque rep (hanches sous les genoux).',
        'Réceptionne la balle en pliant les bras pour amortir.',
      ],
      'en': [
        'Power comes from the legs; the arms only guide/throw.',
        'Full squat on every rep (hips below knees).',
        'Catch the ball by bending the arms to cushion it.',
      ],
    },
    mistakes: const {
      'fr': [
        'Lancer trop bas (cible non atteinte).',
        'Squat partiel pour aller plus vite.',
        'Rattraper la balle bras tendus (choc).',
      ],
      'en': [
        'Throwing too low (target not reached).',
        'Partial squat to go faster.',
        'Catching the ball with straight arms (jarring).',
      ],
    },
    beginner: const {
      'fr': 'Utilise une balle plus légère et/ou une cible plus basse ; au besoin, sépare le geste '
          '(squat puis lancer) avant de l’enchaîner.',
      'en': 'Use a lighter ball and/or a lower target; if needed, split the movement (squat then '
          'throw) before chaining it.',
    },
  ),

  'deadlift': MovementGuide(
    id: 'deadlift',
    svgAsset: movementSvgAsset('deadlift'),
    name: const {'fr': 'Soulevé de terre', 'en': 'Deadlift'},
    steps: const {
      'fr': [
        'Pieds largeur de hanches, barre au-dessus du milieu des pieds, tibias proches.',
        'Charnière de hanche : pousse les fesses vers l’arrière et attrape la barre, dos plat.',
        'Gaine le ventre, poitrine haute, épaules juste devant la barre.',
        'Pousse dans le sol avec les jambes et tends les hanches pour te redresser, barre proche du corps.',
      ],
      'en': [
        'Feet hip-width, bar over the middle of your feet, shins close.',
        'Hinge at the hips: push your butt back and grab the bar, flat back.',
        'Brace your core, chest tall, shoulders just over the bar.',
        'Push the floor away with your legs and extend the hips to stand, bar close to the body.',
      ],
    },
    cues: const {
      'fr': [
        'Dos PLAT du début à la fin (jamais arrondi) : c’est la règle de sécurité n°1.',
        'La barre frôle les jambes et reste proche du corps.',
        'Pousse dans le sol avec les jambes plutôt que de « tirer » avec le dos.',
      ],
      'en': [
        'FLAT back from start to finish (never rounded): safety rule number one.',
        'The bar grazes the legs and stays close to the body.',
        'Push the floor away with the legs rather than “yanking” with the back.',
      ],
    },
    mistakes: const {
      'fr': [
        'Dos arrondi (risque de blessure lombaire majeur).',
        'Hanches qui montent trop vite avant la barre.',
        'Barre qui s’éloigne du corps (bras vers l’avant).',
      ],
      'en': [
        'Rounded back (major lower-back injury risk).',
        'Hips shooting up before the bar moves.',
        'Bar drifting away from the body (arms forward).',
      ],
    },
    beginner: const {
      'fr': 'Soulevé de terre avec une charge légère, barre surélevée (sur des plots) ou avec '
          'kettlebell / haltères, pour apprendre la charnière de hanche.',
      'en': 'Deadlift with a light load, the bar raised on blocks, or with a kettlebell / '
          'dumbbells, to learn the hip hinge.',
    },
  ),

  'clean': MovementGuide(
    id: 'clean',
    svgAsset: movementSvgAsset('clean'),
    name: const {'fr': 'Épaulé (power clean)', 'en': 'Power clean'},
    steps: const {
      'fr': [
        'Barre au sol au-dessus du milieu des pieds, charnière de hanche, dos plat.',
        'Tire la barre du sol en gardant les bras tendus, barre proche des tibias.',
        'Au niveau des hanches, donne une extension explosive (saut) hanches-genoux-chevilles.',
        'Tire-toi sous la barre et réceptionne-la en position de front squat (sur les épaules), genoux fléchis.',
      ],
      'en': [
        'Bar on the floor over the mid-foot, hip hinge, flat back.',
        'Pull the bar off the floor with straight arms, bar close to the shins.',
        'At the hips, give an explosive extension (jump) of hips-knees-ankles.',
        'Pull yourself under the bar and catch it in the front-rack (on the shoulders), knees bent.',
      ],
    },
    cues: const {
      'fr': [
        'Les bras restent tendus jusqu’à l’extension : ils ne tirent pas la barre.',
        'Extension complète des hanches avant de passer dessous.',
        'Réception coudes hauts pour bloquer la barre sur les épaules.',
      ],
      'en': [
        'Arms stay straight until the extension: they don’t pull the bar up.',
        'Full hip extension before pulling under.',
        'Catch with high elbows to rack the bar on the shoulders.',
      ],
    },
    mistakes: const {
      'fr': [
        'Tirer avec les bras trop tôt (« reverse curl »).',
        'Coudes lents à la réception (barre qui chute).',
        'Dos arrondi au départ du sol.',
      ],
      'en': [
        'Pulling with the arms too early (“reverse curl”).',
        'Slow elbows on the catch (bar drops).',
        'Rounded back off the floor.',
      ],
    },
    beginner: const {
      'fr': 'Épaulé depuis les hanches (« hang clean ») barre à vide ou haltères, pour apprendre '
          'l’extension explosive sans gérer la trajectoire complète depuis le sol.',
      'en': 'Hang clean (from the hips) with an empty bar or dumbbells, to learn the explosive '
          'extension without managing the full path from the floor.',
    },
  ),

  'clean_and_jerk': MovementGuide(
    id: 'clean_and_jerk',
    svgAsset: movementSvgAsset('clean_and_jerk'),
    name: const {'fr': 'Épaulé-jeté', 'en': 'Clean & jerk'},
    steps: const {
      'fr': [
        'Réalise un épaulé : amène la barre du sol jusqu’aux épaules (front rack).',
        'Debout, stabilise la barre sur les épaules, gainage actif.',
        'Fléchis légèrement les jambes (dip) puis pousse explosivement la barre vers le haut.',
        'Passe la tête sous la barre et réceptionne bras tendus au-dessus de la tête, puis stabilise.',
      ],
      'en': [
        'Perform a clean: bring the bar from the floor to the shoulders (front rack).',
        'Stand and stabilise the bar on the shoulders, core braced.',
        'Dip slightly with the legs, then drive the bar explosively upward.',
        'Move your head under the bar and catch with straight arms overhead, then stabilise.',
      ],
    },
    cues: const {
      'fr': [
        'Deux temps : épaulé d’abord, jeté ensuite (souffle entre les deux).',
        'La poussée du jeté vient des jambes (dip-drive), pas des bras.',
        'Verrouille bien les bras et les épaules au-dessus de la tête.',
      ],
      'en': [
        'Two phases: clean first, jerk second (breathe between them).',
        'The jerk drive comes from the legs (dip-drive), not the arms.',
        'Lock the arms and shoulders firmly overhead.',
      ],
    },
    mistakes: const {
      'fr': [
        'Pousser le jeté à la force des bras sans dip de jambes.',
        'Barre qui part en avant au-dessus de la tête.',
        'Réception déséquilibrée (pieds qui ne se replacent pas).',
      ],
      'en': [
        'Pressing the jerk with the arms, no leg dip.',
        'Bar drifting forward overhead.',
        'Unbalanced catch (feet not resetting).',
      ],
    },
    beginner: const {
      'fr': 'Travaille séparément l’épaulé (hang clean léger) et le jeté (push press barre à vide) '
          'avant de les combiner. Charges légères impératives.',
      'en': 'Practise the clean (light hang clean) and the jerk (empty-bar push press) separately '
          'before combining them. Light loads are a must.',
    },
  ),

  'snatch': MovementGuide(
    id: 'snatch',
    svgAsset: movementSvgAsset('snatch'),
    name: const {'fr': 'Arraché (power snatch)', 'en': 'Power snatch'},
    steps: const {
      'fr': [
        'Prise large sur la barre au sol, charnière de hanche, dos plat.',
        'Tire la barre du sol bras tendus, proche du corps.',
        'Extension explosive des hanches au niveau du bassin (saut).',
        'Tire-toi sous la barre et réceptionne-la directement au-dessus de la tête, bras tendus, en demi-squat.',
      ],
      'en': [
        'Wide grip on the bar on the floor, hip hinge, flat back.',
        'Pull the bar off the floor with straight arms, close to the body.',
        'Explosive hip extension at hip level (jump).',
        'Pull yourself under the bar and catch it directly overhead, straight arms, in a partial squat.',
      ],
    },
    cues: const {
      'fr': [
        'Un seul geste fluide du sol jusqu’au-dessus de la tête.',
        'Garde la barre très proche du corps tout le long.',
        'Réception bras verrouillés, épaules actives (poussent vers le plafond).',
      ],
      'en': [
        'One fluid motion from floor to overhead.',
        'Keep the bar very close to the body throughout.',
        'Catch with locked arms, active shoulders (pressing to the ceiling).',
      ],
    },
    mistakes: const {
      'fr': [
        'Barre qui s’éloigne du corps (passe en avant).',
        'Tirer avec les bras trop tôt.',
        'Réception molle des épaules (barre instable au-dessus).',
      ],
      'en': [
        'Bar swinging away from the body (loops forward).',
        'Pulling with the arms too early.',
        'Soft shoulders on the catch (unstable overhead).',
      ],
    },
    beginner: const {
      'fr': 'Arraché depuis les hanches (« hang power snatch ») avec barre à vide ou un haltère '
          '(DB snatch), pour apprendre l’explosivité et la réception au-dessus de la tête.',
      'en': 'Hang power snatch with an empty bar or a single dumbbell (DB snatch), to learn the '
          'explosiveness and the overhead catch.',
    },
  ),

  'overhead_squat': MovementGuide(
    id: 'overhead_squat',
    svgAsset: movementSvgAsset('overhead_squat'),
    name: const {'fr': 'Squat barre au-dessus de la tête', 'en': 'Overhead squat'},
    steps: const {
      'fr': [
        'Barre verrouillée au-dessus de la tête, prise large, bras tendus, épaules actives.',
        'Pieds largeur d’épaules, gainage fort, barre légèrement derrière la nuque.',
        'Descends en squat complet en gardant la barre stable au-dessus.',
        'Remonte en poussant dans les talons, barre toujours au-dessus de la tête.',
      ],
      'en': [
        'Bar locked overhead, wide grip, straight arms, active shoulders.',
        'Feet shoulder-width, strong brace, bar slightly behind the neck.',
        'Drop into a full squat keeping the bar stable overhead.',
        'Stand by driving through the heels, bar still overhead.',
      ],
    },
    cues: const {
      'fr': [
        'Pousse activement la barre vers le plafond du début à la fin.',
        'Garde le buste droit et le gainage très ferme.',
        'Mobilité d’épaules et de chevilles indispensable : échauffe-toi bien.',
      ],
      'en': [
        'Actively press the bar to the ceiling from start to finish.',
        'Keep the torso upright and the core very tight.',
        'Shoulder and ankle mobility are essential: warm up well.',
      ],
    },
    mistakes: const {
      'fr': [
        'Barre qui part en avant (épaules qui relâchent).',
        'Buste qui se penche en avant.',
        'Squat partiel par manque de mobilité.',
      ],
      'en': [
        'Bar drifting forward (shoulders relaxing).',
        'Torso tipping forward.',
        'Partial squat due to limited mobility.',
      ],
    },
    beginner: const {
      'fr': 'Overhead squat avec un bâton/PVC ou une barre à vide ; travaille d’abord la mobilité '
          'et l’équilibre avant d’ajouter de la charge.',
      'en': 'Overhead squat with a PVC pipe or empty bar; work on mobility and balance first '
          'before adding load.',
    },
  ),

  'front_squat': MovementGuide(
    id: 'front_squat',
    svgAsset: movementSvgAsset('front_squat'),
    name: const {'fr': 'Squat avant (front squat)', 'en': 'Front squat'},
    steps: const {
      'fr': [
        'Barre sur le haut de la poitrine (front rack), coudes hauts et pointés vers l’avant.',
        'Pieds largeur d’épaules, gainage actif, poitrine haute.',
        'Descends en squat complet, hanches sous les genoux, coudes toujours hauts.',
        'Remonte en poussant dans les talons, buste droit.',
      ],
      'en': [
        'Bar on the upper chest (front rack), elbows high and pointing forward.',
        'Feet shoulder-width, core braced, chest tall.',
        'Drop into a full squat, hips below knees, elbows still high.',
        'Stand by driving through the heels, torso upright.',
      ],
    },
    cues: const {
      'fr': [
        'Garde les coudes HAUTS : c’est ce qui empêche la barre de rouler en avant.',
        'Buste le plus vertical possible.',
        'Pousse dans les talons et tout le pied.',
      ],
      'en': [
        'Keep the elbows HIGH: this stops the bar from rolling forward.',
        'Torso as upright as possible.',
        'Drive through the heels and the whole foot.',
      ],
    },
    mistakes: const {
      'fr': [
        'Coudes qui tombent (barre qui glisse en avant).',
        'Buste qui bascule en avant.',
        'Talons qui décollent.',
      ],
      'en': [
        'Elbows dropping (bar slides forward).',
        'Torso tipping forward.',
        'Heels lifting.',
      ],
    },
    beginner: const {
      'fr': 'Front squat barre à vide ou avec deux haltères posés sur les épaules ; si la mobilité '
          'des poignets gêne, utilise une prise croisée.',
      'en': 'Front squat with an empty bar or two dumbbells resting on the shoulders; if wrist '
          'mobility is an issue, use a cross-arm grip.',
    },
  ),

  'shoulder_to_overhead': MovementGuide(
    id: 'shoulder_to_overhead',
    svgAsset: movementSvgAsset('shoulder_to_overhead'),
    name: const {'fr': 'Épaule au-dessus de la tête', 'en': 'Shoulder-to-overhead'},
    steps: const {
      'fr': [
        'Barre sur les épaules (front rack), pieds largeur de hanches, gainage actif.',
        'Fléchis légèrement les jambes (dip court et vertical).',
        'Pousse explosivement la barre au-dessus de la tête en tendant les jambes.',
        'Verrouille bras et épaules au-dessus de la tête, tête « à travers ».',
      ],
      'en': [
        'Bar on the shoulders (front rack), feet hip-width, core braced.',
        'Dip slightly with the legs (short, vertical dip).',
        'Drive the bar explosively overhead while extending the legs.',
        'Lock arms and shoulders overhead, head “through”.',
      ],
    },
    cues: const {
      'fr': [
        'Englobe push press / push jerk : utilise les jambes pour lancer la barre.',
        'Dip court et vertical (pas un demi-squat penché).',
        'Verrouille bien en haut avant de redescendre la barre.',
      ],
      'en': [
        'Covers push press / push jerk: use the legs to launch the bar.',
        'Short, vertical dip (not a leaning half-squat).',
        'Lock out fully overhead before lowering the bar.',
      ],
    },
    mistakes: const {
      'fr': [
        'Pousser seulement avec les bras (sans dip de jambes).',
        'Dip vers l’avant qui projette la barre devant.',
        'Ne pas verrouiller les coudes en haut.',
      ],
      'en': [
        'Pressing with the arms only (no leg dip).',
        'Forward dip that throws the bar in front.',
        'Not locking the elbows at the top.',
      ],
    },
    beginner: const {
      'fr': 'Développé strict (« strict press ») barre à vide ou haltères, puis push press léger '
          'pour apprendre à utiliser les jambes.',
      'en': 'Strict press with an empty bar or dumbbells, then a light push press to learn how to '
          'use the legs.',
    },
  ),

  'kettlebell_swing': MovementGuide(
    id: 'kettlebell_swing',
    svgAsset: movementSvgAsset('kettlebell_swing'),
    name: const {'fr': 'Swing kettlebell', 'en': 'Kettlebell swing'},
    steps: const {
      'fr': [
        'Kettlebell au sol devant toi, pieds un peu plus larges que les hanches.',
        'Charnière de hanche (fesses en arrière, dos plat), attrape la poignée à deux mains.',
        'Balance la kettlebell entre les jambes, puis donne une extension explosive des hanches.',
        'La kettlebell monte (hauteur poitrine ou au-dessus de la tête selon la version), bras détendus, puis redescends en charnière.',
      ],
      'en': [
        'Kettlebell on the floor in front of you, feet slightly wider than the hips.',
        'Hinge at the hips (butt back, flat back), grab the handle with both hands.',
        'Swing the kettlebell between your legs, then snap the hips forward explosively.',
        'The kettlebell floats up (chest height or overhead depending on the version), relaxed arms, then hinge back down.',
      ],
    },
    cues: const {
      'fr': [
        'La puissance vient des HANCHES, pas des bras (les bras ne sont qu’une corde).',
        'Dos plat tout du long, jamais arrondi.',
        'Serre les fessiers et gaine le ventre en haut du swing.',
      ],
      'en': [
        'Power comes from the HIPS, not the arms (the arms are just a rope).',
        'Flat back throughout, never rounded.',
        'Squeeze the glutes and brace the core at the top of the swing.',
      ],
    },
    mistakes: const {
      'fr': [
        'Squatter au lieu de faire une charnière de hanche.',
        'Tirer la kettlebell avec les bras.',
        'Dos arrondi en bas du mouvement.',
      ],
      'en': [
        'Squatting instead of hinging at the hips.',
        'Pulling the kettlebell up with the arms.',
        'Rounding the back at the bottom.',
      ],
    },
    beginner: const {
      'fr': 'Commence avec une kettlebell légère et un swing « russe » (hauteur poitrine seulement), '
          'le temps de maîtriser la charnière de hanche.',
      'en': 'Start with a light kettlebell and a “Russian” swing (chest height only) while you '
          'master the hip hinge.',
    },
  ),

  'dumbbell_snatch': MovementGuide(
    id: 'dumbbell_snatch',
    svgAsset: movementSvgAsset('dumbbell_snatch'),
    name: const {'fr': 'Arraché haltère', 'en': 'Dumbbell snatch'},
    steps: const {
      'fr': [
        'Un haltère posé au sol entre les pieds, charnière de hanche, dos plat, une main sur l’haltère.',
        'Tire l’haltère du sol proche du corps, bras tendu.',
        'Extension explosive des hanches, puis tire l’haltère le long du corps.',
        'Réceptionne bras tendu au-dessus de la tête, puis stabilise debout.',
      ],
      'en': [
        'One dumbbell on the floor between the feet, hip hinge, flat back, one hand on the dumbbell.',
        'Pull the dumbbell off the floor close to the body, straight arm.',
        'Explosive hip extension, then pull the dumbbell up along the body.',
        'Catch with a straight arm overhead, then stand tall to stabilise.',
      ],
    },
    cues: const {
      'fr': [
        'La hanche lance l’haltère ; le bras ne fait que guider.',
        'Garde l’haltère proche du corps à la montée.',
        'Verrouille le bras et pousse l’épaule vers le plafond en haut.',
      ],
      'en': [
        'The hip launches the dumbbell; the arm only guides.',
        'Keep the dumbbell close to the body on the way up.',
        'Lock the arm and press the shoulder to the ceiling at the top.',
      ],
    },
    mistakes: const {
      'fr': [
        'Tirer à la force du bras (façon « curl »).',
        'Haltère qui s’écarte du corps.',
        'Dos arrondi au départ du sol.',
      ],
      'en': [
        'Muscling it up with the arm (curl-style).',
        'Dumbbell swinging away from the body.',
        'Rounded back off the floor.',
      ],
    },
    beginner: const {
      'fr': 'Arraché haltère depuis les hanches (« hang ») avec un poids léger, ou décompose en '
          'soulevé de terre haltère + tirage menton avant d’enchaîner.',
      'en': 'Hang dumbbell snatch with a light weight, or break it into a dumbbell deadlift + high '
          'pull before chaining it together.',
    },
  ),

  'thruster_db': MovementGuide(
    id: 'thruster_db',
    svgAsset: movementSvgAsset('thruster_db'),
    name: const {'fr': 'Thruster haltères', 'en': 'Dumbbell thruster'},
    steps: const {
      'fr': [
        'Un haltère sur chaque épaule, paume vers l’intérieur, coudes hauts.',
        'Pieds largeur d’épaules, gainage actif.',
        'Descends en squat complet, haltères stables sur les épaules.',
        'Remonte explosivement et pousse les haltères au-dessus de la tête, bras tendus, sans temps mort.',
      ],
      'en': [
        'One dumbbell on each shoulder, palms facing in, elbows high.',
        'Feet shoulder-width, core braced.',
        'Drop into a full squat, dumbbells stable on the shoulders.',
        'Stand up explosively and press the dumbbells overhead to straight arms, no pause.',
      ],
    },
    cues: const {
      'fr': [
        'Un seul mouvement fluide : la poussée des jambes lance les haltères.',
        'Garde les haltères stables sur les épaules dans le squat.',
        'Verrouille les bras au-dessus de la tête à chaque rep.',
      ],
      'en': [
        'One fluid motion: leg drive launches the dumbbells.',
        'Keep the dumbbells stable on the shoulders in the squat.',
        'Lock the arms overhead on every rep.',
      ],
    },
    mistakes: const {
      'fr': [
        'Marquer un arrêt entre le squat et la poussée.',
        'Squat partiel.',
        'Haltères qui partent en avant en haut.',
      ],
      'en': [
        'Pausing between the squat and the press.',
        'Partial squat.',
        'Dumbbells drifting forward at the top.',
      ],
    },
    beginner: const {
      'fr': 'Utilise des haltères légers, ou décompose : front squat haltères puis développé '
          'au-dessus de la tête, avant d’enchaîner.',
      'en': 'Use light dumbbells, or split it: dumbbell front squat then overhead press, before '
          'chaining them.',
    },
  ),

  // =====================================================================================
  // CARDIO / MONOSTRUCTUREL
  // =====================================================================================
  'run': MovementGuide(
    id: 'run',
    svgAsset: movementSvgAsset('run'),
    name: const {'fr': 'Course à pied', 'en': 'Running'},
    steps: const {
      'fr': [
        'Tiens-toi droit, regard loin devant, épaules relâchées.',
        'Pose le pied sous ton centre de gravité (pas trop loin devant), foulée légère.',
        'Bras pliés à ~90°, balancier d’avant en arrière (pas en travers du corps).',
        'Trouve une cadence régulière et une respiration que tu peux tenir.',
      ],
      'en': [
        'Stand tall, eyes far ahead, shoulders relaxed.',
        'Land your foot under your centre of gravity (not far in front), light footstrike.',
        'Arms bent at ~90°, swinging front-to-back (not across the body).',
        'Find a steady cadence and a breathing rhythm you can hold.',
      ],
    },
    cues: const {
      'fr': [
        'Pars sur une allure que tu peux tenir : ne sprinte pas le départ.',
        'Épaules et mains relâchées, pas crispées.',
        'Respire de façon régulière et profonde.',
      ],
      'en': [
        'Start at a pace you can sustain: don’t sprint the opening.',
        'Shoulders and hands relaxed, not clenched.',
        'Breathe steadily and deeply.',
      ],
    },
    mistakes: const {
      'fr': [
        'Partir trop vite et exploser après quelques centaines de mètres.',
        'Foulée trop longue qui « freine » à chaque pose de pied.',
        'Crispation des épaules et des bras.',
      ],
      'en': [
        'Going out too fast and blowing up after a few hundred metres.',
        'Overstriding, which “brakes” on each footstrike.',
        'Tension in the shoulders and arms.',
      ],
    },
    beginner: const {
      'fr': 'Alterne course et marche (par ex. 2 min de course / 1 min de marche) et allonge '
          'progressivement les phases de course.',
      'en': 'Alternate running and walking (e.g. 2 min run / 1 min walk) and gradually extend the '
          'running intervals.',
    },
  ),

  'sprint': MovementGuide(
    id: 'sprint',
    svgAsset: movementSvgAsset('sprint'),
    name: const {'fr': 'Sprint (≤200 m)', 'en': 'Sprint (≤200 m)'},
    steps: const {
      'fr': [
        'Échauffe-toi sérieusement avant tout sprint (jambes et cardio).',
        'Départ penché vers l’avant, pousse fort dans le sol avec la jambe arrière.',
        'Monte les genoux, foulée puissante, bras qui pompent énergiquement.',
        'Reste relâché du visage et des épaules malgré l’effort maximal.',
      ],
      'en': [
        'Warm up thoroughly before any sprint (legs and cardio).',
        'Lean forward at the start, push hard into the ground with the back leg.',
        'Drive the knees up, powerful stride, arms pumping vigorously.',
        'Stay relaxed in the face and shoulders despite the all-out effort.',
      ],
    },
    cues: const {
      'fr': [
        'Échauffement indispensable : sprinter à froid = risque de claquage.',
        'Pousse dans le sol (propulsion), monte les genoux.',
        'Garde le haut du corps relâché même à fond.',
      ],
      'en': [
        'A warm-up is essential: sprinting cold risks a muscle pull.',
        'Push into the ground (propulsion), drive the knees up.',
        'Keep the upper body relaxed even at full effort.',
      ],
    },
    mistakes: const {
      'fr': [
        'Sprinter sans échauffement (blessure musculaire).',
        'Crispation des épaules qui freine la foulée.',
        'Se redresser trop tôt à l’accélération.',
      ],
      'en': [
        'Sprinting without warming up (muscle injury).',
        'Tense shoulders that slow the stride.',
        'Standing up too early during acceleration.',
      ],
    },
    beginner: const {
      'fr': 'Cours à 70-80 % d’abord (« strides »), augmente l’intensité au fil des séances, et '
          'récupère bien entre les répétitions.',
      'en': 'Run at 70-80% first (“strides”), build the intensity over sessions, and rest fully '
          'between reps.',
    },
  ),

  'row': MovementGuide(
    id: 'row',
    svgAsset: movementSvgAsset('row'),
    name: const {'fr': 'Rameur', 'en': 'Rowing (erg)'},
    steps: const {
      'fr': [
        'Assis, pieds sanglés, attrape la poignée, bras tendus, tibias verticaux (position « catch »).',
        'Pousse fort avec les JAMBES en premier, buste qui suit.',
        'Quand les jambes sont presque tendues, bascule légèrement le buste en arrière puis tire la poignée vers le bas des côtes.',
        'Reviens dans l’ordre inverse : bras, buste, puis jambes.',
      ],
      'en': [
        'Sit with feet strapped in, grab the handle, arms straight, shins vertical (the “catch”).',
        'Push hard with the LEGS first, torso following.',
        'When the legs are nearly straight, lean the torso back slightly then pull the handle to the lower ribs.',
        'Return in reverse order: arms, torso, then legs.',
      ],
    },
    cues: const {
      'fr': [
        'Ordre de la poussée : JAMBES → buste → bras (et l’inverse au retour).',
        '~60 % de la force vient des jambes, pas des bras.',
        'Tire la poignée vers le bas des côtes, coudes près du corps.',
      ],
      'en': [
        'Drive order: LEGS → torso → arms (and the reverse on the return).',
        '~60% of the force comes from the legs, not the arms.',
        'Pull the handle to the lower ribs, elbows close to the body.',
      ],
    },
    mistakes: const {
      'fr': [
        'Tirer avec les bras avant de pousser les jambes.',
        'Dos arrondi pendant la traction.',
        'Se précipiter sur le retour (la « récup » doit être plus lente).',
      ],
      'en': [
        'Pulling with the arms before pushing with the legs.',
        'Rounding the back during the pull.',
        'Rushing the recovery (the return should be slower).',
      ],
    },
    beginner: const {
      'fr': 'Travaille à cadence lente pour sentir l’ordre jambes-buste-bras, puis augmente '
          'l’intensité. Règle le frein (« damper ») autour de 4-6.',
      'en': 'Practise at a slow stroke rate to feel the legs-torso-arms order, then build '
          'intensity. Set the damper around 4-6.',
    },
  ),

  'bike_erg_cal': MovementGuide(
    id: 'bike_erg_cal',
    svgAsset: movementSvgAsset('bike_erg_cal'),
    name: const {'fr': 'BikeErg (vélo)', 'en': 'BikeErg'},
    steps: const {
      'fr': [
        'Règle la hauteur de selle : jambe presque tendue en bas de la pédale.',
        'Assieds-toi, mains sur le guidon, dos relâché mais gainé.',
        'Pédale de façon ronde et régulière en poussant ET tirant si pieds clipsés.',
        'Trouve une cadence et une résistance que tu peux tenir sur la durée.',
      ],
      'en': [
        'Set the seat height: leg nearly straight at the bottom of the pedal stroke.',
        'Sit down, hands on the handlebar, back relaxed but braced.',
        'Pedal smoothly and steadily, pushing AND pulling if your feet are clipped in.',
        'Find a cadence and resistance you can hold over time.',
      ],
    },
    cues: const {
      'fr': [
        'Pédalage rond et fluide, pas saccadé.',
        'Garde le buste stable, ne te dandine pas sur la selle.',
        'Respire en rythme avec ta cadence.',
      ],
      'en': [
        'Smooth, round pedalling, not jerky.',
        'Keep the torso stable, don’t rock on the seat.',
        'Breathe in rhythm with your cadence.',
      ],
    },
    mistakes: const {
      'fr': [
        'Selle mal réglée (genoux trop pliés ou jambe tendue brusquement).',
        'Partir à une cadence intenable.',
        'Se crisper sur le guidon.',
      ],
      'en': [
        'Poorly set seat (knees too bent or leg snapping straight).',
        'Starting at an unsustainable cadence.',
        'Gripping the handlebar too tightly.',
      ],
    },
    beginner: const {
      'fr': 'Commence par une cadence modérée et constante ; vise un rythme régulier plutôt que '
          'des à-coups, et augmente progressivement.',
      'en': 'Start with a moderate, constant cadence; aim for a steady rhythm rather than surges, '
          'and build up gradually.',
    },
  ),

  'assault_bike_cal': MovementGuide(
    id: 'assault_bike_cal',
    svgAsset: movementSvgAsset('assault_bike_cal'),
    name: const {'fr': 'Assault bike (vélo à air)', 'en': 'Assault bike'},
    steps: const {
      'fr': [
        'Règle la selle (jambe presque tendue en bas), assieds-toi, mains sur les poignées mobiles.',
        'Pousse et tire les bras ET pédale en même temps : tout le corps travaille.',
        'Coordonne bras et jambes en rythme régulier.',
        'La résistance augmente avec ton effort : dose ta cadence.',
      ],
      'en': [
        'Set the seat (leg nearly straight at the bottom), sit down, hands on the moving handles.',
        'Push and pull the arms AND pedal at the same time: the whole body works.',
        'Coordinate arms and legs in a steady rhythm.',
        'Resistance rises with your effort: pace your cadence.',
      ],
    },
    cues: const {
      'fr': [
        'Utilise les bras autant que les jambes pour répartir l’effort.',
        'Pars conservateur : l’assault bike « punit » les départs trop rapides.',
        'Respire profondément et régulièrement.',
      ],
      'en': [
        'Use the arms as much as the legs to spread the effort.',
        'Start conservatively: the assault bike “punishes” fast starts.',
        'Breathe deeply and steadily.',
      ],
    },
    mistakes: const {
      'fr': [
        'Partir à fond et exploser cardio en quelques calories.',
        'Ne pas utiliser les bras (tout dans les jambes).',
        'Se crisper sur les poignées.',
      ],
      'en': [
        'Going all-out and gassing out within a few calories.',
        'Not using the arms (all legs).',
        'Tensing up on the handles.',
      ],
    },
    beginner: const {
      'fr': 'Vise une cadence régulière et soutenable ; mieux vaut un rythme constant qu’un '
          'départ explosif suivi d’un effondrement.',
      'en': 'Aim for a steady, sustainable cadence; a constant pace beats an explosive start '
          'followed by a collapse.',
    },
  ),

  'ski_erg_cal': MovementGuide(
    id: 'ski_erg_cal',
    svgAsset: movementSvgAsset('ski_erg_cal'),
    name: const {'fr': 'SkiErg (ski ergomètre)', 'en': 'SkiErg'},
    steps: const {
      'fr': [
        'Debout face à la machine, attrape les deux poignées en haut, bras tendus, gainage actif.',
        'Tire les poignées vers le bas en fléchissant légèrement les hanches et les genoux.',
        'Finis le mouvement mains au niveau des hanches/cuisses, comme un coup de bâtons de ski.',
        'Remonte sous contrôle, bras tendus vers le haut, et recommence.',
      ],
      'en': [
        'Stand facing the machine, grab both handles up high, arms straight, core braced.',
        'Pull the handles down while bending slightly at the hips and knees.',
        'Finish with hands at hip/thigh level, like a double ski-pole plant.',
        'Return under control, arms straight overhead, and repeat.',
      ],
    },
    cues: const {
      'fr': [
        'Le mouvement vient de la charnière de hanche + des bras (pas que des bras).',
        'Gaine le ventre, dos plat à la flexion.',
        'Mouvement fluide et rythmé, pas saccadé.',
      ],
      'en': [
        'The power comes from the hip hinge + arms (not arms alone).',
        'Brace the core, flat back on the hinge.',
        'Smooth, rhythmic motion, not jerky.',
      ],
    },
    mistakes: const {
      'fr': [
        'Tirer uniquement avec les bras (on s’épuise vite).',
        'Dos arrondi pendant la flexion.',
        'Amplitude trop courte (poignées qui ne descendent pas assez).',
      ],
      'en': [
        'Pulling with the arms only (you tire fast).',
        'Rounded back during the hinge.',
        'Too short a range (handles not coming down far enough).',
      ],
    },
    beginner: const {
      'fr': 'Travaille à intensité modérée en sentant la coordination hanches-bras, puis '
          'augmente le rythme une fois le geste fluide.',
      'en': 'Work at moderate intensity to feel the hip-arm coordination, then pick up the pace '
          'once the motion is smooth.',
    },
  ),

  'sled_push': MovementGuide(
    id: 'sled_push',
    svgAsset: movementSvgAsset('sled_push'),
    name: const {'fr': 'Poussée de traîneau (sled push)', 'en': 'Sled push'},
    steps: const {
      'fr': [
        'Place les mains sur les montants du traîneau, bras tendus, corps incliné vers l’avant.',
        'Gaine le ventre, dos plat, tête dans l’alignement.',
        'Pousse fort dans le sol avec les jambes, à petits pas puissants.',
        'Garde un angle bas et constant, avance régulièrement.',
      ],
      'en': [
        'Place your hands on the sled posts, arms straight, body leaning forward.',
        'Brace your core, flat back, head in line.',
        'Push hard into the ground with your legs, in short powerful steps.',
        'Keep a low, constant angle and move steadily.',
      ],
    },
    cues: const {
      'fr': [
        'Incline-toi vers l’avant et pousse avec les jambes, bras tendus.',
        'Dos plat et gainage actif : ne t’effondre pas.',
        'Petits pas puissants plutôt que grandes enjambées.',
      ],
      'en': [
        'Lean forward and push with the legs, arms straight.',
        'Flat back and active core: don’t collapse.',
        'Short powerful steps rather than long strides.',
      ],
    },
    mistakes: const {
      'fr': [
        'Bras pliés qui absorbent la force (au lieu des jambes).',
        'Dos arrondi sous l’effort.',
        'Buste trop redressé (perte de poussée).',
      ],
      'en': [
        'Bent arms absorbing the force (instead of the legs).',
        'Rounded back under load.',
        'Torso too upright (loss of drive).',
      ],
    },
    beginner: const {
      'fr': 'Allège le traîneau (moins de charge) et travaille sur de courtes distances ; '
          'l’important est de garder une bonne posture sous l’effort.',
      'en': 'Lighten the sled (less load) and work over short distances; the key is keeping good '
          'posture under effort.',
    },
  ),

  'farmers_carry': MovementGuide(
    id: 'farmers_carry',
    svgAsset: movementSvgAsset('farmers_carry'),
    name: const {'fr': 'Marche du fermier (farmers carry)', 'en': 'Farmer’s carry'},
    steps: const {
      'fr': [
        'Une charge lourde dans chaque main (kettlebells, haltères ou poignées dédiées) le long du corps.',
        'Tiens-toi droit : poitrine haute, épaules en arrière, gainage actif.',
        'Marche d’un pas régulier et contrôlé, sans te pencher d’un côté.',
        'Garde une prise ferme et une respiration régulière sur toute la distance.',
      ],
      'en': [
        'A heavy load in each hand (kettlebells, dumbbells or dedicated handles) at your sides.',
        'Stand tall: chest up, shoulders back, core braced.',
        'Walk with a steady, controlled stride, without leaning to one side.',
        'Keep a firm grip and steady breathing over the whole distance.',
      ],
    },
    cues: const {
      'fr': [
        'Reste bien droit, épaules en arrière, ne te voûte pas.',
        'Gaine le ventre pour rester stable.',
        'Pas réguliers, ne cours pas.',
      ],
      'en': [
        'Stay upright, shoulders back, don’t hunch.',
        'Brace the core to stay stable.',
        'Steady steps, don’t run.',
      ],
    },
    mistakes: const {
      'fr': [
        'S’avachir vers l’avant ou pencher d’un côté.',
        'Charge trop lourde qui ruine la posture.',
        'Bloquer la respiration.',
      ],
      'en': [
        'Slumping forward or leaning to one side.',
        'Load too heavy, wrecking the posture.',
        'Holding your breath.',
      ],
    },
    beginner: const {
      'fr': 'Commence avec une charge modérée sur de courtes distances, en priorité une posture '
          'droite ; augmente le poids progressivement.',
      'en': 'Start with a moderate load over short distances, prioritising an upright posture; '
          'add weight gradually.',
    },
  ),
};
