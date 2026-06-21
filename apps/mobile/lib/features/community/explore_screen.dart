import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';

const _ranks = ['rookie', 'bronze', 'silver', 'gold', 'platinum', 'diamond', 'elite'];

/// Recherche d'athlètes : filtres sexe / rang + nom → profil public.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String? _sex;
  String? _rank;
  String _q = '';
  Timer? _debounce;
  late Future<List<AthleteSummary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _load() {
    _future = ref.read(apiClientProvider).explore(sex: _sex, rank: _rank, q: _q.isEmpty ? null : _q);
  }

  void _onQueryChanged(String v) {
    _q = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(_load));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Athlètes'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(HiSpace.lg),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(hintText: 'Rechercher un pseudo', prefixIcon: Icon(Icons.search)),
                    onChanged: _onQueryChanged,
                  ),
                  const SizedBox(height: HiSpace.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip('Tous', _sex == null && _rank == null, () => setState(() {
                            _sex = null;
                            _rank = null;
                            _load();
                          })),
                      _chip('Hommes', _sex == 'male', () => setState(() {
                            _sex = 'male';
                            _load();
                          })),
                      _chip('Femmes', _sex == 'female', () => setState(() {
                            _sex = 'female';
                            _load();
                          })),
                      ..._ranks.map((r) => _chip(HiLabels.rank(r), _rank == r, () => setState(() {
                            _rank = _rank == r ? null : r;
                            _load();
                          }))),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AthleteSummary>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return Center(child: Text('Aucun athlète.', style: TextStyle(color: HiColors.textTertiary)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: HiColors.strokeSubtle),
                    itemBuilder: (_, i) => _row(items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: active,
        showCheckmark: false,
        selectedColor: HiColors.brandPrimary,
        backgroundColor: HiColors.bgElevated2,
        labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
        side: BorderSide(color: HiColors.strokeSubtle),
        onSelected: (_) => onTap(),
      );

  Widget _row(AthleteSummary a) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(a.displayName, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text('${HiLabels.goal(a.goal)} · Index ${a.index ?? '—'}', style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
        trailing: RankBadge(rank: a.rank, fontSize: 10),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: a.userId))),
      );
}
