import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/haptics.dart';
import '../theme/tokens.dart';
import 'hi_button.dart';

/// Intensité d'une célébration (règle anti-fatigue : une seule « forte » par session).
enum CelebrationIntensity { light, medium, strong }

/// Moment de dopabine plein écran : titre, sous-titre, icône/valeur, burst de confettis.
/// Auto-fermeture après ~2.6 s ou au tap. Conçu pour être appelé en une ligne :
/// `Celebration.show(context, title: 'Nouveau record 🔥', subtitle: '...', intensity: ...)`.
class Celebration {
  Celebration._();

  static bool _strongShownThisSession = false;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? value,
    IconData? icon,
    Color? accent,
    CelebrationIntensity intensity = CelebrationIntensity.medium,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    // Anti-fatigue : on rétrograde une 2e « forte » de la session en « moyenne ».
    var eff = intensity;
    if (eff == CelebrationIntensity.strong && _strongShownThisSession) {
      eff = CelebrationIntensity.medium;
    }
    if (eff == CelebrationIntensity.strong) _strongShownThisSession = true;

    // Légère : pas de plein écran, juste haptique (le caller affichera un accent inline).
    if (eff == CelebrationIntensity.light) {
      HiHaptics.success();
      return;
    }

    HiHaptics.celebrate();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: HiMotion.base,
      pageBuilder: (ctx, _, __) => _CelebrationView(
        title: title,
        subtitle: subtitle,
        value: value,
        icon: icon,
        accent: accent ?? (eff == CelebrationIntensity.strong ? HiColors.accentVictory : HiColors.brandPrimary),
        strong: eff == CelebrationIntensity.strong,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
    );
  }

  /// À appeler au démarrage d'une session si on veut autoriser une nouvelle « forte ».
  static void resetSession() => _strongShownThisSession = false;
}

class _CelebrationView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final Color accent;
  final bool strong;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _CelebrationView({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.accent,
    required this.strong,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView> with TickerProviderStateMixin {
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: HiMotion.celebrate);
  late List<_Particle> _particles = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduce-motion : pas de confettis ni d'effet « pop » — la carte s'affiche directement.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pop.value = 1.0;
    } else {
      _particles = _buildParticles(widget.strong ? 80 : 44);
      _confetti.forward();
      _pop.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-fermeture — sauf si une action (ex. Partager) est proposée : on laisse l'utilisateur choisir.
    if (widget.actionLabel == null) {
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pop.dispose();
    super.dispose();
  }

  List<_Particle> _buildParticles(int n) {
    final rnd = math.Random(n * 7 + widget.title.length);
    final palette = [HiColors.brandPrimary, HiColors.brandSecondary, HiColors.accentVictory, HiColors.brandPrimaryBright];
    return List.generate(n, (i) {
      final angle = rnd.nextDouble() * math.pi * 2;
      return _Particle(
        angle: angle,
        speed: 0.35 + rnd.nextDouble() * 0.65,
        color: palette[rnd.nextInt(palette.length)],
        size: 5 + rnd.nextDouble() * 7,
        rot: rnd.nextDouble() * math.pi,
        rotSpeed: (rnd.nextDouble() - 0.5) * 6,
        drift: (rnd.nextDouble() - 0.5) * 0.4,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned.fill(
            // Confettis purement décoratifs → exclus du lecteur d'écran.
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (_, __) =>
                      CustomPaint(painter: _ConfettiPainter(_particles, Curves.easeOut.transform(_confetti.value))),
                ),
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _pop, curve: HiMotion.emphasis),
              child: Container(
                margin: const EdgeInsets.all(HiSpace.xl),
                padding: const EdgeInsets.symmetric(horizontal: HiSpace.xl, vertical: HiSpace.xl),
                decoration: BoxDecoration(
                  color: HiColors.bgElevated,
                  borderRadius: BorderRadius.circular(HiRadius.xl),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: widget.strong ? HiShadow.glowVictory() : HiShadow.glowBrand(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.value != null)
                      Text(widget.value!, style: HiType.displayL.copyWith(color: widget.accent))
                    else
                      Icon(widget.icon ?? Icons.celebration_rounded, color: widget.accent, size: 56),
                    const SizedBox(height: HiSpace.md),
                    // a11y : la célébration apparaît brutalement → liveRegion pour que le lecteur
                    // d'écran annonce le titre (et le sous-titre) dès l'ouverture.
                    Semantics(
                      liveRegion: true,
                      header: true,
                      child: Text(widget.title,
                          textAlign: TextAlign.center, style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: HiSpace.sm),
                      Text(widget.subtitle!,
                          textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                    ],
                    const SizedBox(height: HiSpace.md),
                    if (widget.actionLabel != null) ...[
                      HiButton(
                        label: widget.actionLabel!,
                        icon: Icons.ios_share_rounded,
                        onPressed: () {
                          Navigator.of(context).maybePop();
                          widget.onAction?.call();
                        },
                      ),
                      const SizedBox(height: HiSpace.sm),
                      Text('Continuer', style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                    ] else
                      Text('Touche pour continuer', style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  final double angle, speed, size, rot, rotSpeed, drift;
  final Color color;
  _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rot,
    required this.rotSpeed,
    required this.drift,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final maxR = size.shortestSide * 0.95;
    for (final p in particles) {
      // Explosion radiale + gravité + dérive horizontale.
      final r = p.speed * maxR * Curves.easeOut.transform(t);
      final gravity = 0.5 * 900 * t * t * p.speed * 0.4;
      final dx = origin.dx + math.cos(p.angle) * r + p.drift * r;
      final dy = origin.dy + math.sin(p.angle) * r + gravity;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rot + p.rotSpeed * t);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
