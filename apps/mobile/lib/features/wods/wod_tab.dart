import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import 'wod_detail_screen.dart';

/// Onglet WOD : catalogue des WODs (15 références + communautaires à venir).
class WodTab extends ConsumerStatefulWidget {
  const WodTab({super.key});

  @override
  ConsumerState<WodTab> createState() => _WodTabState();
}

class _WodTabState extends ConsumerState<WodTab> {
  late Future<List<WodCatalogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).wodsCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(() => _future = ref.read(apiClientProvider).wodsCatalog()),
        child: FutureBuilder<List<WodCatalogEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(padding: const EdgeInsets.all(HiSpace.lg), child: Text('${snap.error}', style: TextStyle(color: HiColors.error))),
              ]);
            }
            final all = snap.data!;
            final sansMateriel = all.where((w) => !w.requiresEquipment).toList();
            final avecMateriel = all.where((w) => w.requiresEquipment).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Text('Séances',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Choisis une séance (aussi appelée « WOD »), vois les records et où tu te situes.',
                    style: TextStyle(color: HiColors.textSecondary)),
                const SizedBox(height: HiSpace.lg),
                if (sansMateriel.isNotEmpty) ...[
                  _section('Sans matériel'),
                  ...sansMateriel.map(_card),
                  const SizedBox(height: HiSpace.lg),
                ],
                if (avecMateriel.isNotEmpty) ...[
                  _section('Avec matériel'),
                  ...avecMateriel.map(_card),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t.toUpperCase(),
            style: TextStyle(color: HiColors.textTertiary, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
      );

  Widget _card(WodCatalogEntry w) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HiSpace.sm),
      child: Material(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(HiRadius.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: w.id, wodName: w.name)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(HiSpace.md),
            child: Row(
              children: [
                Icon(w.scoreType == 'time' ? Icons.timer_outlined : Icons.repeat, color: HiColors.brandPrimary),
                const SizedBox(width: HiSpace.md),
                Expanded(
                  child: Text(w.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
                if (w.isCustom)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('≈', style: TextStyle(color: HiColors.warn, fontWeight: FontWeight.w800)),
                  ),
                Icon(Icons.chevron_right, color: HiColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
