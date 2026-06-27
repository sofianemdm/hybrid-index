import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/hi_avatar.dart';
import '../profile/public_profile_screen.dart';
import '../wods/wod_detail_screen.dart';

/// Mode LIGUE — compétition mensuelle OUVERTE À TOUS, SÉPARÉE de l'Index.
/// Pas d'inscription : tout le monde est classé dès qu'il fait le WOD imposé de la semaine.
/// Signature visuelle violette (`brandSecondary`) pour ne jamais confondre avec l'Index (cyan).
/// Les points repartent à zéro chaque mois ; l'Index, lui, ne bouge jamais ici.
class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> {
  late String _sex;
  late Future<LeagueSeason?> _season;
  Future<LeagueStandings>? _standings;

  @override
  void initState() {
    super.initState();
    _sex = ref.read(sessionProvider).sex ?? 'male';
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    _season = api.leagueSeason();
    _standings = api.leagueStandings(_sex);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _season;
    if (_standings != null) await _standings;
  }

  /// Ouvre DIRECTEMENT le WOD imposé de la semaine (pas un sélecteur générique).
  Future<void> _doWeekWod(LeagueWeekInfo week) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WodDetailScreen(wodId: week.wodId, wodName: week.wodName)),
    );
    if (mounted) setState(_load); // rafraîchit le classement au retour
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ligue du mois'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<LeagueSeason?>(
            future: _season,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
                  children: const [
                    HiSkeleton(height: 120, radius: HiRadius.sm),
                    SizedBox(height: HiSpace.md),
                    HiSkeleton(height: 90, radius: HiRadius.sm),
                    SizedBox(height: HiSpace.md),
                    HiSkeleton(height: 44, radius: HiRadius.sm),
                  ],
                );
              }
              if (snap.hasError) {
                return _centered(
                  icon: Icons.military_tech_rounded,
                  text: 'Ligue indisponible pour le moment.',
                  action: TextButton(onPressed: () => setState(_load), child: const Text('Réessayer')),
                );
              }
              final season = snap.data;
              if (season == null) {
                return _centered(
                  icon: Icons.hourglass_empty_rounded,
                  text: 'Aucune saison de Ligue en cours.\nReviens bientôt : une nouvelle saison démarre chaque mois.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
                children: [
                  _seasonHeader(season),
                  const SizedBox(height: HiSpace.md),
                  _explainerCard(),
                  const SizedBox(height: HiSpace.md),
                  if (season.currentWeek != null) ...[
                    _wodCard(season.currentWeek!),
                    const SizedBox(height: HiSpace.md),
                  ],
                  _standingsSection(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // En-tête : mois + compte à rebours + rappel de la remise à zéro mensuelle.
  Widget _seasonHeader(LeagueSeason season) {
    final daysLeft = season.closesAt.difference(DateTime.now()).inDays;
    final violet = HiColors.brandSecondary;
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [violet.withValues(alpha: 0.28), HiColors.bgElevated2],
        ),
        borderRadius: BorderRadius.circular(HiRadius.sm),
        border: Border.all(color: violet.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded, color: HiColors.brandSecondaryText, size: 22),
              const SizedBox(width: 8),
              Text('LIGUE ${_sex == 'female' ? 'FEMME' : 'HOMME'}',
                  style: HiType.caption.copyWith(color: HiColors.brandSecondaryText, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          Text(
            daysLeft <= 0 ? 'Dernier jour de la saison' : 'Se termine dans $daysLeft jour${daysLeft > 1 ? 's' : ''}',
            style: HiType.titleL.copyWith(color: HiColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text('Les points repartent à zéro chaque mois.',
              style: HiType.caption.copyWith(color: HiColors.textSecondary)),
        ],
      ),
    );
  }

  // « La Ligue du mois, c'est quoi ? » — explication claire en haut de page (ouverte à tous).
  Widget _explainerCard() {
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.sm),
        border: Border.all(color: HiColors.brandSecondary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: HiColors.brandSecondaryText, size: 18),
              const SizedBox(width: 8),
              Text('La Ligue du mois, c\'est quoi ?',
                  style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          Text(
            'Chaque mois, une nouvelle saison. Tu es classé AUTOMATIQUEMENT parmi les athlètes de ton '
            'sexe. Fais la séance imposée de la semaine : tu marques des points selon ta performance. '
            'Les points de Ligue repartent à zéro chaque mois.',
            style: HiType.body.copyWith(color: HiColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // Carte du WOD imposé de la semaine + CTA (ouvert à tous : faire le WOD classe directement).
  Widget _wodCard(LeagueWeekInfo week) {
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.sm),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SÉANCE DE LA SEMAINE',
              style: HiType.caption.copyWith(color: HiColors.textTertiary, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(week.wodName, style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
          const SizedBox(height: HiSpace.sm),
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: HiColors.brandPrimary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text('La séance imposée de la semaine — donne tout pour grimper au classement.',
                    style: HiType.caption.copyWith(color: HiColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: HiSpace.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: HiColors.brandSecondary,
                foregroundColor: HiColors.textOnBrand,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Faire cette séance'),
              onPressed: () => _doWeekWod(week),
            ),
          ),
        ],
      ),
    );
  }

  // Classement du mois — visible par TOUS, avec « Ma position » (vide tant qu'on n'a pas fait le WOD).
  Widget _standingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<LeagueStandings>(
          future: _standings,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const HiSkeleton(height: 200, radius: HiRadius.sm);
            }
            if (snap.hasError || snap.data == null) {
              return _centered(
                icon: Icons.military_tech_rounded,
                text: 'Classement indisponible.',
                action: TextButton(onPressed: () => setState(_load), child: const Text('Réessayer')),
              );
            }
            final s = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _myCard(s),
                const SizedBox(height: HiSpace.md),
                Text('Classement du mois', style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.sm),
                if (s.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: HiSpace.lg),
                    child: Text('Personne n\'a encore marqué ce mois-ci. Sois le premier !',
                        style: HiType.body.copyWith(color: HiColors.textTertiary)),
                  )
                else
                  ...s.entries.map(_row),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _myCard(LeagueStandings s) {
    final pos = s.myPosition;
    final pts = s.myPoints ?? 0;
    return Container(
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        color: HiColors.brandSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HiRadius.sm),
        border: Border.all(color: HiColors.brandSecondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MA POSITION', style: HiType.caption.copyWith(color: HiColors.brandSecondaryText, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(pos == null ? '—' : '#$pos', style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$pts pts', style: HiType.numericM.copyWith(color: HiColors.textPrimary, fontSize: 20)),
              const SizedBox(height: 2),
              Text(pos == null ? 'Fais la séance pour entrer au classement' : 'ce mois-ci',
                  style: HiType.caption.copyWith(color: HiColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(LeagueStandingEntry e) {
    final podium = e.position <= 3;
    final posColor = podium
        ? HiColors.rank(e.position == 1 ? 'gold' : e.position == 2 ? 'silver' : 'bronze')
        : HiColors.textTertiary;
    return InkWell(
      borderRadius: BorderRadius.circular(HiRadius.sm),
      onTap: () {
        HiHaptics.tap();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: e.userId)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: e.isMe ? HiColors.brandSecondary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(HiRadius.sm),
          border: e.isMe ? Border.all(color: HiColors.brandSecondary.withValues(alpha: 0.5)) : null,
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
                rank: 'rookie',
                size: 26,
                showRing: false),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      e.isMe ? '${e.displayName} (moi)' : e.displayName,
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
            Text('${e.points} pts', style: HiType.numericM.copyWith(color: HiColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _centered({required IconData icon, required String text, Widget? action}) {
    return ListView(
      padding: const EdgeInsets.all(HiSpace.lg),
      children: [
        const SizedBox(height: 80),
        Icon(icon, color: HiColors.textTertiary, size: 44),
        const SizedBox(height: HiSpace.md),
        Text(text, textAlign: TextAlign.center, style: HiType.body.copyWith(color: HiColors.textSecondary)),
        if (action != null) ...[const SizedBox(height: HiSpace.md), Center(child: action)],
      ],
    );
  }
}
