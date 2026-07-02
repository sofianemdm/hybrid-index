import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../wods/wod_detail_screen.dart';

/// Encart « Index estimé » affiché SOUS la PlayerCard tant que l'Index n'est pas complet.
///
/// La PlayerCard montre désormais l'OVR et le grade (ex-chip + barre de l'ancien GradeBlock,
/// devenus redondants → retirés). Cet encart slim ne garde que ce que la carte NE dit PAS :
/// (1) l'Index affiché est une ESTIMATION, (2) les séances minimales à faire pour le révéler.
///
/// Ne s'affiche QUE si l'Index est incomplet/estimé (radar < 6 OU isEstimated). L'appelant
/// (home_screen) gère cette condition ; le widget la re-vérifie pour rester sûr isolément.
class EstimationBlock extends ConsumerWidget {
  final Profile profile;
  const EstimationBlock({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = profile.index.radarCoverage;
    // Notice « estimé » si le radar est incomplet OU si l'Index est encore estimé (ex. après
    // Profil Express : 6/6 mais tout estimé → on incite à faire de vraies séances).
    final incomplete = coverage < 6 || profile.index.isEstimated;
    if (!incomplete) return const SizedBox.shrink();
    return _estimationNotice(context, ref, coverage);
  }

  /// Tant que les 6 attributs ne sont pas débloqués : on précise que l'Index est une ESTIMATION,
  /// et on RECOMMANDE les séances minimales à faire pour révéler le vrai Index.
  Widget _estimationNotice(BuildContext context, WidgetRef ref, int coverage) {
    final t = AppLocalizations.of(context);
    final title = coverage == 5 ? t.gradeAlmostReal : t.gradeEstimated;
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
          Semantics(
            container: true,
            label: t.gradeA11y(title, coverage, planAsync.asData?.value.sessions.length ?? 0),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(Icons.construction_rounded, color: HiColors.warn, size: 18),
                  const SizedBox(width: HiSpace.sm),
                  Expanded(child: Text(title, style: HiType.label.copyWith(color: HiColors.warn, fontWeight: FontWeight.w800))),
                  ExcludeSemantics(child: _coverageDots(coverage)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          planAsync.when(
            loading: () => ExcludeSemantics(child: Text(t.gradeEstimationLoading(coverage), style: HiType.caption.copyWith(color: HiColors.textSecondary))),
            error: (_, __) => ExcludeSemantics(
              child: Text(
                t.gradeEstimationError(coverage),
                style: HiType.caption.copyWith(color: HiColors.textSecondary, height: 1.3),
              ),
            ),
            data: (plan) {
              final n = plan.sessions.length;
              if (n == 0) {
                return ExcludeSemantics(
                  child: Text(t.gradeKeepLogging,
                      style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: RichText(
                    text: TextSpan(
                      style: HiType.caption.copyWith(color: HiColors.textSecondary, height: 1.3),
                      children: [
                        TextSpan(text: t.gradeCompletePrefix),
                        TextSpan(text: n == 1 ? t.gradeCompleteSessionOne : t.gradeCompleteSessionMany(n),
                            style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800)),
                        TextSpan(text: t.gradeCompleteSuffix),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 6),
                  // Précision rassurante : ces séances recommandées ne sont pas obligatoires.
                  ExcludeSemantics(
                    child: Text(t.gradeCompleteOptional,
                        style: HiType.caption.copyWith(
                            color: HiColors.textTertiary, fontStyle: FontStyle.italic, height: 1.3)),
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
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context).gradeSessionA11y(s.name, covers),
        child: Material(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(HiRadius.sm),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: s.wodId, wodName: s.name)),
          ),
          child: ExcludeSemantics(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(s.requiresEquipment ? Icons.fitness_center : Icons.self_improvement, size: 16, color: HiColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: HiType.label.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                      Text(AppLocalizations.of(context).gradeUnlocks(covers), style: HiType.caption.copyWith(color: HiColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: HiColors.textTertiary),
              ],
            ),
          )),
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
}
