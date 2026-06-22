import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/wod_catalog.dart';
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
    final bodyweight = wodCatalog.where((w) => !w.requiresEquipment).toList();
    final equipped = wodCatalog.where((w) => w.requiresEquipment).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Choisir une séance'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
          children: [
            Text('Choisis une séance pour voir en quoi elle consiste, les temps de référence et le classement — puis enregistre ton résultat.',
                style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
            const SizedBox(height: HiSpace.lg),
            _sectionTitle('Sans matériel'),
            ...bodyweight.map(_tile),
            const SizedBox(height: HiSpace.lg),
            _sectionTitle('Avec matériel'),
            ...equipped.map(_tile),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t, style: TextStyle(color: HiColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      );

  Widget _tile(WodCatalogItem w) => Card(
        color: HiColors.bgElevated,
        child: ListTile(
          title: Text(w.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text(w.requiresEquipment ? 'Avec matériel' : 'Sans matériel',
              style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
          trailing: Icon(Icons.chevron_right, color: HiColors.textTertiary),
          onTap: () => _open(w.id),
        ),
      );
}
