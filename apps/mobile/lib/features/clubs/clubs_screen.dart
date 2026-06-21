import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
import 'club_detail_screen.dart';

/// Clubs : mes clubs + invitations + création + recherche pour rejoindre.
class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({super.key});

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> {
  late Future<({List<ClubSummary> mine, List<ClubInvite> invites})> _future;
  final _search = TextEditingController();
  Timer? _debounce;
  List<ClubSummary> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    _future = () async {
      final r = await Future.wait([api.myClubs(), api.myClubInvites()]);
      return (mine: r[0] as List<ClubSummary>, invites: r[1] as List<ClubInvite>);
    }();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (v.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      final res = await ref.read(apiClientProvider).searchClubs(v.trim());
      if (mounted) setState(() => _results = res);
    });
  }

  Future<void> _open(String clubId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubDetailScreen(clubId: clubId)));
    if (mounted) setState(_load);
  }

  Future<void> _createDialog() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text('Créer un club', style: TextStyle(color: HiColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom du club')),
          const SizedBox(height: 8),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description (option)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true || name.text.trim().length < 3) return;
    try {
      final club = await ref.read(apiClientProvider).createClub(name.text.trim(), description: desc.text.trim());
      if (!mounted) return;
      setState(_load);
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubDetailScreen(clubId: club.id)));
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _decline(String inviteId) async {
    await ref.read(apiClientProvider).declineClubInvite(inviteId);
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clubs'), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HiColors.brandPrimary,
        foregroundColor: HiColors.textOnBrand,
        onPressed: _createDialog,
        icon: const Icon(Icons.add),
        label: const Text('Créer un club'),
      ),
      body: SafeArea(
        child: FutureBuilder<({List<ClubSummary> mine, List<ClubInvite> invites})>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
            final data = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(hintText: 'Rechercher un club à rejoindre', prefixIcon: Icon(Icons.search)),
                  onChanged: _onSearch,
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: HiSpace.sm),
                  ..._results.map((c) => _clubTile(c, subtitle: '${c.memberCount} membres')),
                  Divider(color: HiColors.strokeSubtle),
                ],
                if (data.invites.isNotEmpty) ...[
                  const SizedBox(height: HiSpace.md),
                  Text('Invitations', style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: HiSpace.sm),
                  ...data.invites.map(_inviteTile),
                ],
                const SizedBox(height: HiSpace.md),
                Text('Mes clubs', style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
                const SizedBox(height: HiSpace.sm),
                if (data.mine.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: HiSpace.md),
                    child: Text('Tu n\'es dans aucun club. Crée le tien ou rejoins-en un 👥',
                        style: TextStyle(color: HiColors.textTertiary)),
                  )
                else
                  ...data.mine.map((c) => _clubTile(c, subtitle: '${c.memberCount} membres${c.role == 'owner' ? ' · créateur' : ''}')),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _clubTile(ClubSummary c, {required String subtitle}) => Card(
        color: HiColors.bgElevated,
        child: ListTile(
          leading: Icon(Icons.groups, color: HiColors.brandPrimary),
          title: Text(c.name, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
          trailing: Icon(Icons.chevron_right, color: HiColors.textTertiary),
          onTap: () => _open(c.id),
        ),
      );

  Widget _inviteTile(ClubInvite i) => Card(
        color: HiColors.bgElevated,
        child: ListTile(
          leading: Icon(Icons.mail_outline, color: HiColors.brandSecondaryText),
          title: Text(i.clubName, style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text('${i.memberCount} membres · t\'invite', style: TextStyle(color: HiColors.textTertiary, fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 34,
              child: HiButton(label: 'Voir', onPressed: () => _open(i.clubId)),
            ),
            IconButton(icon: Icon(Icons.close, color: HiColors.textTertiary), onPressed: () => _decline(i.inviteId)),
          ]),
        ),
      );
}
