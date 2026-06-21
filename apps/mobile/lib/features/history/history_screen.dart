import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/wod_catalog.dart';
import '../../theme/tokens.dart';

/// Journal : historique des WODs loggés (résultat + sous-score + date).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<WodResultItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).results();
  }

  WodCatalogItem? _catalog(String wodId) {
    for (final w in wodCatalog) {
      if (w.id == wodId) return w;
    }
    return null;
  }

  String _name(String wodId) => _catalog(wodId)?.name ?? (wodId == 'run_free_distance' ? 'Course' : wodId);

  String _formatResult(WodResultItem r) {
    final type = _catalog(r.wodId)?.scoreType ?? (r.wodId == 'run_free_distance' ? 'time' : 'reps');
    if (type == 'time') {
      final s = r.rawResult.round();
      final m = s ~/ 60;
      final sec = s % 60;
      return '$m:${sec.toString().padLeft(2, '0')}';
    }
    if (type == 'load') return '${r.rawResult.round()} kg';
    if (type == 'distance') return '${r.rawResult.round()} m';
    return '${r.rawResult.round()} reps';
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon historique'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<List<WodResultItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text('Aucun WOD loggé pour l’instant.',
                      textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(HiSpace.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: HiSpace.sm),
              itemBuilder: (_, i) => _tile(items[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(WodResultItem r) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name(r.wodId), style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${_formatResult(r)} · ${_date(r.performedAt)}',
                    style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (r.subScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HiColors.brandPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(HiRadius.pill),
              ),
              child: Text('${r.subScore}',
                  style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}
