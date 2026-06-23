import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_card.dart';

/// Carte « rival amical » : l'athlète juste au-dessus dans la ligue. Ton TOUJOURS bienveillant
/// et motivant — jamais de honte. Si [rival] est null (leader), affiche l'état meneur.
class RivalCard extends StatelessWidget {
  final Rival? rival;
  final int? leaguePosition;
  final VoidCallback onTap;
  const RivalCard({super.key, required this.rival, required this.leaguePosition, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLeader = rival == null && leaguePosition == 1;
    return HiHeroCard(
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HiColors.brandSecondary.withValues(alpha: 0.16),
          HiColors.brandPrimary.withValues(alpha: 0.08),
        ],
      ),
      child: isLeader ? _leader() : _chasing(rival!),
    );
  }

  Widget _chasing(Rival r) {
    return Row(
      children: [
        _avatarBubble(Icons.sports_mma_rounded, HiColors.brandSecondaryText),
        const SizedBox(width: HiSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TU POURSUIS', style: HiType.overline.copyWith(color: HiColors.brandSecondaryText)),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: HiType.titleM.copyWith(color: HiColors.textPrimary),
                  children: [
                    TextSpan(text: r.displayName, style: TextStyle(color: HiColors.brandPrimary)),
                    TextSpan(text: '  ·  ${r.ovr}', style: HiType.numericM.copyWith(color: HiColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                r.gapPoints <= 1
                    ? 'Plus qu\'1 point pour le rattraper 👊'
                    : 'Plus que ${r.gapPoints} points pour le rattraper 👊',
                style: HiType.caption.copyWith(color: HiColors.textSecondary),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
      ],
    );
  }

  Widget _leader() {
    return Row(
      children: [
        _avatarBubble(Icons.workspace_premium_rounded, HiColors.accentVictory),
        const SizedBox(width: HiSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEADER DE TA LIGUE', style: HiType.overline.copyWith(color: HiColors.accentVictory)),
              const SizedBox(height: 4),
              Text('Tu es en tête 👑', style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Défends ta place — bats ton propre record.',
                  style: HiType.caption.copyWith(color: HiColors.textSecondary)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
      ],
    );
  }

  Widget _avatarBubble(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
