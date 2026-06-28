import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
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
      // searchClubs('') = TOUS les clubs visibles (publics, rejoignables par n'importe qui).
      final r = await Future.wait([api.myClubs(), api.myClubInvites(), api.searchClubs('')]);
      if (mounted) setState(() => _results = r[2] as List<ClubSummary>);
      return (mine: r[0] as List<ClubSummary>, invites: r[1] as List<ClubInvite>);
    }();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      // Recherche vide → on réaffiche TOUS les clubs (et pas une liste vide).
      final res = await ref.read(apiClientProvider).searchClubs(v.trim());
      if (mounted) setState(() => _results = res);
    });
  }

  Future<void> _open(String clubId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubDetailScreen(clubId: clubId)));
    if (mounted) setState(_load);
  }

  Future<void> _createDialog() async {
    final t = AppLocalizations.of(context);
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HiColors.bgElevated,
        title: Text(t.clubsCreateTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: t.clubsNameLabel)),
          const SizedBox(height: 8),
          TextField(controller: desc, decoration: InputDecoration(labelText: t.clubsDescriptionLabel)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.clubsCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.clubsCreate)),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonGenericError)));
    }
  }

  Future<void> _decline(String inviteId) async {
    await ref.read(apiClientProvider).declineClubInvite(inviteId);
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.clubsTitle), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HiColors.brandPrimary,
        foregroundColor: HiColors.textOnBrand,
        onPressed: _createDialog,
        icon: const Icon(Icons.add),
        label: Text(t.clubsCreateTitle),
      ),
      body: SafeArea(
        child: FutureBuilder<({List<ClubSummary> mine, List<ClubInvite> invites})>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: HiColors.brandPrimary));
            }
            if (snap.hasError) return ErrorRetry(onRetry: () => setState(_load));
            final data = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(hintText: t.clubsSearchHint, prefixIcon: const Icon(Icons.search)),
                  onChanged: _onSearch,
                ),
                Builder(builder: (context) {
                  // « Tous les clubs » : tout ce qui est visible, SAUF ceux dont je suis déjà membre
                  // (ils apparaissent dans « Mes clubs »). Tap → fiche du club → bouton Rejoindre.
                  final mineIds = data.mine.map((m) => m.id).toSet();
                  final discover = _results.where((c) => !mineIds.contains(c.id)).toList();
                  if (discover.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: HiSpace.md),
                    Text(t.clubsDiscover, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                    const SizedBox(height: HiSpace.sm),
                    ...discover.map((c) => _clubTile(c, subtitle: t.clubsMembers(c.memberCount))),
                    Divider(color: HiColors.strokeSubtle, height: HiSpace.xl),
                  ]);
                }),
                if (data.invites.isNotEmpty) ...[
                  const SizedBox(height: HiSpace.md),
                  Text(t.clubsInvitations, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                  const SizedBox(height: HiSpace.sm),
                  ...data.invites.map(_inviteTile),
                ],
                const SizedBox(height: HiSpace.md),
                Text(t.clubsMine, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
                const SizedBox(height: HiSpace.sm),
                if (data.mine.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: HiSpace.md),
                    child: Text(t.clubsEmpty,
                        style: HiType.body.copyWith(color: HiColors.textTertiary)),
                  )
                else
                  ...data.mine.map((c) => _clubTile(c,
                      subtitle: c.role == 'owner'
                          ? t.clubsMembersOwner(c.memberCount)
                          : t.clubsMembers(c.memberCount))),
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
          leading: Icon(Icons.groups_rounded, color: HiColors.brandPrimary),
          title: Text(c.name, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
          subtitle: Text(subtitle, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
          trailing: Icon(Icons.chevron_right_rounded, color: HiColors.textTertiary),
          onTap: () => _open(c.id),
        ),
      );

  Widget _inviteTile(ClubInvite i) => Card(
        color: HiColors.bgElevated,
        child: ListTile(
          leading: Icon(Icons.mail_outline_rounded, color: HiColors.brandSecondaryText),
          title: Text(i.clubName, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
          subtitle: Text(AppLocalizations.of(context).clubsMembersInvite(i.memberCount),
              style: HiType.caption.copyWith(color: HiColors.textTertiary)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 34,
              child: HiButton(label: AppLocalizations.of(context).clubsView, onPressed: () => _open(i.clubId)),
            ),
            IconButton(icon: Icon(Icons.close_rounded, color: HiColors.textTertiary), onPressed: () => _decline(i.inviteId)),
          ]),
        ),
      );
}
