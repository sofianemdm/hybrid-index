import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// Preuve sociale à deux populations.
/// Ligne 1 (TOUJOURS) = humanité, valorisante. Ligne 2 (si éligible) = rang dans l'app.
class SocialProofCard extends StatelessWidget {
  final SocialProof proof;
  const SocialProofCard({super.key, required this.proof});

  @override
  Widget build(BuildContext context) {
    final appVisible = proof.appVisible && proof.appTopPercent != null;
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(
          color: HiColors.brandPrimary.withValues(alpha: appVisible ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _humanityLine(),
          if (appVisible) ...[
            const SizedBox(height: HiSpace.sm),
            Divider(height: 1, color: HiColors.strokeSubtle),
            const SizedBox(height: HiSpace.sm),
            _appLine(),
          ],
        ],
      ),
    );
  }

  Widget _humanityLine() {
    final top = proof.humanityTopPercent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.public, color: HiColors.brandPrimary, size: 22),
        const SizedBox(width: HiSpace.sm),
        Expanded(
          child: top == null
              // Sous la médiane : jamais dévalorisant, formulé en progression.
              ? Text(
                  'Tu poses tes bases — chaque séance te rapproche du haut du classement.',
                  style: TextStyle(color: HiColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                )
              : top <= 1
                  // Tout en haut : on célèbre, sans surenchère « des humains ».
                  ? Text(
                      '🔥 Tu es dans l\'élite — tout en haut des plus performants.',
                      style: TextStyle(color: HiColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
                    )
                  : RichText(
                      text: TextSpan(
                        style: TextStyle(color: HiColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
                        children: [
                          const TextSpan(text: 'Tu fais partie des '),
                          TextSpan(text: '$top%', style: TextStyle(color: HiColors.brandPrimary)),
                          const TextSpan(text: ' les plus en forme'),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _appLine() {
    return Row(
      children: [
        Icon(Icons.bolt, color: HiColors.brandSecondaryText, size: 18),
        const SizedBox(width: HiSpace.sm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: HiColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
              children: [
                const TextSpan(text: 'Top '),
                TextSpan(text: '${proof.appTopPercent}%', style: TextStyle(color: HiColors.brandSecondaryText, fontWeight: FontWeight.w700)),
                const TextSpan(text: ' des athlètes HYBRID'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
