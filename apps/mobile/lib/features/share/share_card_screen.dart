import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/web_download.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_button.dart';
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

  /// Capture la carte en PNG (figée le temps de la capture).
  Future<Uint8List?> _capture() async {
    setState(() => _exporting = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Partage natif (réseaux sociaux) ; capture puis feuille de partage iOS/Android (et Web Share API).
  Future<void> _share() async {
    try {
      final bytes = await _capture();
      if (bytes == null || !mounted) return;
      final shareText = AppLocalizations.of(context).shareCardShareText;
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'hybrid-index.png', mimeType: 'image/png')],
        text: shareText,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _export() async {
    try {
      final bytes = await _capture();
      if (bytes == null || !mounted) return;
      final ok = await downloadBytes(bytes, 'hybrid-index.png');
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? t.shareCardDownloaded : t.shareCardDownloadUnsupported)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider).value;
    final name = ref.watch(sessionProvider).user?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(t.shareCardTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profile == null)
                  Text(t.shareCardNoIndex, style: TextStyle(color: HiColors.textTertiary))
                else ...[
                  RepaintBoundary(
                    key: _cardKey,
                    child: _Card(profile: profile, name: name, sex: ref.watch(sessionProvider).sex, exporting: _exporting),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  Text(t.shareCardTagline,
                      textAlign: TextAlign.center, style: HiType.caption.copyWith(color: HiColors.textTertiary)),
                  const SizedBox(height: HiSpace.sm),
                  SizedBox(
                    width: 300,
                    child: HiButton(
                      label: t.shareCardShareCta,
                      icon: Icons.ios_share_rounded,
                      loading: _exporting,
                      onPressed: _exporting ? null : _share,
                    ),
                  ),
                  const SizedBox(height: HiSpace.sm),
                  SizedBox(
                    width: 300,
                    child: HiButtonSecondary(
                      label: t.shareCardDownload,
                      icon: Icons.download_rounded,
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

class _Card extends StatefulWidget {
  final Profile profile;
  final String name;
  final String? sex;

  /// Pendant l'export PNG : on fige (OVR plein, sans reflet animé) pour une capture propre.
  final bool exporting;
  const _Card({required this.profile, required this.name, this.sex, this.exporting = false});

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with TickerProviderStateMixin {
  static const _ink = Color(0xFFF2F5FA);
  static const _inkSoft = Color(0xFFA7B0C0);

  // Ordre d'apparition en cascade des 6 attributs.
  static const _order = {'engine': 0, 'strength': 1, 'power': 2, 'speed': 3, 'muscular_endurance': 4, 'hybrid': 5};

  late final AnimationController _reveal;
  late final AnimationController _sheen;

  _Skin get _skin => _skins[widget.profile.index.rank] ?? _skins['rookie']!;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _reveal.addStatusListener((s) {
      if (s == AnimationStatus.completed) HapticFeedback.mediumImpact();
    });
    _sheen = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    if (_skin.legendary) _sheen.repeat();
    _reveal.forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final idx = widget.profile.index;
    final skin = _skin;
    final isElite = idx.rank == 'elite';
    final topPct = (100 - idx.percentile * 100).clamp(1, 100).round();
    final byAttr = {for (final a in widget.profile.radar) a.attribute: a};
    const left = ['engine', 'power', 'muscular_endurance'];
    const right = ['strength', 'speed', 'hybrid'];

    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _sheen]),
      builder: (context, _) {
        final t = widget.exporting ? 1.0 : Curves.easeOutCubic.transform(_reveal.value);
        final shownOvr = (idx.value * t).round();
        final haloAlpha = (skin.legendary ? 0.30 : 0.0) * t;

        return Container(
          width: 340,
          height: 453,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [skin.bgTop, skin.bgBottom]),
            borderRadius: BorderRadius.circular(HiRadius.xl),
            border: Border.all(color: skin.frame.withValues(alpha: isElite ? 0.9 : 0.7), width: 2),
            boxShadow: skin.legendary
                ? [BoxShadow(color: skin.frame.withValues(alpha: haloAlpha), blurRadius: 30, spreadRadius: -4)]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(HiRadius.xl),
            child: Stack(
              children: [
                Padding(
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
                                  child: Text('$shownOvr',
                                      style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w900, height: 0.9, color: Colors.white)),
                                ),
                                Text(loc.shareCardOvr,
                                    style: TextStyle(color: skin.frame.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3)),
                                const SizedBox(height: 8),
                                RankBadge(rank: idx.rank, fontSize: 12),
                                const SizedBox(height: 4),
                                Text('${widget.sex == 'female' ? '♀' : '♂'}  ${loc.shareCardLeague} ${widget.sex == 'female' ? 'F' : 'H'}',
                                    style: const TextStyle(color: _inkSoft, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                          _avatar(skin),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: skin.frame.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(HiRadius.pill)),
                        child: Text(loc.shareCardTopPct(topPct),
                            style: TextStyle(color: skin.frame, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.name.isEmpty ? loc.shareCardAthlete : widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                      const Spacer(),
                      Container(height: 1, color: skin.frame.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
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
                if (skin.legendary && !widget.exporting) _sheenLayer(idx.rank),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Bande lumineuse diagonale qui traverse la carte en boucle (diamant/elite).
  Widget _sheenLayer(String rank) {
    final alpha = rank == 'elite' ? 0.12 : 0.06;
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final dx = (-0.5 + 1.7 * _sheen.value) * w;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.rotate(
                angle: -0.42,
                child: Container(
                  width: w * 0.32,
                  height: c.maxHeight * 1.6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.white.withValues(alpha: alpha), Colors.transparent],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _avatar(_Skin skin) {
    final initials = widget.name.trim().isEmpty
        ? '?'
        : widget.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
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
    // Cascade : chaque attribut apparaît (fade + glissement) après l'OVR.
    final start = 0.45 + (_order[key] ?? 0) * 0.06;
    final av = widget.exporting ? 1.0 : Curves.easeOut.transform(((_reveal.value - start) / 0.35).clamp(0.0, 1.0));
    return Opacity(
      opacity: av,
      child: Transform.translate(
        offset: Offset(0, (1 - av) * 6),
        child: Padding(
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
        ),
      ),
    );
  }
}
