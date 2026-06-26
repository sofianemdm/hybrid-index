/// Glossaire du jargon d'entraînement (CrossFit / HYROX / hybride) → définition FR simple,
/// pensée pour un débutant. Utilisé par `GlossaryText` : ces termes deviennent tappables
/// (ℹ️ → définition) partout où ils apparaissent dans une description de séance/épreuve.
///
/// Clés en MINUSCULES (la détection est insensible à la casse). Termes volontairement « jargon » :
/// on évite les mots trop courants (« force », « échelle ») qui pollueraient le texte.
const Map<String, String> kGlossary = {
  'rx': 'En CrossFit, « Rx » (as prescribed) = la séance faite avec les charges et mouvements '
      'officiels, sans adaptation. À l\'inverse d\'une version allégée.',
  'scaled': 'Version allégée d\'une épreuve : charges réduites ou mouvements adaptés pour rester '
      'réalisable tout en gardant l\'esprit de la séance.',
  'allégé': 'Version adaptée d\'une épreuve : charges plus légères ou mouvements simplifiés.',
  'for time': '« Pour le temps » : tu réalises tout le travail demandé le plus vite possible. '
      'Ton score est le chrono total.',
  'pour le temps': 'Tu réalises tout le travail demandé le plus vite possible ; ton score est le '
      'chrono total.',
  'amrap': '« As Many Rounds/Reps As Possible » : faire un MAXIMUM de tours ou de répétitions dans '
      'un temps imparti (ex. AMRAP 12 min).',
  'emom': '« Every Minute On the Minute » : au top de chaque minute tu fais le travail prévu, puis '
      'tu récupères le temps restant de la minute.',
  'tabata': 'Format court et très intense : 8 cycles de 20 s d\'effort / 10 s de repos (4 min en '
      'tout) sur un même mouvement.',
  'chipper': 'Une longue liste de mouvements à « grignoter » : on les enchaîne une seule fois, du '
      'premier au dernier.',
  'intervalles': 'Alternance d\'efforts intenses et de récupérations (ex. 30 s vite / 30 s lent), '
      'répétée plusieurs fois.',
  'metcon': '« Metabolic Conditioning » : un circuit cardio-musculaire court et intense, typique du '
      'CrossFit.',
  'wod': '« Workout Of the Day » : la séance / l\'épreuve du jour.',
  'hyrox': 'Épreuve hybride en salle : 8 km de course entrecoupés de 8 ateliers de force et '
      'd\'endurance (rameur, traîneau, wall balls…).',
  'ligue du mois': 'Mode mensuel optionnel : un classement par points qui se réinitialise chaque '
      'mois. Ton Athlete Index permanent, lui, ne baisse jamais.',
};
