/// Formatage d'un résultat de séance selon son type de score.
/// Les temps ≥ 1 h s'affichent en h:mm:ss (ex. marathon 4:30:00), sinon m:ss.
String formatWodResult(num value, String scoreType) {
  if (scoreType == 'time') return formatDuration(value.round());
  if (scoreType == 'load') return '${value.round()} kg';
  if (scoreType == 'distance') return '${value.round()} m';
  return '${value.round()} reps';
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
