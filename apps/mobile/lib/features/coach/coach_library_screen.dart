import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/celebration.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_button.dart';
import '../../widgets/hi_card.dart';
import '../../widgets/hi_skeleton.dart';
import '../guided/guided_session_screen.dart';

/// Bibliothèque de séances GUIDÉES du coach (type « Le Forgeron ») : des entraînements clés en main
/// (nom, durée, intensité, attributs travaillés, déroulé). À ne PAS confondre avec les ÉPREUVES
/// loguables (WODs) qui, elles, mesurent le score — voir [SessionsByAttributeScreen].
///
/// La donnée vient de GET /v1/coach/library?attribute=… (api_client.coachLibrary). L'API exige UN
/// attribut et renvoie les séances qui le travaillent, triées par pertinence (poids décroissant).
/// On propose un filtre par axe ; l'option « Tout » fait UN appel GET /v1/coach/library/all
/// (séances dédupliquées + triées côté serveur, anti N+1) au lieu d'agréger 6 appels par-axe.
class CoachLibraryScreen extends ConsumerStatefulWidget {
  /// Axe initialement sélectionné (clé interne). Null ⇒ « Tout ».
  final String? attribute;
  const CoachLibraryScreen({super.key, this.attribute});

  @override
  ConsumerState<CoachLibraryScreen> createState() => _CoachLibraryScreenState();
}

class _CoachLibraryScreenState extends ConsumerState<CoachLibraryScreen> {
  static const _attrs = ['engine', 'speed', 'strength', 'power', 'muscular_endurance', 'hybrid'];

  // null = filtre « Tout » (toutes les séances, agrégées sur les 6 axes).
  String? _selected;
  late Future<List<CoachSession>> _future;

  @override
  void initState() {
    super.initState();
    _selected = widget.attribute;
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    final sel = _selected;
    if (sel != null) {
      _future = api.coachLibrary(sel);
    } else {
      // « Tout » : UN SEUL appel serveur (GET /v1/coach/library/all) — séances déjà dédupliquées,
      // filtrées matériel et triées (durée asc → nom) côté back. Remplace les 6 appels par-axe
      // (anti N+1, plus all-or-nothing). Même ordre que l'ancienne agrégation client
      // (aggregateAllSessions, conservée et testée dans coach_library_aggregate.dart, repli possible).
      _future = api.coachLibraryAll();
    }
  }

  void _select(String? attr) {
    setState(() {
      _selected = attr;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.coachLibraryTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(HiSpace.gutter, HiSpace.sm, HiSpace.gutter, HiSpace.sm),
              child: Text(t.coachLibrarySubtitle,
                  style: HiType.body.copyWith(color: HiColors.textSecondary)),
            ),
            _filters(t),
            const SizedBox(height: HiSpace.sm),
            Expanded(
              child: FutureBuilder<List<CoachSession>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _skeleton();
                  }
                  if (snap.hasError) {
                    return ErrorRetry(message: t.coachLibraryError, onRetry: () => setState(_load));
                  }
                  final sessions = snap.data ?? const [];
                  if (sessions.isEmpty) {
                    return _empty(t);
                  }
                  return RefreshIndicator(
                    onRefresh: () async => setState(_load),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(HiSpace.gutter, HiSpace.sm, HiSpace.gutter, 96),
                      itemCount: sessions.length,
                      itemBuilder: (context, i) => _sessionCard(sessions[i], t),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rangée de filtres : « Tout » + les 6 axes (chip teinté par l'axe).
  Widget _filters(AppLocalizations t) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HiSpace.gutter),
        children: [
          _chip(label: t.coachLibraryAll, color: HiColors.brandPrimary, selected: _selected == null, onTap: () => _select(null)),
          for (final a in _attrs) ...[
            const SizedBox(width: 8),
            _chip(
              label: HiLabels.attribute(a),
              color: HiColors.attribute(a),
              selected: _selected == a,
              onTap: () => _select(a),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({required String label, required Color color, required bool selected, required VoidCallback onTap}) {
    final t = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: t.a11yCoachFilter(label),
      child: ExcludeSemantics(
        child: Material(
      color: selected ? color.withValues(alpha: 0.18) : HiColors.bgElevated,
      borderRadius: BorderRadius.circular(HiRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(HiRadius.pill),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HiRadius.pill),
            border: Border.all(color: selected ? color.withValues(alpha: 0.6) : HiColors.strokeSubtle),
          ),
          child: Text(label,
              style: HiType.label.copyWith(
                  color: selected ? color : HiColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
        ),
      ),
    ),
      ),
    );
  }

  /// Carte d'une séance guidée : nom, durée, intensité, attributs travaillés, déroulé.
  Widget _sessionCard(CoachSession s, AppLocalizations t) {
    final accent = HiColors.attribute(s.primaryAttribute);
    final attrs = <String>[s.primaryAttribute, ...s.secondaryAttributes];
    return Padding(
      padding: const EdgeInsets.only(bottom: HiSpace.sm),
      child: Semantics(
      container: true,
      label: t.a11yCoachSession(s.name, s.durationMin, _intensityLabel(t, s.intensity)),
      child: MergeSemantics(
      child: HiCard(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(HiRadius.sm)),
                  child: Icon(Icons.directions_run_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: HiSpace.md),
                Expanded(
                  child: Text(s.name, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: HiSpace.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _meta(Icons.schedule_rounded, t.coachDurationMin(s.durationMin), HiColors.textSecondary),
                _meta(_intensityIcon(s.intensity), _intensityLabel(t, s.intensity), _intensityColor(s.intensity)),
                _meta(s.requiresEquipment ? Icons.fitness_center_rounded : Icons.self_improvement_rounded,
                    s.requiresEquipment ? t.wodTabWithEquipment : t.wodTabNoEquipment,
                    s.requiresEquipment ? HiColors.warn : HiColors.success),
              ],
            ),
            const SizedBox(height: HiSpace.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: attrs.map((a) {
                final c = HiColors.attribute(a);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(HiRadius.pill)),
                  child: Text(HiLabels.attribute(a),
                      style: HiType.caption.copyWith(color: c, fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
            const SizedBox(height: HiSpace.sm),
            Text(s.description,
                style: HiType.body.copyWith(color: HiColors.textSecondary, height: 1.45)),
            const SizedBox(height: HiSpace.md),
            // Deux actions claires : lancer le Mode guidé (chrono) ou valider la séance.
            HiButton(
              label: t.coachSessionGuidedMode,
              icon: Icons.play_circle_outline_rounded,
              onPressed: () => _openGuided(s),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// Lance le Mode guidé format-aware (GuidedSessionScreen) pour la séance. La complétion
  /// (crédit de série) se déclenche AUTOMATIQUEMENT à la fin du lecteur via onCompleted —
  /// plus de bouton « Marquer comme faite ».
  Future<void> _openGuided(CoachSession s) {
    return GuidedSessionScreen.fromCoach(
      context,
      session: s,
      onCompleted: () => _creditCoachSession(s),
    );
  }

  /// Crédit de série d'une séance terminée — appelé par le lecteur en fin de Mode guidé via
  /// onCompleted. VOIE CHOISIE : complétion PERSISTÉE côté serveur (POST
  /// /v1/coach/sessions/:id/complete), SANS routage vers la saisie de résultat. Raison : une
  /// [CoachSession] est une séance GUIDÉE clé en main (GET /v1/coach/library), distincte des
  /// ÉPREUVES loguables (WodCatalogEntry) ; elle n'a pas d'id de WOD ni de barème → l'API enregistre
  /// la complétion et CRÉDITE LA SÉRIE sans toucher l'Athlete Index.
  ///
  /// PEUT THROW si l'API échoue : le lecteur affiche alors l'état « échec » avec « réessayer »
  /// (on NE MENT PAS sur le crédit — la série n'est créditée que si la synchro aboutit).
  Future<void> _creditCoachSession(CoachSession s) async {
    final api = ref.read(apiClientProvider);
    // Persistance + crédit de série. PEUT THROW : le lecteur attrape et affiche l'état « échec »
    // avec un bouton « réessayer » (on ne crédite la série que si la synchro aboutit).
    final res = await api.completeCoachSession(s.id);
    final streakCredited = res.streakCredited;
    if (!mounted) return;

    final t = AppLocalizations.of(context);
    await Celebration.show(
      context,
      title: t.coachSessionDoneTitle,
      subtitle: t.coachSessionDoneSubtitle,
      icon: Icons.check_circle_rounded,
      accent: HiColors.accentVictory,
      intensity: CelebrationIntensity.light,
    );
    if (!mounted) return;
    // Message honnête : on ne confirme la série créditée QUE si l'API a réussi.
    final message = streakCredited ? t.coachSessionStreakCredited(s.name) : t.coachSessionSyncFailed;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _meta(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, color: color, size: 15)),
          const SizedBox(width: 4),
          Text(text, style: HiType.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      );

  IconData _intensityIcon(String i) {
    switch (i) {
      case 'high':
        return Icons.whatshot_rounded;
      case 'low':
        return Icons.spa_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _intensityColor(String i) {
    switch (i) {
      case 'high':
        return HiColors.error;
      case 'low':
        return HiColors.success;
      default:
        return HiColors.warn;
    }
  }

  String _intensityLabel(AppLocalizations t, String i) {
    switch (i) {
      case 'high':
        return t.coachIntensityHigh;
      case 'low':
        return t.coachIntensityLow;
      default:
        return t.coachIntensityMedium;
    }
  }

  Widget _skeleton() => ListView(
        padding: const EdgeInsets.fromLTRB(HiSpace.gutter, HiSpace.sm, HiSpace.gutter, 96),
        children: List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: HiSpace.sm),
            child: HiSkeleton(height: 132, radius: HiRadius.lg),
          ),
        ),
      );

  Widget _empty(AppLocalizations t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_run_rounded, color: HiColors.textTertiary, size: 40),
              const SizedBox(height: HiSpace.md),
              Text(t.coachLibraryEmpty,
                  textAlign: TextAlign.center,
                  style: HiType.body.copyWith(color: HiColors.textSecondary)),
            ],
          ),
        ),
      );
}
