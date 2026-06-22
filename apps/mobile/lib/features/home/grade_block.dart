import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../wods/wod_detail_screen.dart';

/// Séances pour compléter le radar (révéler le vrai Index). autoDispose : rechargé à chaque
/// ouverture de l'accueil, libéré ensuite.
final completionPlanProvider =
    FutureProvider.autoDispose<CompletionPlan>((ref) => ref.read(apiClientProvider).completionPlan());

/// Bloc accueil sous l'Index : chip de grade (« 70+ »), barre de progression vers le palier
/// suivant, notice « Index estimé » + séances à faire tant que le radar n'est pas complet.
class GradeBlock extends ConsumerWidget {
  final Profile profile;
  const GradeBlock({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ovr = profile.index.value;
    final coverage = profile.index.radarCoverage;
    final incomplete = coverage < 6;
    final color = HiGrade.color(ovr);

    return Column(
      children: [
        _gradeChip(ovr, color),
        const SizedBox(height: HiSpace.md),
        _progressBar(ovr, color),
        const SizedBox(height: HiSpace.sm),
        if (incomplete) _estimationNotice(context, ref, coverage) else _actionMessage(ovr),
      ],
    );
  }

  Widget _gradeChip(int ovr, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(HiRadius.pill),
        border: Border.all(color: color, width: 1.5),
        boxShadow: ovr >= 100 ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ovr >= 100) ...[
            Icon(Icons.workspace_premium, color: color, size: 16),
            const SizedBox(width: 4),
          ],
          Text(HiGrade.label(ovr),
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _progressBar(int ovr, Color color) {
    if (ovr >= 100) {
      return Text('Sommet atteint — 100',
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800));
    }
    // Paliers de 5 (plus de jalons, progression plus lisible) : prochaine cible = multiple de 5.
    final lower5 = (ovr ~/ 5) * 5;
    final next5 = (lower5 + 5).clamp(0, 100);
    final pts = (next5 - ovr).clamp(1, 5);
    final fill = ((ovr - lower5) / 5).clamp(0.0, 1.0);
    final nextColor = HiGrade.color(next5); // couleur du palier de grade visé (peut être identique)
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text('${pts == 1 ? '1 pt' : '$pts pts'} → $next5',
              style: TextStyle(color: nextColor, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(HiRadius.pill),
          child: Stack(
            children: [
              Container(height: 10, color: HiColors.bgElevated2),
              FractionallySizedBox(
                widthFactor: fill.clamp(0.02, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, nextColor]),
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$ovr', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            Text('$next5', style: TextStyle(color: HiColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  /// Tant que les 6 attributs ne sont pas débloqués : on précise que l'Index est une ESTIMATION,
  /// et on RECOMMANDE les séances minimales à faire pour révéler le vrai Index.
  Widget _estimationNotice(BuildContext context, WidgetRef ref, int coverage) {
    final title = coverage >= 5 ? 'Presque ton vrai Index' : 'Index estimé';
    final planAsync = ref.watch(completionPlanProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.warn.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.warn.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, color: HiColors.warn, size: 18),
              const SizedBox(width: HiSpace.sm),
              Expanded(child: Text(title, style: TextStyle(color: HiColors.warn, fontWeight: FontWeight.w800, fontSize: 13))),
              _coverageDots(coverage),
            ],
          ),
          const SizedBox(height: 8),
          planAsync.when(
            loading: () => Text('Estimation sur $coverage/6 attributs…', style: TextStyle(color: HiColors.textSecondary, fontSize: 12)),
            error: (_, __) => Text(
              'Estimation sur $coverage/6 attributs. Complète ton radar pour révéler ton vrai Index.',
              style: TextStyle(color: HiColors.textSecondary, fontSize: 12, height: 1.3),
            ),
            data: (plan) {
              final n = plan.sessions.length;
              if (n == 0) {
                return Text('Continue à logger des séances pour finaliser ton Index.',
                    style: TextStyle(color: HiColors.textSecondary, fontSize: 12));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: HiColors.textSecondary, fontSize: 12, height: 1.3),
                      children: [
                        const TextSpan(text: 'Complète '),
                        TextSpan(text: n == 1 ? 'cette séance' : 'ces $n séances',
                            style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800)),
                        const TextSpan(text: ' pour révéler ton vrai Index :'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...plan.sessions.map((s) => _sessionRow(context, s)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Une séance recommandée (clic → fiche pour la faire).
  Widget _sessionRow(BuildContext context, CompletionSession s) {
    final covers = s.covers.map((c) => HiLabels.attribute(c)).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(HiRadius.sm),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: s.wodId, wodName: s.name)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(s.requiresEquipment ? Icons.fitness_center : Icons.self_improvement, size: 16, color: HiColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Débloque : $covers', style: TextStyle(color: HiColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: HiColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverageDots(int coverage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (i) {
        final on = i < coverage;
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: on ? HiColors.warn : HiColors.strokeStrong,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  /// Index complet (6/6) : message d'action court vers le palier suivant.
  Widget _actionMessage(int ovr) {
    final weak = profile.weakest;
    final next = HiGrade.nextLabel(ovr);
    if (weak == null) {
      return Text('Continue à logger tes séances pour grimper vers $next.',
          textAlign: TextAlign.center, style: TextStyle(color: HiColors.textSecondary, fontSize: 13));
    }
    final attrColor = HiColors.attribute(weak);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.trending_up, color: attrColor, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(color: HiColors.textSecondary, fontSize: 13),
              children: [
                const TextSpan(text: 'Travaille ta '),
                TextSpan(text: HiLabels.attribute(weak), style: TextStyle(color: attrColor, fontWeight: FontWeight.w800)),
                const TextSpan(text: ' pour viser '),
                TextSpan(text: next, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
