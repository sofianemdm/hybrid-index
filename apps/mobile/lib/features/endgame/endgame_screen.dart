import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Grand Chelem'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<EndgameInfo>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            final e = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                _hero(e),
                const SizedBox(height: HiSpace.lg),
                Text('Les 4 séances phares', style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: HiSpace.sm),
                ...e.flagship.map((f) => _flagshipRow(f, e)),
                const SizedBox(height: HiSpace.lg),
                _trophyTier('bronze', '🥉 Bronze', 'Terminer les 4 séances phares.', e),
                _trophyTier('silver', '🥈 Argent', 'Les 4 avec une note ≥ ${e.silverMin}/100 — difficile mais atteignable (~1 an de pratique).', e),
                _trophyTier('gold', '🥇 Or', 'Les 4 avec une note ≥ ${e.goldMin}/100 — ultra exigeant (~5 ans).', e),
                const SizedBox(height: HiSpace.lg),
                _statCard('Rang mondial', e.globalRank != null ? '#${e.globalRank} / ${e.globalTotal}' : '—',
                    e.isTop100 ? 'Top 100 mondial 🌍' : null, HiColors.brandPrimary),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(EndgameInfo e) {
    final c = _tierColor[e.tier] ?? HiColors.textTertiary;
    final emoji = {'bronze': '🥉', 'silver': '🥈', 'gold': '🥇'}[e.tier] ?? '🔒';
    final label = {'bronze': 'Grand Chelem Bronze', 'silver': 'Grand Chelem Argent', 'gold': 'Grand Chelem Or'}[e.tier] ??
        'Grand Chelem — non débloqué';
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
              style: TextStyle(color: e.tier == 'none' ? HiColors.textSecondary : c, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text('${e.completed}/${e.total} séances phares terminées',
              style: TextStyle(color: HiColors.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _flagshipRow(SlamFlagship f, EndgameInfo e) {
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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 12),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          Icon(f.done ? Icons.check_circle : Icons.radio_button_unchecked, color: f.done ? sc : HiColors.textTertiary, size: 20),
          const SizedBox(width: HiSpace.sm),
          Expanded(child: Text(f.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700))),
          Text(f.done ? '${f.score}/100' : '—',
              style: TextStyle(color: f.done ? sc : HiColors.textTertiary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _trophyTier(String tier, String title, String desc, EndgameInfo e) {
    final unlocked = _order.indexOf(e.tier) >= _order.indexOf(tier);
    final c = _tierColor[tier]!;
    return Container(
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
                Text(title, style: TextStyle(color: unlocked ? c : HiColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: HiColors.textTertiary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: HiSpace.sm),
          Icon(unlocked ? Icons.emoji_events : Icons.lock_outline, color: unlocked ? c : HiColors.textTertiary),
        ],
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
          Icon(Icons.public, color: color),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                Text(value, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                if (highlight != null) Text(highlight, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
