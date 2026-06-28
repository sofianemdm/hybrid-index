import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../wods/wod_detail_screen.dart';
import 'coach_library_screen.dart';

/// Les ÉPREUVES (WODs loguables) qui comptent pour le score d'un attribut, triées par contribution
/// (celle qui compte le plus en haut). On y arrive depuis le menu Séances (6 axes) et le radar Accueil.
/// Taper une épreuve → fiche détaillée → « Faire ce workout » → saisie du temps.
class SessionsByAttributeScreen extends ConsumerStatefulWidget {
  final String attribute; // clé interne : engine/speed/strength/power/muscular_endurance/hybrid
  const SessionsByAttributeScreen({super.key, required this.attribute});

  @override
  ConsumerState<SessionsByAttributeScreen> createState() => _SessionsByAttributeScreenState();
}

class _SessionsByAttributeScreenState extends ConsumerState<SessionsByAttributeScreen> {
  late Future<List<WodCatalogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(apiClientProvider).wodsCatalog();

  /// Épreuves de référence qui MESURENT cet attribut, triées : la plus « centrée » sur l'attribut
  /// d'abord (peu d'attributs visés ⇒ compte le plus), les grands défis remontent à contribution égale.
  List<WodCatalogEntry> _ranked(List<WodCatalogEntry> all) {
    int score(WodCatalogEntry w) => (100 - w.targetAttributes.length * 12) + (w.isFlagship ? 6 : 0);
    final list = all
        .where((w) => !w.isOther && !w.isCustom && w.targetAttributes.contains(widget.attribute))
        .toList()
      ..sort((a, b) {
        final s = score(b).compareTo(score(a));
        return s != 0 ? s : a.name.compareTo(b.name);
      });
    return list;
  }

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
        child: FutureBuilder<List<WodCatalogEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: color));
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.coachLoadError,
                        textAlign: TextAlign.center, style: TextStyle(color: HiColors.textSecondary)),
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
            final wods = _ranked(snap.data ?? const []);
            return RefreshIndicator(
              onRefresh: () async => setState(_load),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.md, HiSpace.lg, 96),
                children: [
                  Container(
                    padding: const EdgeInsets.all(HiSpace.md),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(HiRadius.lg),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events_rounded, color: color),
                        const SizedBox(width: HiSpace.md),
                        Expanded(
                          child: Text(t.sessionsAttributeHeader(label),
                              style: HiType.titleM.copyWith(color: HiColors.textPrimary, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HiSpace.md),
                  // Renvoi vers les séances GUIDÉES du coach pour cet axe (entraînements clés en
                  // main), distinctes des ÉPREUVES à loguer listées ci-dessous.
                  _guidedLink(color),
                  const SizedBox(height: HiSpace.lg),
                  _section(t.sessionsToLog),
                  if (wods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(t.coachNoSessions,
                          textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                    )
                  else
                    ...wods.asMap().entries.map((e) => _wodCard(e.value, color, e.key == 0)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: HiColors.textTertiary, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
      );

  /// Renvoi vers la bibliothèque de séances GUIDÉES (entraînements clés en main) pour cet axe.
  Widget _guidedLink(Color accent) {
    final t = AppLocalizations.of(context);
    return Material(
      color: HiColors.bgElevated,
      borderRadius: BorderRadius.circular(HiRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(HiRadius.md),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CoachLibraryScreen(attribute: widget.attribute)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(HiSpace.md),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: accent, size: 20),
              const SizedBox(width: HiSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.sessionsGuidedLinkTitle,
                        style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(t.sessionsGuidedLinkSubtitle,
                        style: TextStyle(color: HiColors.textTertiary, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// Carte d'épreuve loguable. `top` = celle qui compte le plus (mise en avant).
  Widget _wodCard(WodCatalogEntry w, Color accent, bool top) {
    final t = AppLocalizations.of(context);
    final key = w.targetAttributes.length <= 2; // épreuve très centrée sur cet axe
    return Padding(
      padding: const EdgeInsets.only(bottom: HiSpace.sm),
      child: Semantics(
      button: true,
      label: t.a11ySessionWod(w.name),
      child: MergeSemantics(
      child: Material(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(HiRadius.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: w.id, wodName: w.name)),
          ),
          child: Container(
            decoration: top
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(HiRadius.md),
                    border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
                  )
                : null,
            padding: const EdgeInsets.all(HiSpace.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(HiRadius.sm)),
                  child: Icon(w.scoreType == 'time' ? Icons.timer_outlined : Icons.repeat, color: accent, size: 20),
                ),
                const SizedBox(width: HiSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (top) ...[
                            Icon(Icons.star_rounded, color: accent, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(w.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _tag(w.requiresEquipment ? t.wodTabWithEquipment : t.wodTabNoEquipment,
                              w.requiresEquipment ? HiColors.warn : HiColors.success),
                          if (key) ...[
                            const SizedBox(width: 6),
                            _tag(t.sessionsCountsMost, accent),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
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
