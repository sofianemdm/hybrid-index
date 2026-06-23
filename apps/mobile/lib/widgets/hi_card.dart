import 'package:flutter/material.dart';
import '../theme/haptics.dart';
import '../theme/tokens.dart';

/// Enveloppe tappable avec micro-scale au press (0.97) — feel premium pour tout élément
/// interactif. Déclenche un tap haptique léger.
class HiPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  const HiPressable({super.key, required this.child, this.onTap, this.pressedScale = 0.97, this.haptic = true});

  @override
  State<HiPressable> createState() => _HiPressableState();
}

class _HiPressableState extends State<HiPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HiHaptics.tap();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: HiMotion.instant,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Carte standard : fond élevé, bordure subtile, rayon carte, ombre e1.
class HiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const HiCard({super.key, required this.child, this.padding = const EdgeInsets.all(HiSpace.md), this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.lg),
        border: Border.all(color: HiColors.strokeSubtle),
        boxShadow: HiShadow.e1,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return HiPressable(onTap: onTap, pressedScale: 0.99, child: card);
  }
}

/// Carte héros : point focal d'un écran (Index, ligue, reveal). Bordure marque, rayon héros,
/// ombre e2 + halo cyan léger. Accepte un dégradé de fond optionnel.
class HiHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final VoidCallback? onTap;
  const HiHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HiSpace.lg),
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? HiColors.bgElevated : null,
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HiColors.bgElevated, HiColors.bgElevated2],
            ),
        borderRadius: BorderRadius.circular(HiRadius.xl),
        border: Border.all(color: HiColors.strokeBrand, width: 1.5),
        boxShadow: [...HiShadow.e2, ...HiShadow.glowBrand(0.18)],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return HiPressable(onTap: onTap, pressedScale: 0.99, child: card);
  }
}
