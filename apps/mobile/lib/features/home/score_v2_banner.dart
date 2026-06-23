import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/rank_badge.dart';

const _prefKey = 'seen_score_v2_banner';

/// Affiche UNE fois l'explication de la bascule du score /1000 → /100 (« type FIFA »).
/// Widget invisible à placer en tête de l'accueil ; se déclenche après le 1er rendu.
class ScoreV2BannerLauncher extends ConsumerStatefulWidget {
  const ScoreV2BannerLauncher({super.key});

  @override
  ConsumerState<ScoreV2BannerLauncher> createState() => _ScoreV2BannerLauncherState();
}

class _ScoreV2BannerLauncherState extends ConsumerState<ScoreV2BannerLauncher> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_checked) return;
    _checked = true;
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return; // pas de stockage → on n'embête pas l'utilisateur
    }
    if (prefs.getBool(_prefKey) ?? false) return;

    // On attend d'avoir un Index à montrer (sinon on réessaiera au prochain lancement).
    final profile = ref.read(myProfileProvider).value;
    if (profile == null) {
      _checked = false;
      return;
    }
    await prefs.setBool(_prefKey, true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _ScoreV2Dialog(ovr: profile.index.value),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ScoreV2Dialog extends StatelessWidget {
  final int ovr;
  const _ScoreV2Dialog({required this.ovr});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: HiColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.scoreV2Title,
                textAlign: TextAlign.center,
                style: TextStyle(color: HiColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: HiSpace.md),
            Text(
              t.scoreV2Body,
              textAlign: TextAlign.center,
              style: TextStyle(color: HiColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: HiSpace.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg, vertical: HiSpace.md),
              decoration: BoxDecoration(
                color: HiColors.brandPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(HiRadius.md),
                border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Text(t.scoreV2YourIndex, style: TextStyle(color: HiColors.textSecondary, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (r) => HiColors.brandGradient.createShader(r),
                  child: Text('$ovr',
                      style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1)),
                ),
                Text('/ 100', style: TextStyle(color: HiColors.textTertiary, fontSize: 13)),
                const SizedBox(height: 8),
                RankBadge(ovr: ovr, fontSize: 13),
              ]),
            ),
            const SizedBox(height: HiSpace.sm),
            Text(t.scoreV2Benchmarks,
                textAlign: TextAlign.center,
                style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
            const SizedBox(height: HiSpace.lg),
            HiButton(label: t.scoreV2Got, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
