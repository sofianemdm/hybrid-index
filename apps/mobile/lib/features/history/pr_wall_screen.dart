import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';

/// A8 — PR Wall : le mur des records personnels (meilleur effort par WOD).
class PrWallScreen extends ConsumerStatefulWidget {
  const PrWallScreen({super.key});

  @override
  ConsumerState<PrWallScreen> createState() => _PrWallScreenState();
}

class _PrWallScreenState extends ConsumerState<PrWallScreen> {
  late Future<List<PrItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).personalRecords();
  }

  void _reload() => setState(() => _future = ref.read(apiClientProvider).personalRecords());

  String _formatResult(PrItem p) {
    if (p.scoreType == 'time') {
      final s = p.rawResult.round();
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }
    return p.rawResult.toStringAsFixed(p.rawResult % 1 == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).prWallTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: FutureBuilder<List<PrItem>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
                  itemCount: 8,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, __) => const HiSkeleton(height: 64, radius: HiRadius.sm),
                );
              }
              if (snap.hasError) {
                return _centered(
                  AppLocalizations.of(context).prWallError,
                  TextButton(onPressed: _reload, child: Text(AppLocalizations.of(context).commonRetry)),
                );
              }
              final prs = snap.data ?? const <PrItem>[];
              if (prs.isEmpty) {
                return _centered(AppLocalizations.of(context).prWallEmpty, null);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
                itemCount: prs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _prCard(prs[i]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _prCard(PrItem p) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.sm),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: HiColors.rank('gold'), size: 22),
          const SizedBox(width: HiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.wodName, style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Record : ${_formatResult(p)}',
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: HiColors.brandPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(HiRadius.pill),
            ),
            child: Text('${p.subScore}',
                style: HiType.numericM.copyWith(color: HiColors.brandPrimary, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _centered(String text, Widget? action) {
    return ListView(
      padding: const EdgeInsets.all(HiSpace.lg),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.emoji_events_outlined, color: HiColors.textTertiary, size: 44),
        const SizedBox(height: HiSpace.md),
        Text(text, textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
        if (action != null) ...[const SizedBox(height: HiSpace.md), Center(child: action)],
      ],
    );
  }
}
