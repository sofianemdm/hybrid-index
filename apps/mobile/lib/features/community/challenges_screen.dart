import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/wod_catalog.dart';
import '../../theme/tokens.dart';

/// Défis : liste (envoyés/reçus) + accepter/refuser/vérifier + créer un défi sur un WOD fait.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  late Future<List<Challenge>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(apiClientProvider).challenges();

  Future<void> _action(Future<void> Function() fn, String ok) async {
    try {
      await fn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
        setState(_load);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _resolve(Challenge c) async {
    try {
      final res = await ref.read(apiClientProvider).resolveChallenge(c.id);
      if (!mounted) return;
      final beaten = res['beaten'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(beaten ? 'Défi remporté 🔥' : 'Pas encore battu — continue !')),
      );
      setState(_load);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _create() async {
    final results = await ref.read(apiClientProvider).results();
    if (!mounted) return;
    final doneWodIds = <String>{...results.map((r) => r.wodId)}.toList();
    if (doneWodIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fais d’abord un WOD pour pouvoir défier dessus.')));
      return;
    }
    final wodId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: doneWodIds.map((id) {
            final match = wodCatalog.where((w) => w.id == id);
            final name = match.isEmpty ? id : match.first.name;
            return ListTile(
              title: Text(name, style: const TextStyle(color: HiColors.textPrimary)),
              onTap: () => Navigator.of(context).pop(id),
            );
          }).toList(),
        ),
      ),
    );
    if (wodId == null) return;
    await _action(() => ref.read(apiClientProvider).createChallenge(wodId: wodId), 'Défi ouvert créé 💪');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Défis'), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HiColors.brandPrimary,
        foregroundColor: HiColors.textOnBrand,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau défi'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Challenge>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: const TextStyle(color: HiColors.error)));
            final items = snap.data!;
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(HiSpace.lg),
                  child: Text('Aucun défi. Lance-en un sur un WOD que tu as fait !',
                      textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(HiSpace.lg),
              children: items.map(_card).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _card(Challenge c) {
    return Container(
      margin: const EdgeInsets.only(bottom: HiSpace.sm),
      padding: const EdgeInsets.all(HiSpace.md),
      decoration: BoxDecoration(
        color: HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sports_kabaddi, color: HiColors.brandSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(c.wodName, style: const TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700))),
            _statusChip(c.status),
          ]),
          const SizedBox(height: 4),
          Text(c.iAmCreator ? 'Ton défi → ${c.toName}' : 'Défi de ${c.fromName}',
              style: const TextStyle(color: HiColors.textSecondary, fontSize: 13)),
          const SizedBox(height: HiSpace.sm),
          Row(
            children: [
              if (c.iAmChallenged && c.status == 'pending') ...[
                _btn('Accepter', () => _action(() => ref.read(apiClientProvider).acceptChallenge(c.id), 'Défi accepté')),
                const SizedBox(width: 8),
                _btn('Refuser', () => _action(() => ref.read(apiClientProvider).declineChallenge(c.id), 'Défi refusé'), outline: true),
              ],
              if (c.status == 'accepted' || c.status == 'pending') ...[
                const SizedBox(width: 8),
                _btn('Vérifier', () => _resolve(c), outline: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = {
      'pending': 'En attente',
      'accepted': 'Accepté',
      'completed': 'Remporté',
      'declined': 'Refusé',
      'expired': 'Expiré',
    }[status] ?? status;
    final color = status == 'completed' ? HiColors.success : status == 'declined' || status == 'expired' ? HiColors.textTertiary : HiColors.brandPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(HiRadius.pill)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool outline = false}) {
    return outline
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: HiColors.strokeStrong), foregroundColor: HiColors.textSecondary),
            onPressed: onTap,
            child: Text(label))
        : FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HiColors.brandPrimary, foregroundColor: HiColors.textOnBrand),
            onPressed: onTap,
            child: Text(label));
  }
}
