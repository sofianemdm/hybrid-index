import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'wod_detail_screen.dart';
import 'other_workouts_screen.dart';
import '../history/history_screen.dart';
import '../coach/sessions_by_attribute_screen.dart';
import '../../widgets/glossary_text.dart';

/// Onglet WOD : catalogue des WODs (15 références + communautaires à venir).
class WodTab extends ConsumerStatefulWidget {
  const WodTab({super.key});

  @override
  ConsumerState<WodTab> createState() => _WodTabState();
}

class _WodTabState extends ConsumerState<WodTab> {
  late Future<List<WodCatalogEntry>> _future;
  late Future<CoachSession> _weekly;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).wodsCatalog();
    _weekly = ref.read(apiClientProvider).weeklySession();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(() {
          _future = ref.read(apiClientProvider).wodsCatalog();
          _weekly = ref.read(apiClientProvider).weeklySession();
        }),
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
            // « Autre » et séances communautaires (custom) sont rangées à part (écran « Autres épreuves »).
            final all = snap.data!.where((w) => !w.isOther && !w.isCustom).toList();
            final phares = all.where((w) => w.isFlagship).toList();
            final sansMateriel = all.where((w) => !w.requiresEquipment && !w.isFlagship).toList();
            final avecMateriel = all.where((w) => w.requiresEquipment && !w.isFlagship).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Text(t.wodTabTitle,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HiColors.textPrimary)),
                const SizedBox(height: 4),
                Text(t.wodTabSubtitle,
                    style: TextStyle(color: HiColors.textSecondary)),
                const SizedBox(height: HiSpace.md),
                _historyButton(context),
                const SizedBox(height: HiSpace.lg),
                // Séance de la semaine (Le Forgeron) + accès aux séances par axe (les 6 attributs).
                _section(t.sessionsWeeklyTitle),
                _weeklyCard(),
                const SizedBox(height: HiSpace.lg),
                _section(t.sessionsByFocus),
                _attributeGrid(context),
                const SizedBox(height: HiSpace.lg),
                if (phares.isNotEmpty) ...[
                  _section(t.wodTabFlagshipSection),
                  Padding(
                    padding: const EdgeInsets.only(bottom: HiSpace.sm),
                    child: Text(t.wodTabFlagshipCaption,
                        style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
                  ),
                  ...phares.map((w) => _card(w, flagship: true)),
                  const SizedBox(height: HiSpace.lg),
                ],
                if (sansMateriel.isNotEmpty) ...[
                  _section(t.wodTabNoEquipment),
                  ...sansMateriel.map(_card),
                  const SizedBox(height: HiSpace.lg),
                ],
                if (avecMateriel.isNotEmpty) ...[
                  _section(t.wodTabWithEquipment),
                  ...avecMateriel.map(_card),
                ],
                const SizedBox(height: HiSpace.lg),
                Builder(
                  builder: (context) => Card(
                    color: HiColors.bgElevated,
                    child: ListTile(
                      leading: const Text('🌍', style: TextStyle(fontSize: 20)),
                      title: Text(t.wodTabOtherTitle, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                      subtitle: Text(t.wodTabOtherSubtitle,
                          style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: HiColors.textTertiary),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OtherWorkoutsScreen()),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Raccourci vers l'historique des séances loggées (avec suppression).
  Widget _historyButton(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: HiColors.strokeStrong),
          foregroundColor: HiColors.textPrimary,
        ),
        icon: const Icon(Icons.history),
        label: Text(AppLocalizations.of(context).wodTabMyHistory),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        ),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t.toUpperCase(),
            style: TextStyle(color: HiColors.textTertiary, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
      );

  /// Carte « séance de la semaine » (Le Forgeron). Masquée en cas d'erreur (non bloquant).
  Widget _weeklyCard() {
    return FutureBuilder<CoachSession>(
      future: _weekly,
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final s = snap.data;
        if (s == null) {
          return const SizedBox(height: 84, child: Center(child: CircularProgressIndicator()));
        }
        return Container(
          padding: const EdgeInsets.all(HiSpace.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              HiColors.brandPrimary.withValues(alpha: 0.14),
              HiColors.brandSecondary.withValues(alpha: 0.10),
            ]),
            borderRadius: BorderRadius.circular(HiRadius.lg),
            border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: HiColors.brandPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.name,
                        style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: HiColors.brandPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(HiRadius.pill)),
                    child: Text('${s.durationMin} min',
                        style: TextStyle(color: HiColors.brandPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GlossaryText(s.description, style: TextStyle(color: HiColors.textSecondary, fontSize: 13, height: 1.4)),
            ],
          ),
        );
      },
    );
  }

  /// Les 6 axes (attributs) → bibliothèque de séances triées pour cet axe.
  Widget _attributeGrid(BuildContext context) {
    const attrs = ['engine', 'speed', 'strength', 'power', 'muscular_endurance', 'hybrid'];
    const icons = {
      'engine': Icons.favorite_rounded,
      'speed': Icons.bolt_rounded,
      'strength': Icons.fitness_center_rounded,
      'power': Icons.flash_on_rounded,
      'muscular_endurance': Icons.timelapse_rounded,
      'hybrid': Icons.all_inclusive_rounded,
    };
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: attrs.map((a) {
        final color = HiColors.attribute(a);
        return Material(
          color: HiColors.bgElevated,
          borderRadius: BorderRadius.circular(HiRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(HiRadius.md),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SessionsByAttributeScreen(attribute: a)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HiRadius.md),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(HiRadius.sm)),
                    child: Icon(icons[a], color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(HiLabels.attribute(a),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _card(WodCatalogEntry w, {bool flagship = false}) {
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
          child: Container(
            decoration: flagship
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(HiRadius.md),
                    border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.6), width: 1.5),
                  )
                : null,
            padding: const EdgeInsets.all(HiSpace.md),
            child: Row(
              children: [
                Icon(flagship ? Icons.star : (w.scoreType == 'time' ? Icons.timer_outlined : Icons.repeat),
                    color: HiColors.brandPrimary),
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
