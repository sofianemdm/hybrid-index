import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/league_scope.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';
import 'progress_board_screen.dart';
import '../league/league_screen.dart';
import '../home/home_shell.dart';
import '../../data/ui_state.dart';

/// Classement public par ligue (Hommes / Femmes), trié par HYBRID INDEX.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  late String _sex;
  bool _manual = false; // l'utilisateur a choisi un onglet manuellement → on ne le force plus.
  late Future<Leaderboard> _future;

  @override
  void initState() {
    super.initState();
    _sex = ref.read(sessionProvider).sex ?? 'male';
    _load();
  }

  void _load() {
    // Périmètre PARTAGÉ (leagueScopeClubIdProvider) : null = 🌍 Ligue Mondiale ; sinon un club.
    // Sélectionné tout en haut de cet onglet et relu par la ligue du mois (LeagueScreen).
    _future = ref.read(apiClientProvider).leaderboard(
      _sex,
      limit: 100,
      clubId: ref.read(leagueScopeClubIdProvider),
    );
  }

  /// Change le périmètre partagé (🌍 Mondiale = null, ou un club) puis recharge le classement Index.
  /// La ligue du mois lira le même provider et se re-synchronisera à sa prochaine ouverture/build.
  void _selectScope(String? clubId) {
    if (clubId == ref.read(leagueScopeClubIdProvider)) return;
    HiHaptics.tap();
    ref.read(leagueScopeClubIdProvider.notifier).state = clubId;
    setState(_load);
  }

  void _switch(String sex) {
    _manual = true;
    if (sex == _sex) return;
    setState(() {
      _sex = sex;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Recharge le classement à CHAQUE ouverture de l'onglet Ligue. Le HomeShell utilise un
    // IndexedStack → cet écran reste monté en permanence, donc sans ça on réaffiche un instantané
    // périmé (ex. ton ancien Index) après avoir logué une séance ailleurs. Les autres comptes,
    // eux, voyaient déjà ta valeur fraîche → d'où l'incohérence « je me vois à 66, les autres à 97 ».
    ref.listen<int>(homeTabProvider, (prev, next) {
      if (next == kLeaderboardTabIndex && prev != next && mounted) setState(_load);
    });
    // Ouvre par défaut l'onglet du sexe de l'utilisateur (le sexe de session peut n'arriver
    // qu'après le 1er build). On ne force plus dès que l'utilisateur a choisi un onglet.
    if (!_manual) {
      final s = ref.watch(sessionProvider).sex;
      if (s != null && s != _sex) {
        _sex = s;
        _load();
      }
    }
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, HiSpace.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(t.leaderboardTitle, style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
            ),
          ),
          // Sélecteur de PÉRIMÈTRE partagé, tout en haut : 🌍 Ligue Mondiale + une puce par club.
          // N'apparaît que si l'utilisateur a ≥1 club. Filtre à la fois ce classement Index ET la
          // ligue du mois (via leagueScopeClubIdProvider).
          _scopeSelector(),
          // Explication claire de ce qu'est la Ligue dès l'arrivée sur la page.
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: HiColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t.leaderboardIntro,
                      style: HiType.caption.copyWith(color: HiColors.textSecondary, height: 1.35)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.sm),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(color: HiColors.brandPrimary.withValues(alpha: 0.5)),
                foregroundColor: HiColors.brandPrimary,
              ),
              icon: const Icon(Icons.local_fire_department),
              label: Text(t.leaderboardWeeklyProgress),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProgressBoardScreen()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.sm),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: HiColors.brandSecondary,
                foregroundColor: HiColors.textOnBrand,
              ),
              icon: const Icon(Icons.military_tech_rounded),
              label: const Text('Ligue du mois'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeagueScreen()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
            child: Row(
              children: [
                _tab(t.leaderboardMen, 'male'),
                const SizedBox(width: 8),
                _tab(t.leaderboardWomen, 'female'),
              ],
            ),
          ),
          const SizedBox(height: HiSpace.md),
          Expanded(
            child: FutureBuilder<Leaderboard>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, 96),
                    itemCount: 10,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const HiSkeleton(height: 44, radius: HiRadius.sm),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(HiSpace.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.leaderboard_rounded, color: HiColors.textTertiary, size: 40),
                          const SizedBox(height: HiSpace.md),
                          Text(t.leaderboardUnavailable,
                              textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
                          const SizedBox(height: HiSpace.md),
                          TextButton(onPressed: () => setState(_load), child: Text(t.leaderboardRetry)),
                        ],
                      ),
                    ),
                  );
                }
                final lb = snap.data!;
                if (lb.entries.isEmpty) {
                  return Center(
                      child: Text(t.leaderboardEmpty, style: TextStyle(color: HiColors.textTertiary)));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_load);
                    await _future; // l'indicateur reste jusqu'à l'arrivée réelle des données
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, 96),
                    itemCount: lb.entries.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: HiColors.strokeSubtle),
                    itemBuilder: (_, i) => _row(lb.entries[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Sélecteur de périmètre partagé (Ligue Mondiale + clubs de l'utilisateur). Clubs chargés via
  // myLeagueClubsProvider (best-effort). Masqué s'il n'a aucun club. Rangée défilante horizontale.
  Widget _scopeSelector() {
    final t = AppLocalizations.of(context);
    final clubs = ref.watch(myLeagueClubsProvider).asData?.value ?? const <ClubSummary>[];
    if (clubs.isEmpty) return const SizedBox.shrink();
    final current = ref.watch(leagueScopeClubIdProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _scopeChip(label: '🌍 ${t.leagueScopeWorld}', selected: current == null, onTap: () => _selectScope(null)),
            for (final club in clubs) ...[
              const SizedBox(width: HiSpace.sm),
              _scopeChip(label: '🛡️ ${club.name}', selected: current == club.id, onTap: () => _selectScope(club.id)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scopeChip({required String label, required bool selected, required VoidCallback onTap}) {
    final brand = HiColors.brandPrimary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(HiRadius.pill),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40), // cible tactile a11y
          padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? brand.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(HiRadius.pill),
            border: Border.all(color: brand.withValues(alpha: selected ? 0.6 : 0.35)),
          ),
          child: Text(
            label,
            style: HiType.caption.copyWith(
              color: selected ? HiColors.textPrimary : HiColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, String sex) {
    final active = _sex == sex;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: AppLocalizations.of(context).a11yLeaderboardTab(label),
        child: GestureDetector(
        onTap: () => _switch(sex),
        child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? HiColors.brandGradient : null,
            color: active ? null : HiColors.bgElevated2,
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
        ),
        ),
      ),
    );
  }

  Widget _row(LeaderboardEntry e) {
    final podium = e.position <= 3;
    final posColor = podium ? HiColors.rank(e.position == 1 ? 'gold' : e.position == 2 ? 'silver' : 'bronze') : HiColors.textTertiary;
    final t = AppLocalizations.of(context);
    // a11y : chaque ligne lue d'un bloc « Rang N, <nom>, Index X » (l'utilisateur courant annoncé
    // comme tel). Le contenu visuel (avatar, badge, chiffres) est décoratif → ExcludeSemantics.
    final rowLabel = e.isMe
        ? t.a11yLeaderboardRowMe(e.position, e.displayName, e.value)
        : t.a11yLeaderboardRow(e.position, e.displayName, e.value);
    return MergeSemantics(
      child: Semantics(
      button: true,
      selected: e.isMe,
      label: rowLabel,
      child: InkWell(
      borderRadius: BorderRadius.circular(HiRadius.sm),
      onTap: () {
        HiHaptics.tap();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: e.userId)),
        );
      },
      child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: e.isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(HiRadius.sm),
          border: e.isMe ? Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: podium
                  ? Icon(Icons.workspace_premium_rounded, color: posColor, size: 22)
                  : Text('#${e.position}', style: HiType.numericM.copyWith(color: posColor, fontSize: 16)),
            ),
            HiAvatar(
                config: e.avatar ?? const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1),
                rank: e.rank,
                size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      e.isMe ? AppLocalizations.of(context).leaderboardYou(e.displayName) : e.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: (e.isMe ? HiType.bodyStrong : HiType.body).copyWith(color: HiColors.textPrimary),
                    ),
                  ),
                  if (e.clubName != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(e.clubName!,
                          overflow: TextOverflow.ellipsis,
                          style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                    ),
                  ],
                ],
              ),
            ),
            RankBadge(rank: e.rank, ovr: e.value, fontSize: 11),
            const SizedBox(width: HiSpace.md),
            Text('${e.value}', style: HiType.numericM.copyWith(color: HiColors.textPrimary)),
          ],
        ),
      ),
      ),
      ),
      ),
    );
  }
}
