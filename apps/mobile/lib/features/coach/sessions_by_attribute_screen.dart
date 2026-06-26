import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Bibliothèque de séances qui travaillent un attribut, triées par pertinence (la séance où
/// l'attribut compte le plus en tête). Atteint depuis le menu Séances (6 axes) et le radar Accueil.
class SessionsByAttributeScreen extends ConsumerStatefulWidget {
  final String attribute; // clé interne : engine/speed/strength/power/muscular_endurance/hybrid
  const SessionsByAttributeScreen({super.key, required this.attribute});

  @override
  ConsumerState<SessionsByAttributeScreen> createState() => _SessionsByAttributeScreenState();
}

class _SessionsByAttributeScreenState extends ConsumerState<SessionsByAttributeScreen> {
  late Future<List<CoachSession>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(apiClientProvider).coachLibrary(widget.attribute);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color = HiColors.attribute(widget.attribute);
    final label = HiLabels.attribute(widget.attribute);
    return Scaffold(
      appBar: AppBar(
        title: Text('${t.sessionsTitle} · $label'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<List<CoachSession>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: color));
            }
            if (snap.hasError) {
              return _errorRetry(t);
            }
            final sessions = snap.data ?? const <CoachSession>[];
            return RefreshIndicator(
              onRefresh: () async => setState(_load),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.md, HiSpace.lg, 96),
                children: [
                  // En-tête : barre d'accent de l'axe + phrase d'explication.
                  Container(
                    padding: const EdgeInsets.all(HiSpace.md),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(HiRadius.lg),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.fitness_center_rounded, color: color),
                        const SizedBox(width: HiSpace.md),
                        Expanded(
                          child: Text(t.sessionsAttributeHeader(label),
                              style: HiType.titleM.copyWith(color: HiColors.textPrimary, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(t.coachNoSessions,
                          textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                    )
                  else
                    ...sessions.map((s) => _SessionCard(session: s, accent: color)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _errorRetry(AppLocalizations t) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.coachLoadError, textAlign: TextAlign.center, style: TextStyle(color: HiColors.textSecondary)),
            const SizedBox(height: HiSpace.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(t.commonRetry),
              onPressed: () => setState(_load),
            ),
          ],
        ),
      );
}

/// Carte de séance : nom (+ étoile si l'axe est primaire), tags durée/intensité/matériel, description.
class _SessionCard extends StatelessWidget {
  final CoachSession session;
  final Color accent;
  const _SessionCard({required this.session, required this.accent});

  bool get _isPrimary => (session.weight ?? 0) >= 0.999;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final intensity = session.intensity == 'high'
        ? t.coachIntensityHigh
        : (session.intensity == 'medium' ? t.coachIntensityMedium : t.coachIntensityLow);
    return Card(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isPrimary) ...[
                  Icon(Icons.star_rounded, color: accent, size: 18),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(session.name,
                      style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
                _tag(t.coachDurationMin(session.durationMin), HiColors.textTertiary),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _tag(intensity, accent),
                const SizedBox(width: 6),
                _tag(session.requiresEquipment ? t.coachWithEquipment : t.coachNoEquipment,
                    session.requiresEquipment ? HiColors.warn : HiColors.success),
              ],
            ),
            const SizedBox(height: 8),
            Text(session.description,
                style: TextStyle(color: HiColors.textSecondary, fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(HiRadius.pill)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
