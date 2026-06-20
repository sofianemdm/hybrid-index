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
            const Divider(height: 1, color: HiColors.strokeSubtle),
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
        const Icon(Icons.public, color: HiColors.brandPrimary, size: 22),
        const SizedBox(width: HiSpace.sm),
        Expanded(
          child: top == null
              // Sous la médiane : jamais dévalorisant, formulé en progression.
              ? const Text(
                  'Tu poses tes bases — chaque WOD te rapproche du haut du classement mondial.',
                  style: TextStyle(color: HiColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                )
              : RichText(
                  text: TextSpan(
                    style: const TextStyle(color: HiColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
                    children: [
                      const TextSpan(text: 'Tu fais partie des '),
                      TextSpan(text: '$top%', style: const TextStyle(color: HiColors.brandPrimary)),
                      const TextSpan(text: ' des humains les plus en forme'),
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
        const Icon(Icons.bolt, color: HiColors.brandSecondary, size: 18),
        const SizedBox(width: HiSpace.sm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: HiColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              children: [
                const TextSpan(text: 'Top '),
                TextSpan(text: '${proof.appTopPercent}%', style: const TextStyle(color: HiColors.brandSecondary, fontWeight: FontWeight.w700)),
                const TextSpan(text: ' des athlètes HYBRID'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
