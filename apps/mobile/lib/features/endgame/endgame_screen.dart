import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../wods/wod_detail_screen.dart';

/// Grand Chelem : réussir les 4 séances phares — Bronze (terminées), Argent (bonnes notes),
/// Or (notes excellentes). + classement mondial.
class EndgameScreen extends ConsumerStatefulWidget {
  const EndgameScreen({super.key});

  @override
  ConsumerState<EndgameScreen> createState() => _EndgameScreenState();
}

class _EndgameScreenState extends ConsumerState<EndgameScreen> {
  late Future<EndgameInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).endgame();
  }

  static const _order = ['none', 'bronze', 'silver', 'gold'];
  static const _tierColor = {
    'bronze': Color(0xFFC87E4F),
    'silver': Color(0xFFC2CBD8),
    'gold': Color(0xFFF3C13A),
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.endgameTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<EndgameInfo>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) return ErrorRetry(onRetry: () => setState(() => _future = ref.read(apiClientProvider).endgame()));
            final e = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                _hero(e),
                const SizedBox(height: HiSpace.lg),
                Text(t.endgameFlagshipTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                Text(t.endgameFlagshipSubtitle,
                    style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                const SizedBox(height: HiSpace.sm),
                ...e.flagship.map((f) => _flagshipRow(f, e)),
                const SizedBox(height: HiSpace.lg),
                _trophyTier('bronze', t.endgameTierBronze, t.endgameTierBronzeDesc, e),
                _trophyTier('silver', t.endgameTierSilver, t.endgameTierSilverDesc(e.silverMin), e),
                _trophyTier('gold', t.endgameTierGold, t.endgameTierGoldDesc(e.goldMin), e),
                const SizedBox(height: HiSpace.lg),
                _statCard(t.endgameGlobalRank, e.globalRank != null ? '#${e.globalRank} / ${e.globalTotal}' : '—',
                    e.isTop100 ? t.endgameTop100 : null, HiColors.brandPrimary),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(EndgameInfo e) {
    final t = AppLocalizations.of(context);
    final c = _tierColor[e.tier] ?? HiColors.textTertiary;
    final emoji = {'bronze': '🥉', 'silver': '🥈', 'gold': '🥇'}[e.tier] ?? '🔒';
    final label = {'bronze': t.endgameHeroBronze, 'silver': t.endgameHeroSilver, 'gold': t.endgameHeroGold}[e.tier] ??
        t.endgameHeroLocked;
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.lg),
        border: Border.all(color: e.tier == 'none' ? HiColors.strokeSubtle : c, width: 2),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: HiSpace.sm),
          Text(label, textAlign: TextAlign.center,
              style: HiType.titleL.copyWith(color: e.tier == 'none' ? HiColors.textSecondary : c)),
          const SizedBox(height: 4),
          Text(t.endgameFlagshipDone(e.completed, e.total),
              style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _flagshipRow(SlamFlagship f, EndgameInfo e) {
    final t = AppLocalizations.of(context);
    final Color sc;
    if (!f.done) {
      sc = HiColors.textTertiary;
    } else if ((f.score ?? 0) >= e.goldMin) {
      sc = _tierColor['gold']!;
    } else if ((f.score ?? 0) >= e.silverMin) {
      sc = _tierColor['silver']!;
    } else {
      sc = _tierColor['bronze']!;
    }
    // a11y : statut (faite/à faire) + score énoncés, rôle bouton (ouvre le WOD).
    final rowLabel = f.done
        ? t.a11yFlagshipDone(f.name, f.score ?? 0)
        : t.a11yFlagshipTodo(f.name);
    return Semantics(
      button: true,
      label: rowLabel,
      child: ExcludeSemantics(
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HiRadius.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: f.wodId, wodName: f.name)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 12),
            child: Row(
              children: [
                Icon(f.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: f.done ? sc : HiColors.textTertiary, size: 20),
                const SizedBox(width: HiSpace.sm),
                Expanded(child: Text(f.name, style: HiType.titleM.copyWith(color: HiColors.textPrimary))),
                Text(f.done ? '${f.score}/100' : '—',
                    style: HiType.bodyStrong.copyWith(color: f.done ? sc : HiColors.textTertiary, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }

  Widget _trophyTier(String tier, String title, String desc, EndgameInfo e) {
    final t = AppLocalizations.of(context);
    final unlocked = _order.indexOf(e.tier) >= _order.indexOf(tier);
    final c = _tierColor[tier]!;
    // a11y : palier de trophée énoncé avec son état (débloqué / verrouillé).
    return Semantics(
      label: '$title, ${unlocked ? t.a11yUnlocked : t.a11yLocked}. $desc',
      child: ExcludeSemantics(
      child: Container(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: unlocked ? c.withValues(alpha: 0.12) : HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: unlocked ? c : HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HiType.titleM.copyWith(color: unlocked ? c : HiColors.textSecondary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(desc, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: HiSpace.sm),
          Icon(unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded, color: unlocked ? c : HiColors.textTertiary),
        ],
      ),
    ),
    ),
    );
  }

  Widget _statCard(String title, String value, String? highlight, Color color) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.public_rounded, color: color),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                Text(value, style: HiType.numericM.copyWith(color: HiColors.textPrimary)),
                if (highlight != null) Text(highlight, style: HiType.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
