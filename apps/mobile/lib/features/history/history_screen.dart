import 'package:flutter/material.dart';
import 'pr_wall_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/wod_catalog.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../wods/wod_detail_screen.dart';
import '../wods/wod_format.dart';

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

  String _name(String wodId) => _catalog(wodId)?.name ??
      (wodId == 'run_free_distance' ? AppLocalizations.of(context).historyRun : wodId);

  String _formatResult(WodResultItem r) {
    final type = _catalog(r.wodId)?.scoreType ?? (r.wodId == 'run_free_distance' ? 'time' : 'reps');
    if (type == 'time') return formatDuration(r.rawResult.round());
    if (type == 'load') return '${r.rawResult.round()} kg';
    if (type == 'distance') return '${r.rawResult.round()} m';
    return '${r.rawResult.round()} reps';
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _delete(WodResultItem r) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(t.historyDeleteTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Text(t.historyDeleteBody(_name(r.wodId), _date(r.performedAt)),
            style: HiType.body.copyWith(color: HiColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.commonCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.commonDelete, style: HiType.button.copyWith(color: HiColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteResult(r.id);
      ref.invalidate(myProfileProvider);
      ref.invalidate(completionPlanProvider); // suppression → un attribut peut redevenir verrouillé
      if (mounted) setState(() => _future = ref.read(apiClientProvider).results());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.commonGenericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.historyTitle), backgroundColor: Colors.transparent, elevation: 0, actions: [IconButton(icon: const Icon(Icons.emoji_events_rounded), tooltip: 'Mes records', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrWallScreen())))]),
      body: SafeArea(
        child: FutureBuilder<List<WodResultItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) {
              return ErrorRetry(onRetry: () => setState(() => _future = ref.read(apiClientProvider).results()));
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HiSpace.lg),
                  child: Text(t.historyEmpty,
                      textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textTertiary)),
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
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WodDetailScreen(wodId: r.wodId, wodName: _name(r.wodId)))),
      child: Container(
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
                Text(_name(r.wodId), style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${_formatResult(r)} · ${_date(r.performedAt)}',
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
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
                  style: HiType.numericM.copyWith(color: HiColors.brandPrimary)),
            ),
          IconButton(
            tooltip: AppLocalizations.of(context).commonDelete,
            icon: Icon(Icons.delete_outline_rounded, color: HiColors.textTertiary, size: 20),
            onPressed: () => _delete(r),
          ),
          ],
        ),
      ),
    );
  }
}
