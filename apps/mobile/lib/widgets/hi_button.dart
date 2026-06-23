import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'hi_card.dart';

/// Bouton héro : gradient « métal cyan » + glow + micro-scale au press. Spinner si `loading`.
/// Icône optionnelle. C'est le CTA primaire (un seul par écran de repos).
class HiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const HiButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return HiPressable(
      onTap: enabled ? onPressed : null,
      pressedScale: 0.96,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: HiColors.brandGradient,
            borderRadius: BorderRadius.circular(HiRadius.md),
            boxShadow: enabled ? HiShadow.glowBrand(0.28) : null,
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: HiColors.textOnBrand),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: HiColors.textOnBrand, size: 20),
                      const SizedBox(width: HiSpace.sm),
                    ],
                    Text(label, style: HiType.button.copyWith(color: HiColors.textOnBrand)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Bouton secondaire : fond élevé, contour, micro-scale au press. Icône optionnelle.
class HiButtonSecondary extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const HiButtonSecondary({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return HiPressable(
      onTap: onPressed,
      pressedScale: 0.97,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HiColors.bgElevated,
            borderRadius: BorderRadius.circular(HiRadius.md),
            border: Border.all(color: HiColors.strokeStrong, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: HiColors.brandPrimary, size: 20),
                const SizedBox(width: HiSpace.sm),
              ],
              Text(label, style: HiType.button.copyWith(color: HiColors.textPrimary, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton fantôme : pas de fond ni bordure, texte marque. Actions discrètes (historique, partage).
class HiGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const HiGhostButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return HiPressable(
      onTap: onPressed,
      pressedScale: 0.96,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HiSpace.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: HiColors.brandPrimary, size: 18),
                const SizedBox(width: 6),
              ],
              Text(label, style: HiType.label.copyWith(color: HiColors.brandPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
