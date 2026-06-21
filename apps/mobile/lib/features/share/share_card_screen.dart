import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/web_download.dart';
import '../../theme/tokens.dart';
import '../../widgets/rank_badge.dart';

/// Carte partageable : un visuel soigné de ton HYBRID INDEX, téléchargeable en image (Web).
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key});

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _cardKey = GlobalKey();
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final ok = await downloadBytes(bytes, 'hybrid-index.png');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Carte téléchargée 📥' : 'Téléchargement non supporté ici.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    final name = ref.watch(sessionProvider).user?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Ma carte'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profile == null)
                  Text('Aucun Index à partager.', style: TextStyle(color: HiColors.textTertiary))
                else ...[
                  RepaintBoundary(
                    key: _cardKey,
                    child: _Card(profile: profile, name: name, sex: ref.watch(sessionProvider).sex),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  SizedBox(
                    width: 300,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: HiColors.brandPrimary,
                        foregroundColor: HiColors.textOnBrand,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: _exporting
                          ? SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.textOnBrand))
                          : const Icon(Icons.download),
                      label: const Text('Télécharger ma carte'),
                      onPressed: _exporting ? null : _export,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Habillage visuel d'une carte selon le rang (valeurs « produit imprimé », indépendantes du thème).
class _Skin {
  final Color frame;
  final Color bgTop;
  final Color bgBottom;
  final List<Color> metal; // dégradé du grand OVR
  final bool legendary; // elite/diamond → halo + traitement premium
  const _Skin(this.frame, this.bgTop, this.bgBottom, this.metal, {this.legendary = false});
}

const Map<String, _Skin> _skins = {
  'rookie': _Skin(Color(0xFF8A93A6), Color(0xFF161B26), Color(0xFF0B0E14), [Color(0xFFC2C9D6), Color(0xFF8A93A6)]),
  'bronze': _Skin(Color(0xFFC87E4F), Color(0xFF1E1611), Color(0xFF0E0A07), [Color(0xFFE8A878), Color(0xFFC87E4F)]),
  'silver': _Skin(Color(0xFFC2CBD8), Color(0xFF191D24), Color(0xFF0C0F14), [Color(0xFFEFF3F8), Color(0xFFB4BECC)]),
  'gold': _Skin(Color(0xFFF3C13A), Color(0xFF211B0E), Color(0xFF100C05), [Color(0xFFFFE27A), Color(0xFFF3C13A)]),
  'platinum': _Skin(Color(0xFF5FE0C8), Color(0xFF0E1F1C), Color(0xFF06100E), [Color(0xFFA8F5E6), Color(0xFF5FE0C8)]),
  'diamond': _Skin(Color(0xFF6FB3FF), Color(0xFF101826), Color(0xFF070C14), [Color(0xFFBFE0FF), Color(0xFF6FB3FF)], legendary: true),
  'elite': _Skin(Color(0xFFB98CFF), Color(0xFF160F26), Color(0xFF0A0714), [Color(0xFFB98CFF), Color(0xFF6FB3FF), Color(0xFF5FE0C8), Color(0xFFB98CFF)], legendary: true),
};

class _Card extends StatelessWidget {
  final Profile profile;
  final String name;
  final String? sex;
  const _Card({required this.profile, required this.name, this.sex});

  static const _ink = Color(0xFFF2F5FA);
  static const _inkSoft = Color(0xFFA7B0C0);

  _Skin get _skin => _skins[profile.index.rank] ?? _skins['rookie']!;

  @override
  Widget build(BuildContext context) {
    final idx = profile.index;
    final skin = _skin;
    final isElite = idx.rank == 'elite';
    final topPct = (100 - idx.percentile * 100).clamp(0, 100).round();
    final byAttr = {for (final a in profile.radar) a.attribute: a};
    // 2 colonnes × 3 lignes (sens groupés).
    const left = ['engine', 'power', 'muscular_endurance'];
    const right = ['strength', 'speed', 'hybrid'];

    return Container(
      width: 340,
      height: 453,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [skin.bgTop, skin.bgBottom]),
        borderRadius: BorderRadius.circular(HiRadius.xl),
        border: Border.all(color: skin.frame.withValues(alpha: isElite ? 0.9 : 0.7), width: 2),
        boxShadow: skin.legendary
            ? [BoxShadow(color: skin.frame.withValues(alpha: 0.30), blurRadius: 30, spreadRadius: -4)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(HiSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête : OVR + rang + ligue, et avatar ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => (isElite
                                ? SweepGradient(colors: skin.metal)
                                : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: skin.metal))
                            .createShader(r),
                        child: Text('${idx.value}',
                            style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w900, height: 0.9, color: Colors.white)),
                      ),
                      Text('OVR',
                          style: TextStyle(color: skin.frame.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      RankBadge(rank: idx.rank, fontSize: 12),
                      const SizedBox(height: 4),
                      Text('${sex == 'female' ? '♀' : '♂'}  LIGUE ${sex == 'female' ? 'F' : 'H'}',
                          style: const TextStyle(color: _inkSoft, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                _avatar(skin),
              ],
            ),
            const SizedBox(height: 14),
            // ── Bande percentile ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: skin.frame.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(HiRadius.pill)),
              child: Text('★ TOP $topPct %',
                  style: TextStyle(color: skin.frame, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 12),
            Text(name.isEmpty ? 'Athlète' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            const Spacer(),
            Container(height: 1, color: skin.frame.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            // ── 6 sous-notes ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: left.map((k) => _stat(k, byAttr[k])).toList())),
                const SizedBox(width: 16),
                Expanded(child: Column(children: right.map((k) => _stat(k, byAttr[k])).toList())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(_Skin skin) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: skin.frame.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(HiRadius.md),
        border: Border.all(color: skin.frame.withValues(alpha: 0.6), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: const TextStyle(color: _ink, fontSize: 30, fontWeight: FontWeight.w800)),
    );
  }

  Widget _stat(String key, RadarAttribute? a) {
    final unlocked = a?.unlocked ?? false;
    final score = a?.score ?? 0;
    final provisional = a?.isEstimated ?? false;
    final Color noteColor;
    if (!unlocked) {
      noteColor = HiColors.attrLocked;
    } else if (score >= 80) {
      noteColor = HiColors.success;
    } else if (score >= 60) {
      noteColor = _ink;
    } else if (score >= 40) {
      noteColor = _inkSoft;
    } else {
      noteColor = HiColors.warn;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: HiColors.attribute(key).withValues(alpha: unlocked ? 1 : 0.4)),
          const SizedBox(width: 8),
          Text(HiLabels.attrAbbreviation(key),
              style: const TextStyle(color: _inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const Spacer(),
          Opacity(
            opacity: provisional ? 0.7 : 1,
            child: Text(unlocked ? '$score' : '—',
                style: TextStyle(color: noteColor, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
