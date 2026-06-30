import 'package:flutter/material.dart';

import '../../core/timeago.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';
import '../wods/wod_detail_screen.dart';
import '../wods/wod_format.dart';
import 'mention_text.dart';

/// Carte d'activité PARTAGÉE (feed Communauté + « mur » du profil public). Centralise le rendu
/// (avatar, en-tête, corps avec mentions cliquables, perf, kudos 👏, commentaires) ET le toggle
/// kudos OPTIMISTE pour ne PAS dupliquer la logique entre les écrans. Les actions « lourdes »
/// (menu Signaler/Bloquer/Supprimer, ouverture des commentaires) sont déléguées à l'appelant via
/// des callbacks optionnels — un écran qui ne les fournit pas n'affiche tout simplement pas ces
/// affordances (le mur de profil n'a pas de menu modération, par ex.).
class FeedPostCard extends StatefulWidget {
  const FeedPostCard({
    super.key,
    required this.activity,
    required this.onToggleKudos,
    this.onOpenComments,
    this.onMenu,
    this.onFollow,
  });

  final FeedActivity activity;

  /// Toggle kudos asynchrone (réseau). Renvoie `true` si le serveur a confirmé, `false` si échec
  /// (la carte annule alors sa mise à jour optimiste). Fourni par l'appelant qui détient l'API.
  final Future<bool> Function(FeedActivity a, bool wantOn) onToggleKudos;

  /// Ouvre le fil de commentaires (posts uniquement). Null = bouton commentaire masqué.
  final void Function(FeedActivity a)? onOpenComments;

  /// Menu de la carte (Signaler / Bloquer / Supprimer). Null = pas de menu (ex. mur de profil).
  final void Function(FeedActivity a)? onMenu;

  /// Bouton « Suivre » d'une carte « Découvrir ». Null = carte standard.
  final void Function(FeedActivity a)? onFollow;

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  bool _kudosBusy = false;

  FeedActivity get a => widget.activity;

  Future<void> _toggleKudos() async {
    if (_kudosBusy || a.isMe) return;
    final t = AppLocalizations.of(context);
    final had = a.hasKudoed;
    void apply(bool on) {
      a.hasKudoed = on;
      a.kudos = (a.kudos + (on ? 1 : -1)).clamp(0, 1 << 30);
    }

    setState(() {
      apply(!had);
      _kudosBusy = true;
    });
    final ok = await widget.onToggleKudos(a, !had);
    if (!mounted) return;
    setState(() {
      if (!ok) apply(had); // échec → rollback
      _kudosBusy = false;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.commonGenericError)));
    }
  }

  String _message(AppLocalizations t) {
    switch (a.type) {
      case 'pr':
        return t.communityMsgPr(a.payload['wodName']?.toString() ?? t.communityWorkoutFallback);
      case 'wod_logged':
        return t.communityMsgWodLogged(a.payload['wodName']?.toString() ?? t.communityWorkoutFallback);
      case 'rank_up':
        return t.communityMsgRankUp(HiLabels.rank(a.payload['rank']?.toString() ?? ''));
      case 'badge_unlocked':
        return t.communityMsgBadge(a.payload['name']?.toString() ?? '');
      case 'member_joined':
        return t.communityMsgMemberJoined(a.payload['index']?.toString() ?? '—');
      case 'post_text':
        return a.payload['body']?.toString() ?? '';
      case 'post_perf':
        return t.communityMsgPostPerf(a.payload['wodName']?.toString() ?? t.communityWorkoutFallback);
      default:
        return t.communityMsgDefault;
    }
  }

  /// (wodId, nom) si l'activité référence une séance → corps cliquable vers son classement.
  (String, String)? _seanceTarget(AppLocalizations t) {
    if (a.type != 'pr' && a.type != 'wod_logged' && a.type != 'post_perf') return null;
    final id = a.payload['wodId']?.toString();
    if (id == null || id.isEmpty) return null;
    return (id, a.payload['wodName']?.toString() ?? t.communityWorkoutFallback);
  }

  Widget _avatar() => HiAvatar(
        config: a.actorAvatar ?? const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1),
        rank: a.actorRank,
        size: 34,
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
          Row(
            children: [
              _avatar(),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: a.isMe
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: a.actorUserId)),
                          ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(a.actorName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          RankBadge(rank: a.actorRank, ovr: a.actorIndex, fontSize: 10),
                        ],
                      ),
                      if (a.createdAt != null)
                        Text(timeAgo(t, a.createdAt!),
                            style: HiType.caption.copyWith(color: HiColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              if (widget.onMenu != null && (!a.isMe || a.isPost))
                GestureDetector(
                  onTap: () => widget.onMenu!(a),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.more_horiz, size: 18, color: HiColors.textTertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Builder(builder: (context) {
            final target = _seanceTarget(t);
            final body = _message(t);
            final color = target != null ? HiColors.brandPrimary : HiColors.textSecondary;
            // Corps : mentions cliquables (posts d'athlètes) ; les events auto n'ont pas de mention.
            final text = MentionText(
              body,
              mentions: a.mentions,
              baseStyle: TextStyle(color: color),
            );
            if (target == null) return text;
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WodDetailScreen(wodId: target.$1, wodName: target.$2))),
              child: text,
            );
          }),
          if (a.type == 'post_perf') ...[
            const SizedBox(height: 4),
            _perfLine(t),
          ],
          const SizedBox(height: HiSpace.sm),
          Row(children: [
            _kudos(t),
            if (a.isPost && widget.onOpenComments != null) ...[
              const SizedBox(width: HiSpace.sm),
              _commentButton(t),
            ],
            if (widget.onFollow != null) ...[
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HiColors.brandPrimary,
                  foregroundColor: HiColors.textOnBrand,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => widget.onFollow!(a),
                child: Text(t.communityFollow),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _perfLine(AppLocalizations t) {
    final raw = a.payload['rawResult'];
    final scoreType = a.payload['scoreType']?.toString();
    final caption = a.payload['body']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (raw is num && scoreType != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: HiColors.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(HiRadius.pill),
            ),
            child: Text(
              '${formatWodResult(raw, scoreType, wodId: a.payload['wodId']?.toString(), roundsLabel: t.wodFormatRounds)}'
              '${a.payload['subScore'] is num ? '  ·  ${a.payload['subScore']}/100' : ''}',
              style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800),
            ),
          ),
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 4),
          MentionText(caption, mentions: a.mentions, baseStyle: TextStyle(color: HiColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _kudos(AppLocalizations t) {
    final active = a.hasKudoed;
    final count = a.kudos;
    return Semantics(
      button: !a.isMe,
      toggled: active,
      enabled: !a.isMe,
      label: t.communityKudosTooltip,
      value: count > 0 ? '$count' : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: a.isMe ? null : _toggleKudos,
          child: Tooltip(
            message: t.communityKudosTooltip,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: HiTap.minTarget),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? HiColors.brandPrimary.withValues(alpha: 0.15) : HiColors.bgElevated2,
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                    border:
                        Border.all(color: active ? HiColors.brandPrimary.withValues(alpha: 0.5) : HiColors.strokeSubtle),
                  ),
                  child: Text('👏 ${count > 0 ? count : ''}'.trim(),
                      style: TextStyle(
                          color: active ? HiColors.brandPrimary : HiColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _commentButton(AppLocalizations t) {
    final count = a.commentCount;
    return Semantics(
      button: true,
      label: t.commentsTitle,
      value: count > 0 ? '$count' : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => widget.onOpenComments!(a),
          child: Tooltip(
            message: t.commentsTitle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: HiTap.minTarget),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HiColors.bgElevated2,
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                    border: Border.all(color: HiColors.strokeSubtle),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.mode_comment_outlined, size: 15, color: HiColors.textSecondary),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Text('$count',
                          style: TextStyle(color: HiColors.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
