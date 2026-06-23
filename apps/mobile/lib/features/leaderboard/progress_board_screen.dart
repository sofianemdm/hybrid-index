import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../profile/public_profile_screen.dart';

/// Classement de PROGRESSION de la semaine : on classe par EFFORT fourni, pas par niveau.
/// Tout le monde peut briller (régularité, PR, exploration). Personne n'est « dernier ».
class ProgressBoardScreen extends ConsumerStatefulWidget {
  /// Si fourni, le classement de progression est filtré aux membres de ce club.
  final String? clubId;
  final String? clubName;
  const ProgressBoardScreen({super.key, this.clubId, this.clubName});

  @override
  ConsumerState<ProgressBoardScreen> createState() => _ProgressBoardScreenState();
}

class _ProgressBoardScreenState extends ConsumerState<ProgressBoardScreen> {
  late String _sex;
  late Future<ProgressBoard> _future;

  @override
  void initState() {
    super.initState();
    _sex = ref.read(sessionProvider).sex ?? 'male';
    _load();
  }

  void _load() => _future = ref.read(apiClientProvider).progressBoard(_sex, clubId: widget.clubId);

  void _switch(String sex) {
    if (sex == _sex) return;
    setState(() {
      _sex = sex;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.clubName != null ? t.progressBoardClubTitle(widget.clubName!) : t.progressBoardTitle),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.sm, HiSpace.lg, HiSpace.sm),
              child: Text(t.progressBoardHeader,
                  style: TextStyle(color: HiColors.textSecondary, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
              child: Row(children: [_tab(t.leaderboardMen, 'male'), const SizedBox(width: 8), _tab(t.leaderboardWomen, 'female')]),
            ),
            const SizedBox(height: HiSpace.md),
            Expanded(
              child: FutureBuilder<ProgressBoard>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('${snap.error}', style: TextStyle(color: HiColors.error)));
                  }
                  final b = snap.data!;
                  if (b.entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(HiSpace.xl),
                        child: Text(t.progressBoardEmpty,
                            textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(HiSpace.lg, 0, HiSpace.lg, HiSpace.lg),
                    children: [
                      if (b.myPosition != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: HiSpace.md),
                          child: Text(t.progressBoardMyPosition(b.myPosition!, b.myEp ?? 0),
                              style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w700)),
                        ),
                      ...b.entries.map(_row),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, String sex) {
    final active = _sex == sex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switch(sex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? HiColors.brandPrimary : HiColors.bgElevated2,
            borderRadius: BorderRadius.circular(HiRadius.pill),
          ),
          child: Text(label,
              style: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _row(ProgressEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: HiSpace.md, vertical: 10),
      decoration: BoxDecoration(
        color: e.isMe ? HiColors.brandPrimary.withValues(alpha: 0.12) : HiColors.bgElevated,
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: HiColors.strokeSubtle),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${e.position}',
                style: TextStyle(color: e.position <= 3 ? HiColors.brandPrimary : HiColors.textTertiary, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: e.isMe ? null : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: e.userId)),
                  ),
              child: Text(e.isMe ? AppLocalizations.of(context).leaderboardYou(e.displayName) : e.displayName,
                  style: TextStyle(color: HiColors.textPrimary, fontWeight: e.isMe ? FontWeight.w800 : FontWeight.w500)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: HiColors.brandPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(HiRadius.pill),
            ),
            child: Text(AppLocalizations.of(context).progressBoardPts(e.ep),
                style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
