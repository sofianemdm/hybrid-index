/// Formatage d'un résultat de WOD selon son type de score.
String formatWodResult(num value, String scoreType) {
  if (scoreType == 'time') {
    final s = value.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
  if (scoreType == 'load') return '${value.round()} kg';
  if (scoreType == 'distance') return '${value.round()} m';
  return '${value.round()} reps';
}
