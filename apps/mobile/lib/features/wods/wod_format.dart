/// WODs comptés en TOURS (AMRAP de tours) plutôt qu'en répétitions : l'unité affichée et saisie est
/// « tours », pas « reps ». Le scoreType reste 'reps' côté moteur (dir +1, plus haut = mieux), seule
/// l'UNITÉ d'affichage change. Aujourd'hui seul Cindy (5 tractions + 10 pompes + 15 air squats / tour).
const Set<String> kRoundWods = {'cindy'};

/// Formatage d'un résultat de séance selon son type de score (et l'unité « tours » par WOD).
/// Les temps ≥ 1 h s'affichent en h:mm:ss (ex. marathon 4:30:00), sinon m:ss.
String formatWodResult(num value, String scoreType, {String? wodId}) {
  if (wodId != null && kRoundWods.contains(wodId)) return '${value.round()} tours';
  if (scoreType == 'time') return formatDuration(value.round());
  if (scoreType == 'load') return '${value.round()} kg';
  if (scoreType == 'distance') return '${value.round()} m';
  return '${value.round()} reps';
}

/// Libellé d'unité d'un WOD pour la SAISIE / les en-têtes (« tours », « reps », « kg », « m »).
/// Pour les WODs chronométrés, renvoie '' (le résultat est un temps m:ss, pas une unité comptée).
String wodUnitLabel(String? wodId, String scoreType) {
  if (wodId != null && kRoundWods.contains(wodId)) return 'tours';
  switch (scoreType) {
    case 'time':
      return '';
    case 'load':
      return 'kg';
    case 'distance':
      return 'm';
    default:
      return 'reps';
  }
}

/// Durée en secondes → « h:mm:ss » (≥ 1 h) ou « m:ss ».
String formatDuration(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  return '$m:${sec.toString().padLeft(2, '0')}';
}
