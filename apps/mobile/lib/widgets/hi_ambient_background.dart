import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Fond ambiant « signé » (audit design 03/07) : dégradé radial très subtil du bleu nuit
/// [HiColors.bgAmbient] (centre-haut) vers [HiColors.bgBase] (bords), plus, en option, un halo
/// cyan diffus (~6 %) derrière la zone héros. Statique (aucune animation) → profondeur perçue
/// immédiate, coût de rendu nul. À placer AUTOUR d'un Scaffold rendu transparent.
class HiAmbientBackground extends StatelessWidget {
  const HiAmbientBackground({super.key, required this.child, this.heroHalo = false});

  final Widget child;

  /// Halo cyan diffus derrière le tiers haut de l'écran (accueil, reveal).
  final bool heroHalo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.9),
                radius: 1.4,
                colors: [HiColors.bgAmbient, HiColors.bgBase],
              ),
            ),
          ),
        ),
        if (heroHalo)
          // Halo décoratif : jamais interactif, jamais annoncé par le lecteur d'écran.
          Positioned(
            top: -140,
            left: -60,
            right: -60,
            height: 380,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        HiColors.brandPrimary.withValues(alpha: 0.06),
                        HiColors.brandPrimary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
