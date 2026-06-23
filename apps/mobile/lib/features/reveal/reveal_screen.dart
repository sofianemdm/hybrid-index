import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/hi_card.dart';
import '../../widgets/index_ring.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/rank_badge.dart';
import '../../widgets/rank_progress_bar.dart';
import '../../widgets/social_proof_card.dart';

/// L'écran « waouh » : séquence orchestrée (suspense → l'Index se remplit en comptant → le rang
/// et la preuve sociale apparaissent → le radar → CTA). Tap n'importe où pour tout révéler.
class RevealScreen extends ConsumerStatefulWidget {
  final Profile profile;
  const RevealScreen({super.key, required this.profile});

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends ConsumerState<RevealScreen> {
  /// Étape de révélation : 0 suspense · 1 anneau · 2 rang/preuve · 3 radar · 4 CTA.
  int _step = 0;
  bool _peaked = false;

  // Calendrier (ms depuis l'entrée). L'anneau compte sur HiMotion.reveal (1600ms).
  static const _t1 = 700; // suspense → anneau
  static const _t2 = 700 + 1700; // fin du count-up → rang + preuve (+ pic haptique)
  static const _t3 = _t2 + 500; // → radar
  static const _t4 = _t3 + 450; // → CTA

  @override
  void initState() {
    super.initState();
    _schedule(_t1, 1);
    _schedule(_t2, 2, peak: true);
    _schedule(_t3, 3);
    _schedule(_t4, 4);
  }

  void _schedule(int ms, int step, {bool peak = false}) {
    Future.delayed(Duration(milliseconds: ms), () {
      if (!mounted || _step >= step) return;
      if (peak) _peak();
      setState(() => _step = step);
    });
  }

  void _peak() {
    if (_peaked) return;
    _peaked = true;
    HiHaptics.impact();
  }

  /// Tap → tout révéler immédiatement.
  void _skip() {
    _peak();
    setState(() => _step = 4);
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.profile.index;
    return Scaffold(
      body: GestureDetector(
        onTap: _step < 4 ? _skip : null,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(HiSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const SizedBox(height: HiSpace.md),
                    Text('TON HYBRID INDEX', style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                    const SizedBox(height: HiSpace.lg),
                    // Phase 0 : suspense ; Phase 1+ : l'anneau qui se remplit en comptant.
                    SizedBox(
                      height: 280,
                      child: Center(
                        child: _step == 0
                            ? const _Suspense()
                            : IndexRing(value: idx.value, percentile: idx.percentile),
                      ),
                    ),
                    const SizedBox(height: HiSpace.lg),
                    // Phase 2 : rang + preuve sociale (« top X% des humains »).
                    _staged(
                      visible: _step >= 2,
                      child: Column(
                        children: [
                          RankBadge(rank: idx.rank, fontSize: 15),
                          if (idx.isProvisional) ...[
                            const SizedBox(height: HiSpace.sm),
                            Text('Index provisoire — affine-le en loggant plus de séances.',
                                textAlign: TextAlign.center, style: HiType.caption.copyWith(color: HiColors.warn)),
                          ],
                          if (idx.rankProgress != null) ...[
                            const SizedBox(height: HiSpace.lg),
                            RankProgressBar(rp: idx.rankProgress!),
                          ],
                          if (widget.profile.socialProof != null) ...[
                            const SizedBox(height: HiSpace.lg),
                            SocialProofCard(proof: widget.profile.socialProof!),
                          ],
                        ],
                      ),
                    ),
                    // Phase 3 : radar.
                    _staged(
                      visible: _step >= 3,
                      child: Padding(
                        padding: const EdgeInsets.only(top: HiSpace.xl),
                        child: HiCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TON RADAR', style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                              const SizedBox(height: HiSpace.sm),
                              RadarView(radar: widget.profile.radar),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Phase 4 : CTA.
                    _staged(
                      visible: _step >= 4,
                      child: Padding(
                        padding: const EdgeInsets.only(top: HiSpace.lg),
                        child: HiButton(
                          label: 'Découvrir mon profil',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () {
                            ref.invalidate(myProfileProvider);
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: HiSpace.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Apparition douce (fade + montée) d'un bloc quand son étape est atteinte.
  Widget _staged({required bool visible, required Widget child}) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.12),
      duration: HiMotion.slow,
      curve: HiMotion.enter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: HiMotion.slow,
        curve: HiMotion.enter,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

/// Suspense pré-révélation : « Calcul… » avec un point cyan qui respire.
class _Suspense extends StatefulWidget {
  const _Suspense();
  @override
  State<_Suspense> createState() => _SuspenseState();
}

class _SuspenseState extends State<_Suspense> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HiColors.brandPrimary.withValues(alpha: 0.10 + 0.18 * _c.value),
                boxShadow: [
                  BoxShadow(
                    color: HiColors.brandPrimary.withValues(alpha: 0.25 * _c.value),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.bolt_rounded, color: HiColors.brandPrimary, size: 32),
            ),
            const SizedBox(height: HiSpace.lg),
            Text('Calcul de ton Index…', style: HiType.body.copyWith(color: HiColors.textSecondary)),
          ],
        );
      },
    );
  }
}
