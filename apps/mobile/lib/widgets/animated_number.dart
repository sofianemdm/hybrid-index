import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Chiffre animé : compte de [from] (ou de la valeur précédente) vers [value] avec figures
/// tabulaires (pas de saut). À utiliser pour l'Index, les notes de WOD, le #rang.
class AnimatedNumber extends StatelessWidget {
  final num value;
  final num? from;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int decimals;
  final String prefix;
  final String suffix;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.from,
    this.style,
    this.duration = HiMotion.reveal,
    this.curve = HiMotion.countUp,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: (from ?? value).toDouble(), end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, v, _) {
        final txt = decimals == 0 ? v.round().toString() : v.toStringAsFixed(decimals);
        return Text('$prefix$txt$suffix', style: style);
      },
    );
  }
}
