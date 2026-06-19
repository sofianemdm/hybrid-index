import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Pastille de rang : couleur du rang + libellé FR (jamais la couleur seule).
class RankBadge extends StatelessWidget {
  final String rank;
  final double fontSize;
  const RankBadge({super.key, required this.rank, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final color = HiColors.rank(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(HiRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield, size: fontSize + 2, color: color),
          const SizedBox(width: 5),
          Text(
            HiLabels.rank(rank).toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: fontSize, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
