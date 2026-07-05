import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/wod_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../wods/wod_detail_screen.dart';

/// Choix d'une séance de référence : on ouvre la fiche complète (énoncé, paliers, références
/// pro/débutant/intermédiaire, classement, mon historique) où l'on peut enregistrer son résultat.
class LogWodScreen extends ConsumerStatefulWidget {
  /// Pré-ouvre directement la fiche d'un WOD (ex. depuis « Faire cette séance »).
  final String? initialWodId;
  const LogWodScreen({super.key, this.initialWodId});

  @override
  ConsumerState<LogWodScreen> createState() => _LogWodScreenState();
}

class _LogWodScreenState extends ConsumerState<LogWodScreen> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    // Si une séance est pré-sélectionnée, on ouvre directement sa fiche.
    if (widget.initialWodId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(widget.initialWodId!));
    }
  }

  Future<void> _open(String id) async {
    if (_opened) return;
    _opened = true;
    final item = wodCatalog.firstWhere((w) => w.id == id, orElse: () => wodCatalog.first);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: item.id, wodName: item.name)),
    );
    _opened = false;
    if (mounted && widget.initialWodId != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bodyweight = wodCatalog.where((w) => !w.requiresEquipment).toList();
    final equipped = wodCatalog.where((w) => w.requiresEquipment).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.logWodTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
          children: [
            Text(t.logWodIntro,
                style: HiType.body.copyWith(color: HiColors.textSecondary)),
            const SizedBox(height: HiSpace.sm),
            // Rappel fair-play discret, avant l'effort (touchpoint calme, non culpabilisant).
            Row(
              children: [
                Icon(Icons.favorite_outline_rounded, size: 14, color: HiColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t.logWodFairPlay,
                      style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                ),
              ],
            ),
            const SizedBox(height: HiSpace.lg),
            _sectionTitle(t.logWodNoEquipment),
            ...bodyweight.map((w) => _tile(context, w)),
            const SizedBox(height: HiSpace.lg),
            _sectionTitle(t.logWodWithEquipment),
            ...equipped.map((w) => _tile(context, w)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
      );

  Widget _tile(BuildContext context, WodCatalogItem w) {
    final t = AppLocalizations.of(context);
    return Card(
      color: HiColors.bgElevated,
      child: ListTile(
        title: Text(w.name, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        subtitle: Text(w.requiresEquipment ? t.logWodWithEquipment : t.logWodNoEquipment,
            style: HiType.caption.copyWith(color: HiColors.textTertiary)),
        trailing: Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
        onTap: () => _open(w.id),
      ),
    );
  }
}
