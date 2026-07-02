/// Associe un libellé de mouvement (tel qu'affiché dans les blocs d'une séance) à une image
/// d'explication (assets/movements/). Sert à afficher une icône d'info tappable à côté des
/// mouvements pour lesquels on dispose d'un guide visuel.
///
/// Robuste aux pluriels, à la casse, aux accents et au mélange FR/EN
/// (ex. « Épaulé-jeté » = clean & jerk, « Relevés de jambes à la barre » = toes-to-bar).
library;

const String _base = 'assets/movements/';

/// Chemin de l'image explicative pour un libellé de mouvement, ou `null` si aucun guide.
String? movementGuideAsset(String movementLabel) {
  final s = _normalize(movementLabel);
  // Composés/spécifiques d'abord (« wall ball » vs « wall walk »).
  if (s.contains('wall walk')) return '${_base}wall_walk.jpg';
  if (s.contains('wall ball')) return '${_base}wall_ball.jpg';
  if (s.contains('thruster')) return '${_base}thruster.jpg';
  if (s.contains('snatch') || s.contains('arrach')) return '${_base}snatch.jpg';
  if (s.contains('epaule') || (s.contains('clean') && s.contains('jerk'))) {
    return '${_base}clean_and_jerk.jpg';
  }
  if (s.contains('kettlebell') || s.contains('swing')) return '${_base}kettlebell_swing.jpg';
  if (s.contains('releves de jambes') || s.contains('toes')) return '${_base}toes_to_bar.jpg';
  // « burpee » mais PAS « burpee broad jump » (mouvement différent, non illustré).
  if (s.contains('burpee') && !s.contains('broad')) return '${_base}burpee.jpg';
  return null;
}

/// minuscule + suppression des accents + tirets/underscores → espaces + espaces simples.
String _normalize(String s) {
  const from = 'àâäáãéèêëíìîïóòôöõúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final lower = s.toLowerCase().trim();
  final sb = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    sb.write(i >= 0 ? to[i] : ch);
  }
  return sb
      .toString()
      .replaceAll(RegExp(r'[-_]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
