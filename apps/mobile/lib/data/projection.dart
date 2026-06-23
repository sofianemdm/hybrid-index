import 'models.dart';

/// Projection motivante : à quand le prochain palier de 10 (80+, 90+…) au rythme RÉCENT.
class IndexProjection {
  final int targetGrade; // ex. 80 (= « 80+ »)
  final int weeks; // ~semaines pour l'atteindre
  const IndexProjection(this.targetGrade, this.weeks);
}

/// Estime quand l'utilisateur atteindra le prochain palier de 10 à partir de la pente de son
/// historique d'Index sur ~8 semaines. Pur (testable). Retourne null si données insuffisantes,
/// pente nulle/négative, ou horizon non plausible (> 1 an).
IndexProjection? projectIndex(List<IndexPoint> history, int currentOvr) {
  if (currentOvr >= 100) return null;
  if (history.length < 2) return null;
  final now = history.last.at;
  final recent = history.where((p) => now.difference(p.at).inDays <= 56).toList();
  if (recent.length < 2) return null;
  final first = recent.first;
  final last = recent.last;
  final days = last.at.difference(first.at).inDays;
  if (days < 5) return null; // tendance trop courte pour être fiable
  final delta = last.value - first.value;
  if (delta <= 0) return null; // pas de progression récente → pas de fausse promesse
  final perWeek = delta / (days / 7.0);
  final nextGrade = ((currentOvr ~/ 10) + 1) * 10;
  final pointsNeeded = nextGrade - currentOvr;
  if (pointsNeeded <= 0) return null;
  final weeks = (pointsNeeded / perWeek).ceil();
  if (weeks < 1 || weeks > 52) return null;
  return IndexProjection(nextGrade, weeks);
}
