import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Bloc squelette avec shimmer qui traverse (L→R). Remplace les spinners pour préserver le
/// layout pendant le chargement → sensation premium et perçue plus rapide.
class HiSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const HiSkeleton({super.key, this.width = double.infinity, required this.height, this.radius = HiRadius.sm});

  /// Cercle (anneau d'Index, avatar).
  const HiSkeleton.circle(double size, {super.key})
      : width = size,
        height = size,
        radius = 999;

  @override
  State<HiSkeleton> createState() => _HiSkeletonState();
}

class _HiSkeletonState extends State<HiSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value; // 0..1
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2 - 0.6, 0),
              end: Alignment(-1 + t * 2 + 0.6, 0),
              colors: [HiColors.bgElevated2, HiColors.bgElevatedHi, HiColors.bgElevated2],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Squelette de l'accueil — épouse la forme RÉELLE du contenu : carte joueur héros (grand
/// rectangle arrondi, pas un cercle), puis chips et bloc radar. Évite le saut de layout au reveal.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: HiSpace.lg),
            // Carte joueur héros : grand rectangle arrondi (≈ ratio de la PlayerCard).
            HiSkeleton(height: 300, radius: HiRadius.xl),
            SizedBox(height: HiSpace.lg),
            // Chip rival / projection.
            HiSkeleton(height: 64, radius: HiRadius.lg),
            SizedBox(height: HiSpace.md),
            // Bloc radar.
            HiSkeleton(height: 240, radius: HiRadius.lg),
          ],
        ),
      ),
    );
  }
}
