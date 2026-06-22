import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';

/// « Autre » : épreuves réelles (HYROX solo, WODs de compétition, courses) avec les VRAIS temps
/// publics des pros. Informatif — ce ne sont pas des séances notées de l'app.
class OtherWorkoutsScreen extends ConsumerWidget {
  const OtherWorkoutsScreen({super.key});

  static const _catLabels = {'hyrox': 'HYROX', 'crossfit': 'CrossFit', 'course': 'Course'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autres épreuves'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<List<OtherWorkout>>(
          future: ref.read(apiClientProvider).otherWorkouts(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            final items = snap.data ?? [];
            final cats = ['hyrox', 'crossfit', 'course'];
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Text('Les vrais temps des pros sur de grandes épreuves — données publiques de compétition. '
                    'Informatif : ces épreuves ne sont pas notées dans l\'app.',
                    style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                const SizedBox(height: HiSpace.lg),
                for (final cat in cats) ...[
                  if (items.any((w) => w.category == cat)) ...[
                    Text(_catLabels[cat] ?? cat,
                        style: TextStyle(color: HiColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                    const SizedBox(height: HiSpace.sm),
                    ...items.where((w) => w.category == cat).map(_card),
                    const SizedBox(height: HiSpace.lg),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(OtherWorkout w) {
    return Container(
      margin: const EdgeInsets.only(bottom: HiSpace.md),
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 2),
          Text(w.format, style: TextStyle(color: HiColors.brandPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: HiSpace.sm),
          Text(w.description, style: TextStyle(color: HiColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: HiSpace.md),
          Divider(height: 1, color: HiColors.strokeSubtle),
          const SizedBox(height: HiSpace.sm),
          Text('RECORDS & ÉLITE',
              style: TextStyle(color: HiColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...w.records.map(_refRow),
        ],
      ),
    );
  }

  Widget _refRow(OtherRef r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(r.sex == 'female' ? '♀' : '♂', style: TextStyle(color: HiColors.textTertiary, fontSize: 13)),
          const SizedBox(width: HiSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.athlete, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(r.source, style: TextStyle(color: HiColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: HiSpace.sm),
          Flexible(
            child: Text(r.note,
                textAlign: TextAlign.right,
                style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
