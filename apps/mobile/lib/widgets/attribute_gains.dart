import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// Feedback de compétence : « +X sur tel attribut », avec mise en avant du point faible.
/// Le levier le mieux établi (compétence + feedback) ; honnête : deltas réels (no-drop ⇒ ≥ 0).
class AttributeGains extends StatelessWidget {
  final List<AttributeGain> gains;
  final String? weakest;
  const AttributeGains({super.key, required this.gains, this.weakest});

  @override
  Widget build(BuildContext context) {
    if (gains.isEmpty) {
      return Text(
        'Pas de nouveau record cette fois — mais chaque séance compte pour ta régularité.',
        textAlign: TextAlign.center,
        style: TextStyle(color: HiColors.textSecondary, fontSize: 14),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: gains.map((g) {
        final isWeak = g.attribute == weakest;
        final color = HiColors.attribute(g.attribute);
        // a11y : une ligne = un message clair (« +X en Cardio, ton point faible »).
        final semanticLabel = '+${g.delta} en ${HiLabels.attribute(g.attribute)}'
            '${isWeak ? ', ton point faible' : ''}';
        return Semantics(
          label: semanticLabel,
          child: ExcludeSemantics(
            child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_up, color: color, size: 18),
              const SizedBox(width: 6),
              // Texte en couleur lisible (textPrimary) ; la couleur d'attribut reste portée par l'icône
              // ET le libellé → l'info n'est jamais codée par la seule couleur (WCAG 1.4.1).
              Text('+${g.delta}',
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 6),
              Text(HiLabels.attribute(g.attribute),
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
              if (isWeak) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                  ),
                  child: Text('🎯 ton point faible',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
