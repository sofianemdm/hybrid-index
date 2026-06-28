import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Pastille de GRADE (« 70+ », « 100 ») calée sur l'OVR. Remplace les rangs médailles.
/// Si `ovr` est fourni → grade ; sinon repli sur l'ancien libellé de rang (compat).
class RankBadge extends StatelessWidget {
  final String rank;
  final int? ovr;
  final double fontSize;
  const RankBadge({super.key, this.rank = 'rookie', this.ovr, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final bool grade = ovr != null;
    final color = grade ? HiGrade.color(ovr!) : HiColors.rank(rank);
    final label = grade ? HiGrade.label(ovr!) : HiLabels.rank(rank).toUpperCase();
    // a11y : énoncé explicite (« grade 70+ » / « rang Or ») plutôt que le texte brut « 70+ ».
    final semanticLabel = grade ? 'Grade ${HiGrade.label(ovr!)}' : 'Rang ${HiLabels.rank(rank)}';
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: _badge(color, label, grade)),
    );
  }

  Widget _badge(Color color, String label, bool grade) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(HiRadius.pill),
        border: Border.all(color: color.withValues(alpha: grade ? 0.9 : 0.5), width: grade ? 1.4 : 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: fontSize, letterSpacing: 0.5),
      ),
    );
  }
}
