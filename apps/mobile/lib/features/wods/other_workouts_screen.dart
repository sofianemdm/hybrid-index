import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_skeleton.dart';
import 'wod_detail_screen.dart';

/// « Autre » : épreuves réelles (HYROX solo, WODs de compét, courses) — présentées comme les
/// séances (séparation matériel / sans), noms seuls ; au clic, fiche complète + on peut la faire.
class OtherWorkoutsScreen extends ConsumerStatefulWidget {
  const OtherWorkoutsScreen({super.key});

  @override
  ConsumerState<OtherWorkoutsScreen> createState() => _OtherWorkoutsScreenState();
}

class _OtherWorkoutsScreenState extends ConsumerState<OtherWorkoutsScreen> {
  late Future<List<WodCatalogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).wodsCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.otherWorkoutsTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<List<WodCatalogEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const HiListSkeleton(count: 5, itemHeight: 88);
            }
            if (snap.hasError) {
              return ErrorRetry(onRetry: () => setState(() {
                _future = ref.read(apiClientProvider).wodsCatalog();
              }));
            }
            final others = (snap.data ?? []).where((w) => w.isOther).toList();
            final sans = others.where((w) => !w.requiresEquipment).toList();
            final avec = others.where((w) => w.requiresEquipment).toList();
            final community = (snap.data ?? []).where((w) => w.isCustom).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                Text(t.otherWorkoutsIntro,
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                const SizedBox(height: HiSpace.lg),
                if (sans.isNotEmpty) ...[
                  _section(t.otherWorkoutsNoEquipment),
                  ...sans.map((w) => _tile(context, w)),
                  const SizedBox(height: HiSpace.lg),
                ],
                if (avec.isNotEmpty) ...[
                  _section(t.otherWorkoutsWithEquipment),
                  ...avec.map((w) => _tile(context, w)),
                  const SizedBox(height: HiSpace.lg),
                ],
                _section(t.otherWorkoutsCommunitySection),
                if (community.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HiSpace.sm),
                    child: Text(t.otherWorkoutsCommunityEmpty,
                        style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  )
                else
                  ...community.map((w) => _tile(context, w)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t, style: HiType.label.copyWith(color: HiColors.textTertiary, fontWeight: FontWeight.w700)),
      );

  Widget _tile(BuildContext context, WodCatalogEntry w) => Card(
        color: HiColors.bgElevated,
        child: ListTile(
          title: Text(w.name, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
          trailing: Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: w.id, wodName: w.name)),
          ),
        ),
      );
}
