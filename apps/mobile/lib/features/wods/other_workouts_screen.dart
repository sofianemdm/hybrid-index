import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import 'wod_detail_screen.dart';

/// « Autre » : épreuves réelles (HYROX solo, WODs de compét, courses) — présentées comme les
/// séances (séparation matériel / sans), noms seuls ; au clic, fiche complète + on peut la faire.
class OtherWorkoutsScreen extends ConsumerWidget {
  const OtherWorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autres épreuves'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<List<WodCatalogEntry>>(
          future: ref.read(apiClientProvider).wodsCatalog(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            final others = (snap.data ?? []).where((w) => w.isOther).toList();
            final sans = others.where((w) => !w.requiresEquipment).toList();
            final avec = others.where((w) => w.requiresEquipment).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Text('De grandes épreuves réelles (HYROX, WODs de compétition, courses). '
                    'Ouvre-en une pour voir les détails et les records — et enregistre ton temps.',
                    style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                const SizedBox(height: HiSpace.lg),
                if (sans.isNotEmpty) ...[
                  _section('Sans matériel'),
                  ...sans.map((w) => _tile(context, w)),
                  const SizedBox(height: HiSpace.lg),
                ],
                if (avec.isNotEmpty) ...[
                  _section('Avec matériel'),
                  ...avec.map((w) => _tile(context, w)),
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
        child: Text(t, style: TextStyle(color: HiColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      );

  Widget _tile(BuildContext context, WodCatalogEntry w) => Card(
        color: HiColors.bgElevated,
        child: ListTile(
          title: Text(w.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
          trailing: Icon(Icons.chevron_right, color: HiColors.textTertiary),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: w.id, wodName: w.name)),
          ),
        ),
      );
}
