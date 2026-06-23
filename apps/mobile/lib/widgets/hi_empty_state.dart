import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'hi_button.dart';

/// État vide designé : icône cerclée + titre + sous-titre + (optionnel) CTA. Un vide n'est jamais
/// un cul-de-sac — on propose toujours une action quand c'est pertinent.
class HiEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  const HiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: HiColors.bgElevated2,
                shape: BoxShape.circle,
                border: Border.all(color: HiColors.strokeSubtle),
              ),
              child: Icon(icon, color: HiColors.textTertiary, size: 44),
            ),
            const SizedBox(height: HiSpace.lg),
            Text(title, textAlign: TextAlign.center, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
            const SizedBox(height: HiSpace.sm),
            Text(message, textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: HiSpace.lg),
              SizedBox(width: 260, child: HiButton(label: ctaLabel!, icon: ctaIcon, onPressed: onCta)),
            ],
          ],
        ),
      ),
    );
  }
}
