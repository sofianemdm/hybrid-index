import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/timeago.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/rank_badge.dart';
import '../profile/public_profile_screen.dart';

/// Ouvre le fil de commentaires d'un post en bottom-sheet. Renvoie le DELTA de commentaires
/// (créés − supprimés) pour que l'appelant mette à jour son compteur sans refetch.
Future<int> showCommentsSheet(
  BuildContext context, {
  required FeedActivity post,
}) async {
  final delta = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HiColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(HiRadius.xxl)),
    ),
    builder: (_) => _CommentsSheet(post: post),
  );
  return delta ?? 0;
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.post});
  final FeedActivity post;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final List<Comment> _items = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasError = false;
  bool _sending = false;
  String? _cursor;
  bool _hasMore = false;

  /// DELTA renvoyé à l'appelant (créés − supprimés) → maj optimiste du compteur de la carte.
  int _delta = 0;

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasMore && !_loadingMore && _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final page = await ref.read(apiClientProvider).comments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(apiClientProvider).comments(widget.post.id, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    HiHaptics.tap();
    setState(() => _sending = true);
    try {
      final created = await ref.read(apiClientProvider).createComment(widget.post.id, text);
      if (!mounted) return;
      setState(() {
        _items.add(created);
        _delta += 1;
        _sending = false;
        _inputCtrl.clear();
      });
      // Faire défiler vers le commentaire fraîchement posté.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).commonGenericError)));
    }
  }

  /// Menu d'un commentaire : Supprimer (mon commentaire OU commentaire sur mon post) / Signaler (tiers).
  Future<void> _commentMenu(Comment c) async {
    final t = AppLocalizations.of(context);
    final canDelete = c.isMe || widget.post.isMe;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HiColors.bgElevated,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canDelete)
            ListTile(
              leading: Icon(Icons.delete_outline, color: HiColors.error),
              title: Text(t.commentDelete, style: TextStyle(color: HiColors.error)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          if (!c.isMe)
            ListTile(
              leading: Icon(Icons.flag_outlined, color: HiColors.textSecondary),
              title: Text(t.commentReport, style: TextStyle(color: HiColors.textPrimary)),
              onTap: () => Navigator.of(context).pop('report'),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'delete') {
      await _delete(c);
    } else if (action == 'report') {
      await _report(c);
    }
  }

  Future<void> _delete(Comment c) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).deleteComment(c.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => x.id == c.id);
        _delta -= 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.commentDeleted)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.commonGenericError)));
    }
  }

  Future<void> _report(Comment c) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).reportComment(c.id, 'inappropriate');
      if (!mounted) return;
      // Le commentaire signalé disparaît de MA vue (auto-masquage géré côté back au seuil).
      setState(() => _items.removeWhere((x) => x.id == c.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.communityReportSent)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.commonGenericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_delta);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return Column(
              children: [
                _grabber(t),
                Expanded(child: _body(t, controller)),
                _composer(t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _grabber(AppLocalizations t) => Padding(
        padding: const EdgeInsets.only(top: HiSpace.sm, bottom: HiSpace.xs),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HiColors.strokeSubtle,
                borderRadius: BorderRadius.circular(HiRadius.pill),
              ),
            ),
            const SizedBox(height: HiSpace.sm),
            Text(t.commentsTitle, style: HiType.titleM.copyWith(color: HiColors.textPrimary)),
          ],
        ),
      );

  Widget _body(AppLocalizations t, ScrollController sheetController) {
    if (_loading) {
      return ListView.separated(
        controller: sheetController,
        padding: const EdgeInsets.all(HiSpace.lg),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: HiSpace.md),
        itemBuilder: (_, __) => const HiSkeleton(height: 56, radius: HiRadius.md),
      );
    }
    if (_hasError) {
      return ListView(
        controller: sheetController,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HiSpace.xl),
            child: ErrorRetry(onRetry: _loadFirst),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        controller: sheetController,
        children: [
          Padding(
            padding: const EdgeInsets.all(HiSpace.xl),
            child: Column(children: [
              Icon(Icons.mode_comment_outlined, color: HiColors.textTertiary, size: 36),
              const SizedBox(height: HiSpace.md),
              Text(t.commentsEmpty,
                  textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
            ]),
          ),
        ],
      );
    }
    // On garde notre propre controller pour la pagination (priorité au sheet controller fourni).
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.xs, HiSpace.lg, HiSpace.md),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: HiSpace.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _commentTile(_items[i], t);
      },
    );
  }

  Widget _commentTile(Comment c, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HiSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: c.isMe
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: c.authorUserId)),
                    ),
            child: HiAvatar(
              config: c.authorAvatar ?? const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1),
              rank: c.authorRank,
              size: 32,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: HiColors.textPrimary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    RankBadge(rank: c.authorRank, fontSize: 9),
                    const Spacer(),
                    if (c.createdAt != null)
                      Text(timeAgo(t, c.createdAt!),
                          style: HiType.caption.copyWith(color: HiColors.textTertiary, fontSize: 11)),
                    GestureDetector(
                      onTap: () => _commentMenu(c),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.more_horiz, size: 16, color: HiColors.textTertiary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(c.body, style: TextStyle(color: HiColors.textSecondary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(AppLocalizations t) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(HiSpace.md, HiSpace.sm, HiSpace.md, HiSpace.sm),
        decoration: BoxDecoration(
          color: HiColors.bgElevated,
          border: Border(top: BorderSide(color: HiColors.strokeSubtle)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: HiColors.textPrimary),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: t.commentHint,
                  hintStyle: TextStyle(color: HiColors.textTertiary),
                  filled: true,
                  fillColor: HiColors.bgElevated2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HiRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: HiSpace.sm),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: t.commentSend,
                    onPressed: _inputCtrl.text.trim().isEmpty ? null : _send,
                    icon: Icon(Icons.send_rounded,
                        color: _inputCtrl.text.trim().isEmpty ? HiColors.textTertiary : HiColors.brandPrimary),
                  ),
          ],
        ),
      ),
    );
  }
}
