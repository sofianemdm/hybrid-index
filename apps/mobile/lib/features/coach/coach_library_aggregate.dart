import '../../data/models.dart';

/// Agrégation pure du filtre « Tout » de la bibliothèque de séances.
///
/// L'API `/v1/coach/library?attribute=…` renvoie les séances par axe ; une même séance peut
/// remonter sur plusieurs axes. Le filtre « Tout » interroge les 6 axes puis fusionne les listes :
/// déduplication par `id` (première occurrence conservée) puis tri stable durée croissante, puis nom.
/// Logique extraite ici pour être testable sans widget ni réseau.
List<CoachSession> aggregateAllSessions(List<List<CoachSession>> perAxis) {
  final byId = <String, CoachSession>{};
  for (final list in perAxis) {
    for (final s in list) {
      byId.putIfAbsent(s.id, () => s);
    }
  }
  final all = byId.values.toList()
    ..sort((a, b) {
      final d = a.durationMin.compareTo(b.durationMin);
      return d != 0 ? d : a.name.compareTo(b.name);
    });
  return all;
}
