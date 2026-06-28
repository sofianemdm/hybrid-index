import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/hi_avatar.dart';
import '../home/rival_card.dart';
import '../profile/public_profile_screen.dart';
import '../wods/wod_detail_screen.dart';
import 'league_reveal_sheet.dart';
import 'month_format.dart';

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
    // REVEAL de fin de saison : déclenché APRÈS le 1er frame (contexte prêt), une seule fois par
    // saison close (mémorisé via shared_preferences). N'affiche rien s'il n'y a aucune saison close.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowReveal());
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    _season = api.leagueSeason();
    _standings = api.leagueStandings(_sex);
  }

  /// Clé « déjà vu » par saison close (monthKey). Ne montrer le reveal qu'UNE fois par saison.
  static String _revealSeenKey(String monthKey) => 'hi_league_reveal_seen_$monthKey';

  /// Charge le dernier résultat de saison close ; si non encore vu, présente le reveal et le marque vu.
  Future<void> _maybeShowReveal() async {
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.leagueLastResult();
      if (result == null || !mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final key = _revealSeenKey(result.monthKey);
      if (prefs.getBool(key) == true) return; // déjà vu cette saison
      if (!mounted) return;
      await LeagueRevealSheet.show(context, result);
      await prefs.setBool(key, true);
    } catch (_) {
      // Reveal best-effort : jamais bloquant pour l'écran Ligue.
    }
  }

  Future<void> _refresh() async {
    setState(_load);
    await _season;
    if (_standings != null) await _standings;
  }

  /// Change la ligue affichée (Hommes/Femmes) et re-fetch UNIQUEMENT le classement (la saison/WOD
  /// imposé sont communs aux deux ligues). No-op si on retoque le sexe déjà sélectionné.
  void _selectSex(String sex) {
    if (sex == _sex) return;
    HiHaptics.tap();
    setState(() {
      _sex = sex;
      _standings = ref.read(apiClientProvider).leagueStandings(_sex);
    });
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
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.leagueScreenTitle),
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
                  text: t.leagueUnavailable,
                  action: TextButton(onPressed: () => setState(_load), child: Text(t.leagueRetry)),
                );
              }
              final season = snap.data;
              if (season == null) {
                return _centered(
                  icon: Icons.hourglass_empty_rounded,
                  text: t.leagueNoSeason,
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.lg, HiSpace.lg, 96),
                children: [
                  _seasonHeader(season),
                  const SizedBox(height: HiSpace.md),
                  _explainerCard(),
                  const SizedBox(height: HiSpace.sm),
                  _howItWorks(),
                  const SizedBox(height: HiSpace.md),
                  if (season.currentWeek != null) ...[
                    _wodCard(season.currentWeek!),
                    const SizedBox(height: HiSpace.md),
                  ],
                  _rivalSection(season),
                  _sexSegmented(),
                  const SizedBox(height: HiSpace.md),
                  _standingsSection(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // RIVAL dans la Ligue — le rival amical (athlète juste au-dessus) vit AU-DESSUS du classement,
  // conformément au cahier (le rival est le cœur de l'expérience Ligue). Même source que l'Accueil
  // (myProfileProvider → Profile.rival / .leaguePosition) : aucune donnée dupliquée. Le widget
  // RivalCard gère seul l'état « tu es n°1 » (rival null) et porte déjà sa propre a11y Semantics.
  // Gating identique à l'Accueil : on n'affiche rien tant que l'athlète n'a pas de place en ligue.
  Widget _rivalSection(LeagueSeason season) {
    final t = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider).value;
    if (profile == null || profile.leaguePosition == null) return const SizedBox.shrink();
    final week = season.currentWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.leagueRivalTitle, style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
        const SizedBox(height: HiSpace.sm),
        RivalCard(
          rival: profile.rival,
          leaguePosition: profile.leaguePosition,
          // Déjà sur l'écran Ligue : un tap mène à l'action utile — refaire le WOD imposé pour
          // grappiller des points et dépasser le rival. Pas de WOD en cours ⇒ simple feedback tactile.
          onTap: () {
            if (week != null) {
              _doWeekWod(week);
            } else {
              HiHaptics.tap();
            }
          },
        ),
        const SizedBox(height: HiSpace.md),
      ],
    );
  }

  // En-tête : ligue + MOIS formaté (« Juin 2026 ») + compte à rebours + remise à zéro mensuelle.
  Widget _seasonHeader(LeagueSeason season) {
    final t = AppLocalizations.of(context);
    final daysLeft = season.closesAt.difference(DateTime.now()).inDays;
    final violet = HiColors.brandSecondary;
    final monthLabel = formatMonthKey(season.monthKey, Localizations.localeOf(context).toString());
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
              Text(_sex == 'female' ? t.leagueHeaderWomen : t.leagueHeaderMen,
                  style: HiType.caption.copyWith(color: HiColors.brandSecondaryText, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          Text(
            monthLabel,
            style: HiType.titleL.copyWith(color: HiColors.textPrimary, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            daysLeft <= 0 ? t.leagueLastDay : t.leagueEndsIn(daysLeft),
            style: HiType.body.copyWith(color: HiColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(t.leaguePointsReset,
              style: HiType.caption.copyWith(color: HiColors.textSecondary)),
        ],
      ),
    );
  }

  // « La Ligue du mois, c'est quoi ? » — explication claire en haut de page (ouverte à tous).
  Widget _explainerCard() {
    final t = AppLocalizations.of(context);
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
              Text(t.leagueExplainerTitle,
                  style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
            ],
          ),
          const SizedBox(height: HiSpace.sm),
          Text(
            t.leagueExplainerBody,
            style: HiType.body.copyWith(color: HiColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // D — Bloc dépliable « Comment ça marche ? » : règle du meilleur essai, reset mensuel, Index figé.
  Widget _howItWorks() {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: HiColors.bgElevated2,
        borderRadius: BorderRadius.circular(HiRadius.sm),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Retire les séparateurs par défaut de l'ExpansionTile (intégration au design sombre).
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: HiSpace.lg, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.md),
          iconColor: HiColors.brandSecondaryText,
          collapsedIconColor: HiColors.textTertiary,
          leading: Icon(Icons.help_outline_rounded, color: HiColors.brandSecondaryText, size: 20),
          title: Text(t.leagueHowItWorksTitle,
              style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
          children: [
            _howItWorksLine(Icons.emoji_events_outlined, t.leagueHowItWorksBest),
            const SizedBox(height: HiSpace.sm),
            _howItWorksLine(Icons.restart_alt_rounded, t.leagueHowItWorksReset),
            const SizedBox(height: HiSpace.sm),
            _howItWorksLine(Icons.lock_outline_rounded, t.leagueHowItWorksIndex),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: HiColors.brandSecondaryText, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: HiType.caption.copyWith(color: HiColors.textSecondary, height: 1.4)),
        ),
      ],
    );
  }

  // B — Bascule Hommes | Femmes : re-fetch le classement du sexe choisi (saison/WOD communs).
  Widget _sexSegmented() {
    final t = AppLocalizations.of(context);
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'male', label: Text(t.leagueSegmentMen), icon: const Icon(Icons.male_rounded, size: 16)),
        ButtonSegment(value: 'female', label: Text(t.leagueSegmentWomen), icon: const Icon(Icons.female_rounded, size: 16)),
      ],
      selected: {_sex},
      showSelectedIcon: false,
      onSelectionChanged: (s) => _selectSex(s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? HiColors.brandSecondary.withValues(alpha: 0.22) : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? HiColors.textPrimary : HiColors.textSecondary),
        side: WidgetStatePropertyAll(BorderSide(color: HiColors.brandSecondary.withValues(alpha: 0.45))),
      ),
    );
  }

  // Carte du WOD imposé de la semaine + CTA (ouvert à tous : faire le WOD classe directement).
  Widget _wodCard(LeagueWeekInfo week) {
    final t = AppLocalizations.of(context);
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
          Text(t.leagueWeekWod,
              style: HiType.caption.copyWith(color: HiColors.textTertiary, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(week.wodName, style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
          const SizedBox(height: HiSpace.sm),
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: HiColors.brandPrimary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.leagueWeekWodHint,
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
              label: Text(t.leagueDoThisWod),
              onPressed: () => _doWeekWod(week),
            ),
          ),
        ],
      ),
    );
  }

  // Classement du mois — visible par TOUS, avec « Ma position » (vide tant qu'on n'a pas fait le WOD).
  Widget _standingsSection() {
    final t = AppLocalizations.of(context);
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
                text: t.leagueStandingsUnavailable,
                action: TextButton(onPressed: () => setState(_load), child: Text(t.leagueRetry)),
              );
            }
            final s = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _myCard(s),
                const SizedBox(height: HiSpace.md),
                Text(t.leagueStandingsTitle, style: HiType.bodyStrong.copyWith(color: HiColors.textPrimary)),
                const SizedBox(height: HiSpace.sm),
                if (s.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: HiSpace.lg),
                    child: Text(t.leagueStandingsEmpty,
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
    final t = AppLocalizations.of(context);
    final pos = s.myPosition;
    final pts = s.myPoints ?? 0;
    // a11y : « Tu es 3e avec N points » plutôt que « #3 » et « N pts » lus séparément.
    final myLabel = pos == null
        ? '${t.leagueMyPosition}. ${t.leagueDoWodToEnter}'
        : t.a11yLeagueMyPosition(pos, pts);
    return Semantics(
      label: myLabel,
      child: ExcludeSemantics(
      child: Container(
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
              Text(t.leagueMyPosition, style: HiType.caption.copyWith(color: HiColors.brandSecondaryText, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(pos == null ? '—' : '#$pos', style: HiType.titleL.copyWith(color: HiColors.textPrimary)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(t.leaguePts(pts), style: HiType.numericM.copyWith(color: HiColors.textPrimary, fontSize: 20)),
              const SizedBox(height: 2),
              Text(pos == null ? t.leagueDoWodToEnter : t.leagueThisMonth,
                  style: HiType.caption.copyWith(color: HiColors.textSecondary)),
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _row(LeagueStandingEntry e) {
    final t = AppLocalizations.of(context);
    final podium = e.position <= 3;
    final posColor = podium
        ? HiColors.rank(e.position == 1 ? 'gold' : e.position == 2 ? 'silver' : 'bronze')
        : HiColors.textTertiary;
    // a11y : ligne entière (rang + nom + club + points) lue d'un trait, comme un bouton vers le profil.
    final rowLabel = t.a11yLeagueRow(e.position, e.isMe ? t.leagueRowYou(e.displayName) : e.displayName, e.points);
    return Semantics(
      button: true,
      label: rowLabel,
      child: ExcludeSemantics(
      child: InkWell(
      borderRadius: BorderRadius.circular(HiRadius.sm),
      onTap: () {
        HiHaptics.tap();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: e.userId)),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48), // cible tactile a11y >= 48dp
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
                      e.isMe ? t.leagueRowYou(e.displayName) : e.displayName,
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
            Text(t.leaguePts(e.points), style: HiType.numericM.copyWith(color: HiColors.textPrimary)),
          ],
        ),
      ),
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
