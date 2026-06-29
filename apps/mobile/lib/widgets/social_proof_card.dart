import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Preuve sociale à deux populations.
/// Ligne 1 (TOUJOURS) = humanité, valorisante. Ligne 2 (si éligible) = rang dans l'app.
class SocialProofCard extends StatelessWidget {
  final SocialProof proof;
  const SocialProofCard({super.key, required this.proof});

  @override
  Widget build(BuildContext context) {
    final appVisible = proof.appVisible && proof.appTopPercent != null;
    return MergeSemantics(
      child: Semantics(
        label: _a11yLabel(context, appVisible),
        container: true,
        child: ExcludeSemantics(
          child: Container(
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
                _humanityLine(context),
                if (appVisible) ...[
                  const SizedBox(height: HiSpace.sm),
                  Divider(height: 1, color: HiColors.strokeSubtle),
                  const SizedBox(height: HiSpace.sm),
                  _appLine(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Résumé lu d'un trait par le lecteur d'écran : ligne humanité (+ ligne app si visible).
  String _a11yLabel(BuildContext context, bool appVisible) {
    final t = AppLocalizations.of(context);
    final top = proof.humanityTopPercent;
    final String humanity = top == null
        ? t.socialProofBases
        : top <= 1
            ? t.socialProofElite
            : '${t.socialProofTopPrefix}$top%${t.socialProofTopSuffix}';
    if (!appVisible) return t.socialProofA11yHumanity(humanity);
    final app = '${t.socialProofAppPrefix}${proof.appTopPercent}%${t.socialProofAppSuffix}';
    return t.socialProofA11yHumanityApp(humanity, app);
  }

  Widget _humanityLine(BuildContext context) {
    final t = AppLocalizations.of(context);
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
                  t.socialProofBases,
                  style: HiType.body.copyWith(color: HiColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                )
              : top <= 1
                  // Tout en haut : on célèbre, sans surenchère « des humains ».
                  ? Text(
                      t.socialProofElite,
                      style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary, height: 1.3),
                    )
                  : RichText(
                      text: TextSpan(
                        style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary, height: 1.3),
                        children: [
                          TextSpan(text: t.socialProofTopPrefix),
                          TextSpan(text: '$top%', style: TextStyle(color: HiColors.brandPrimary)),
                          TextSpan(text: t.socialProofTopSuffix),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _appLine(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.bolt, color: HiColors.brandSecondaryText, size: 18),
        const SizedBox(width: HiSpace.sm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: HiType.body.copyWith(color: HiColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: t.socialProofAppPrefix),
                TextSpan(text: '${proof.appTopPercent}%', style: TextStyle(color: HiColors.brandSecondaryText, fontWeight: FontWeight.w700)),
                TextSpan(text: t.socialProofAppSuffix),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
