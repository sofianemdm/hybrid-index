import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_card.dart';

/// Carte « Ta semaine » — récap non compétitif, toujours valorisant. Affichée seulement s'il y a
/// quelque chose à montrer (au moins une séance ou un gain d'Index cette semaine).
class WeeklyRecapCard extends StatelessWidget {
  final WeeklyRecap recap;
  const WeeklyRecapCard({super.key, required this.recap});

  @override
  Widget build(BuildContext context) {
    return HiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: HiColors.brandPrimary, size: 16),
              const SizedBox(width: HiSpace.sm),
              Text('TA SEMAINE', style: HiType.overline.copyWith(color: HiColors.textSecondary)),
              const Spacer(),
              if (recap.weekValidated)
                Text('validée ✅', style: HiType.caption.copyWith(color: HiColors.success)),
            ],
          ),
          const SizedBox(height: HiSpace.md),
          Row(
            children: [
              _stat('${recap.sessions}', recap.sessions > 1 ? 'séances' : 'séance', HiColors.brandPrimary),
              _divider(),
              _stat(recap.deltaIndex > 0 ? '+${recap.deltaIndex}' : '—', 'points d\'Index', HiColors.success),
              _divider(),
              _stat('${recap.streakCurrent}', recap.streakCurrent > 1 ? 'semaines 🔥' : 'semaine 🔥',
                  HiColors.streakFlame),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          Text(_message(), style: HiType.caption.copyWith(color: HiColors.textSecondary)),
        ],
      ),
    );
  }

  String _message() {
    if (recap.deltaIndex > 0 && recap.sessions > 0) {
      return 'Belle semaine — ton travail paye, +${recap.deltaIndex} sur ton Index.';
    }
    if (recap.sessions > 0) return 'Bien joué, continue sur ta lancée.';
    return 'Une séance suffit pour lancer la semaine.';
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: HiType.numericL.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: HiColors.strokeSubtle);
}
