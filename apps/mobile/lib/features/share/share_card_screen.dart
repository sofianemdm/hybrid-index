import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../data/analytics.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/web_download.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_button.dart';

/// Carte partageable : un visuel « trophée » de ton Athlete Index, téléchargeable en image (Web).
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
        [XFile.fromData(bytes, name: 'athlete-index.png', mimeType: 'image/png')],
        text: shareText,
      );
      Analytics.capture('share_card_shared');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _export() async {
    try {
      final bytes = await _capture();
      if (bytes == null || !mounted) return;
      final ok = await downloadBytes(bytes, 'athlete-index.png');
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
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.shareCardTitle), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HiSpace.lg),
            child: profileAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(HiSpace.xxl),
                child: CircularProgressIndicator(color: HiColors.brandPrimary),
              ),
              error: (_, __) => _errorRetry(t),
              data: (profile) => profile == null ? _noIndex(t) : _cardAndActions(context, t, profile),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noIndex(AppLocalizations t) =>
      Text(t.shareCardNoIndex, textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary));

  Widget _errorRetry(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.all(HiSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: HiColors.textTertiary, size: 36),
          const SizedBox(height: HiSpace.md),
          Text(t.shareCardNoIndex, textAlign: TextAlign.center, style: TextStyle(color: HiColors.textTertiary)),
          const SizedBox(height: HiSpace.md),
          SizedBox(
            width: 220,
            child: HiButtonSecondary(
              label: t.commonRetry,
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(myProfileProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardAndActions(BuildContext context, AppLocalizations t, Profile profile) {
    final name = ref.watch(sessionProvider).user?.displayName ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Carte rendue à échelle de police FIXE (TextScaler.noScaling) : gabarit pixel-stable,
        // identique sur tous les appareils, et capture PNG déterministe (cf. revue v2 — évite
        // qu'un réglage OS « grandes polices » fasse déborder le socle / corrompe le PNG).
        MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: RepaintBoundary(
            key: _cardKey,
            child: _Card(
              profile: profile,
              name: name,
              sex: ref.watch(sessionProvider).sex,
              avatar: ref.watch(avatarProvider).value,
              badges: ref.watch(cardBadgesProvider).value ?? const [],
              exporting: _exporting,
            ),
          ),
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
    );
  }
}

/// Habillage visuel d'une carte selon le rang (valeurs « produit imprimé », indépendantes du thème).
class _Skin {
  final Color frame;
  final Color bgTop;
  final Color bgBottom;
  final List<Color> metal; // dégradé du grand OVR + bordure métallique
  final bool legendary; // diamond/elite → halo + traitement premium
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

/// Archétype FR (MAJ) selon l'attribut dominant (cf. docs/design-carte-v2.md §E).
const Map<String, String> _archetypeLabel = {
  'engine': 'MOTEUR',
  'strength': 'LA FORCE',
  'power': 'EXPLOSIF',
  'speed': 'VÉLOCITÉ',
  'muscular_endurance': 'INFATIGABLE',
  'hybrid': 'TOUT-TERRAIN',
};

class _Card extends StatefulWidget {
  final Profile profile;
  final String name;
  final String? sex;
  final AvatarConfig? avatar;
  final List<CardBadge> badges;

  /// Pendant l'export PNG : on fige (OVR plein, sans reflet animé) pour une capture propre.
  final bool exporting;
  const _Card({
    required this.profile,
    required this.name,
    this.sex,
    this.avatar,
    this.badges = const [],
    this.exporting = false,
  });

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with TickerProviderStateMixin {
  static const _ink = Color(0xFFF2F5FA);
  static const _inkSoft = Color(0xFFA7B0C0);

  // ─── Dimensions carte v2 (pixels logiques fixes → PNG identique partout) ───
  static const double _kCardW = 360;
  static const double _kCardH = 540;
  static const double _kBorder = 2;
  static const double _kPad = 18;
  static const double _kBandH = 128; // bandeau haut

  // Ordre d'apparition en cascade des 6 attributs.
  static const _order = {'engine': 0, 'strength': 1, 'power': 2, 'speed': 3, 'muscular_endurance': 4, 'hybrid': 5};

  // Intensité (alpha) et période (ms) du sheen, croissantes avec le rang.
  static const _sheenAlpha = {
    'rookie': 0.03, 'bronze': 0.04, 'silver': 0.05, 'gold': 0.07,
    'platinum': 0.08, 'diamond': 0.10, 'elite': 0.13,
  };
  static const _sheenPeriod = {
    'rookie': 4200, 'bronze': 4000, 'silver': 3800, 'gold': 3400,
    'platinum': 3200, 'diamond': 2900, 'elite': 2600,
  };

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
    final period = _sheenPeriod[widget.profile.index.rank] ?? 3600;
    _sheen = AnimationController(vsync: this, duration: Duration(milliseconds: period));
    _sheen.repeat(); // sheen sur TOUS les rangs (intensité par l'alpha)
    _reveal.forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _sheen.dispose();
    super.dispose();
  }

  // ─── Archétype / dominant ───
  List<RadarAttribute> get _unlocked => widget.profile.radar.where((a) => a.unlocked).toList();

  /// Attribut de score max parmi les déverrouillés (ou null si aucun).
  String? _dominantKey() {
    final u = _unlocked;
    if (u.isEmpty) return null;
    u.sort((a, b) => b.score.compareTo(a.score));
    return u.first.attribute;
  }

  /// Polyvalent si < 2 attributs déverrouillés, ou écart top1−top2 < 6 points.
  bool _isBalanced() {
    final u = _unlocked;
    if (u.length < 2) return true;
    final s = u.map((a) => a.score).toList()..sort((a, b) => b.compareTo(a));
    return (s[0] - s[1]) < 6;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final idx = widget.profile.index;
    final skin = _skin;
    final isElite = idx.rank == 'elite';
    final topPct = (100 - idx.percentile * 100).clamp(1, 100).round();
    final byAttr = {for (final a in widget.profile.radar) a.attribute: a};

    final dom = _dominantKey();
    final balanced = _isBalanced();
    final archLabel = (dom == null || balanced) ? 'ATHLÈTE HYBRIDE' : (_archetypeLabel[dom] ?? 'TOUT-TERRAIN');
    final archColor = (dom == null || balanced) ? HiColors.attrHybrid : HiColors.attribute(dom);
    final highlightKey = balanced ? null : dom; // dominant mis en avant seulement si tranché

    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _sheen]),
      builder: (context, _) {
        final p = _reveal.value;
        final t = widget.exporting ? 1.0 : Curves.easeOutCubic.transform(p);
        final tExpo = widget.exporting ? 1.0 : Curves.easeOutExpo.transform(p);
        final shownOvr = (idx.value * tExpo).round();
        final pulse = widget.exporting ? 1.0 : (0.85 + (isElite ? 0.20 : 0.15) * math.sin(_sheen.value * 2 * math.pi));

        return Container(
          // z0 — faux border-gradient métallique + halo de carte (legendary).
          decoration: BoxDecoration(
            gradient: _borderGradient(skin, isElite),
            borderRadius: BorderRadius.circular(HiRadius.xl + _kBorder),
            boxShadow: skin.legendary
                ? [BoxShadow(color: skin.frame.withValues(alpha: 0.30 * t), blurRadius: 34, spreadRadius: -4)]
                : const [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 12))],
          ),
          padding: const EdgeInsets.all(_kBorder),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(HiRadius.xl),
            child: SizedBox(
              width: _kCardW,
              height: _kCardH,
              child: Stack(
                children: [
                  // z1 — fond dégradé de base.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [skin.bgTop, skin.bgBottom],
                        ),
                      ),
                    ),
                  ),
                  // z2 — motif gravé (statique, hors AnimatedBuilder utile mais coût négligeable).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _EngravePainter(skin.frame, isElite ? 0.05 : 0.04, cross: isElite)),
                    ),
                  ),
                  // z5 — inner top highlight (lumière du dessus).
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _kCardH * 0.30,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // z6 — contenu (3 zones).
                  Column(
                    children: [
                      SizedBox(height: _kBandH, child: _bandeau(loc, skin, idx, isElite, shownOvr, t)),
                      Expanded(child: _heroScene(skin, idx, t, pulse)),
                      _socle(loc, skin, byAttr, archLabel, archColor, highlightKey, topPct, t),
                    ],
                  ),
                  // z7 — liseré intérieur clair (double-trait premium).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(HiRadius.xl),
                          border: Border.all(color: skin.frame.withValues(alpha: 0.18), width: 1),
                        ),
                      ),
                    ),
                  ),
                  // z8 — sheen diagonal animé (tous rangs ; figé en export).
                  if (!widget.exporting) _sheenLayer(idx.rank),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── BANDEAU (zone 1) ─────────────────────────
  Widget _bandeau(AppLocalizations loc, _Skin skin, IndexSummary idx, bool isElite, int shownOvr, double t) {
    final gradeProgress = (HiGrade.progress(idx.value) * t).clamp(0.0, 1.0);
    return Stack(
      children: [
        // Bloc OVR (haut-gauche).
        Positioned(
          left: _kPad,
          top: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (r) => (isElite
                        ? SweepGradient(colors: skin.metal)
                        : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: skin.metal))
                    .createShader(r),
                child: Text(
                  '$shownOvr',
                  style: HiType.displayXL.copyWith(fontSize: 72, fontWeight: FontWeight.w700, height: 0.86, color: Colors.white),
                ),
              ),
              const SizedBox(height: 2),
              Text(loc.shareCardOvr,
                  style: HiType.overline.copyWith(fontSize: 11, color: skin.frame.withValues(alpha: 0.80))),
              const SizedBox(height: 8),
              // Grade + progression vers le palier suivant (la « tension »).
              Row(
                children: [
                  Text(HiGrade.label(idx.value),
                      style: HiType.overline.copyWith(fontSize: 12, color: HiGrade.color(idx.value), letterSpacing: 1.5)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(HiRadius.pill),
                      child: Stack(
                        children: [
                          Container(height: 5, color: skin.frame.withValues(alpha: 0.14)),
                          FractionallySizedBox(
                            widthFactor: gradeProgress,
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(HiRadius.pill),
                                gradient: LinearGradient(colors: [HiGrade.color(idx.value), HiGrade.nextColor(idx.value)]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Écusson de ligue (haut-droite).
        Positioned(
          right: _kPad,
          top: 12,
          child: Transform.scale(
            scale: widget.exporting ? 1.0 : (0.6 + 0.4 * Curves.easeOutBack.transform(((_reveal.value - 0.2) / 0.3).clamp(0.0, 1.0))),
            child: _leagueShield(loc),
          ),
        ),
      ],
    );
  }

  Widget _leagueShield(AppLocalizations loc) {
    final female = widget.sex == 'female';
    final base = female ? HiColors.brandSecondary : HiColors.info;
    final dark = Color.lerp(base, Colors.black, 0.32)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 56,
          child: CustomPaint(
            painter: _ShieldPainter(base, dark),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(female ? '♀' : '♂',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text('${loc.shareCardLeague} ${female ? 'F' : 'H'}',
            style: HiType.overline.copyWith(fontSize: 8, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.78))),
      ],
    );
  }

  // ───────────────────────── HÉROS (zone 2) ─────────────────────────
  Widget _heroScene(_Skin skin, IndexSummary idx, double t, double pulse) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // z3 — vignette radiale sombre (détache l'avatar).
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.10),
                  radius: 0.95,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        // z4 — halo radial coloré par skin (pulse).
        Center(child: IgnorePointer(child: _halo(idx.rank, skin, t * pulse))),
        // ombre portée sous l'avatar.
        Align(
          alignment: const Alignment(0, 0.72),
          child: Container(
            width: 120,
            height: 16,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(60, 8)),
              boxShadow: [BoxShadow(color: Color(0x73000000), blurRadius: 18, spreadRadius: -2)],
            ),
          ),
        ),
        // avatar héros.
        Align(
          alignment: const Alignment(0, -0.08),
          child: widget.avatar != null
              ? HiAvatar(config: widget.avatar!, rank: idx.rank, size: 156)
              : _fallbackAvatar(skin),
        ),
      ],
    );
  }

  Widget _halo(String rank, _Skin skin, double a) {
    // Couleur/diamètre/opacité par rang (cf. spec §C.2).
    Color c = skin.frame;
    double d = 200, op = 0.18;
    List<Color>? eliteColors;
    switch (rank) {
      case 'rookie':
        d = 196;
        op = 0.14;
        break;
      case 'bronze':
        d = 196;
        op = 0.18;
        break;
      case 'silver':
        d = 200;
        op = 0.18;
        break;
      case 'gold':
        c = const Color(0xFFFFE27A);
        d = 210;
        op = 0.26;
        break;
      case 'platinum':
        c = const Color(0xFFA8F5E6);
        d = 210;
        op = 0.26;
        break;
      case 'diamond':
        c = const Color(0xFFBFE0FF);
        d = 220;
        op = 0.32;
        break;
      case 'elite':
        d = 232;
        op = 0.38;
        eliteColors = [
          const Color(0xFFB98CFF).withValues(alpha: 0.38 * a),
          const Color(0xFF5FE0C8).withValues(alpha: 0.16 * a),
          Colors.transparent,
        ];
        break;
    }
    final gradient = eliteColors != null
        ? RadialGradient(colors: eliteColors, stops: const [0.0, 0.45, 1.0])
        : RadialGradient(colors: [c.withValues(alpha: op * a), Colors.transparent], stops: const [0.0, 1.0]);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
    );
  }

  Widget _fallbackAvatar(_Skin skin) {
    final initials = widget.name.trim().isEmpty
        ? '?'
        : widget.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: skin.frame.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(HiRadius.xl),
        border: Border.all(color: skin.frame.withValues(alpha: 0.6), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: HiType.displayL.copyWith(fontSize: 44, color: _ink)),
    );
  }

  // ───────────────────────── SOCLE (zone 3) ─────────────────────────
  Widget _socle(AppLocalizations loc, _Skin skin, Map<String, RadarAttribute> byAttr, String archLabel,
      Color archColor, String? highlightKey, int topPct, double t) {
    const left = ['engine', 'power', 'muscular_endurance'];
    const right = ['strength', 'speed', 'hybrid'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kPad, 0, _kPad, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: skin.frame.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          // Nom (plaque gravée).
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: _kCardW - 2 * _kPad - 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: skin.frame.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(HiRadius.sm),
              ),
              child: Text(
                (widget.name.isEmpty ? loc.shareCardAthlete : widget.name).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: HiType.titleL.copyWith(fontSize: 21, letterSpacing: 0.4, color: _ink),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Archétype + Top %.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(archLabel,
                  style: HiType.overline.copyWith(fontSize: 11, letterSpacing: 2.0, color: archColor)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: skin.frame.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HiRadius.pill),
                ),
                child: Text(loc.shareCardTopPct(topPct),
                    style: HiType.overline.copyWith(fontSize: 9, letterSpacing: 0.5, color: skin.frame)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats v2 (mini-barres).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left.map((k) => _statV2(skin, k, byAttr[k], k == highlightKey)).toList())),
              const SizedBox(width: 14),
              Expanded(child: Column(children: right.map((k) => _statV2(skin, k, byAttr[k], k == highlightKey)).toList())),
            ],
          ),
          const SizedBox(height: 8),
          // Badges (5 slots — vides tant que non branchés : dopamine honnête).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: i < widget.badges.length ? _realBadge(widget.badges[i], i) : _emptyBadge(skin, i, t),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Footer branding (slot QR réservé + wordmark).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: skin.frame.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: skin.frame.withValues(alpha: 0.18), width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.qr_code_2_rounded, size: 18, color: skin.frame.withValues(alpha: 0.30)),
              ),
              const Spacer(),
              Text('ATHLETE LEAGUE',
                  style: HiType.overline.copyWith(fontSize: 11, letterSpacing: 3.0, color: _ink.withValues(alpha: 0.55))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statV2(_Skin skin, String key, RadarAttribute? a, bool isDominant) {
    final unlocked = a?.unlocked ?? false;
    final score = a?.score ?? 0;
    final provisional = a?.isEstimated ?? false;
    final attrColor = HiColors.attribute(key);
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
    // Cascade : chaque attribut démarre décalé ; fenêtre calée pour atteindre 100 % AVANT la fin du
    // reveal (sinon les derniers attributs restaient figés à ~99 % de leur score).
    final start = 0.35 + (_order[key] ?? 0) * 0.05;
    final localT = widget.exporting ? 1.0 : Curves.easeOutExpo.transform(((_reveal.value - start) / 0.30).clamp(0.0, 1.0));
    final shownScore = (score * localT).round();
    final fill = (score / 100).clamp(0.0, 1.0) * localT;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // pastille du dominant (réserve l'espace pour aligner les colonnes).
          SizedBox(
            width: 8,
            child: isDominant
                ? Center(child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: attrColor)))
                : null,
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 30,
            child: Text(HiLabels.attrAbbreviation(key),
                style: HiType.overline.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: isDominant ? _ink : _inkSoft,
                    fontWeight: isDominant ? FontWeight.w800 : FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: skin.frame.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(HiRadius.pill),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: unlocked ? fill : 0.0,
                    heightFactor: 1.0, // sans ça, le DecoratedBox enfant s'effondrait à 0px de haut → remplissage invisible
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(HiRadius.pill),
                        gradient: LinearGradient(colors: [attrColor, attrColor.withValues(alpha: 0.7)]),
                        boxShadow: isDominant ? [BoxShadow(color: attrColor.withValues(alpha: 0.55), blurRadius: 8)] : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Opacity(
              opacity: provisional ? 0.7 : 1,
              child: Text(unlocked ? '$shownScore' : '—',
                  textAlign: TextAlign.right,
                  style: HiType.numericM.copyWith(fontSize: 16, color: noteColor)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBadge(_Skin skin, int i, double t) {
    final appear = widget.exporting ? 1.0 : Curves.easeOutBack.transform(((_reveal.value - (0.85 + i * 0.03)) / 0.15).clamp(0.0, 1.0));
    return Opacity(
      opacity: appear.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.8 + 0.2 * appear.clamp(0.0, 1.0),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: skin.frame.withValues(alpha: 0.06),
            border: Border.all(color: skin.frame.withValues(alpha: 0.18), width: 1),
          ),
          alignment: Alignment.center,
          child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: skin.frame.withValues(alpha: 0.25))),
        ),
      ),
    );
  }

  /// Badge gagné : pastille teintée par rareté, glow si rare/epic/legendary.
  Widget _realBadge(CardBadge b, int i) {
    final color = _badgeColor(b.rarity);
    final rare = b.rarity != 'common';
    final appear = widget.exporting
        ? 1.0
        : Curves.easeOutBack.transform(((_reveal.value - (0.85 + i * 0.03)) / 0.15).clamp(0.0, 1.0));
    return Opacity(
      opacity: appear.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.8 + 0.2 * appear.clamp(0.0, 1.0),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.20),
            border: Border.all(color: color, width: 1.4),
            boxShadow: rare ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)] : null,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.military_tech_rounded, color: Colors.white, size: 15),
        ),
      ),
    );
  }

  // Couleurs fixes par rareté (la carte est indépendante du thème).
  Color _badgeColor(String rarity) {
    switch (rarity) {
      case 'legendary':
        return const Color(0xFFB98CFF);
      case 'epic':
        return const Color(0xFF7C5CFF);
      case 'rare':
        return const Color(0xFF2BD4F5);
      default:
        return _inkSoft;
    }
  }

  /// Bande lumineuse diagonale qui traverse la carte en boucle (intensité par rang).
  Widget _sheenLayer(String rank) {
    final alpha = _sheenAlpha[rank] ?? 0.05;
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

  /// Faux border-gradient métallique : clair → foncé → clair (reflet), ou sweep iridescent (élite).
  Gradient _borderGradient(_Skin skin, bool isElite) {
    if (isElite) {
      return SweepGradient(
        colors: skin.metal,
        transform: GradientRotation(widget.exporting ? 0 : _sheen.value * 2 * math.pi),
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [skin.metal.first, skin.metal.last, skin.metal.first],
    );
  }
}

/// Motif gravé : fines diagonales à -45° (+ jeu croisé pour l'élite). Coût négligeable (vectoriel).
class _EngravePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final bool cross;
  _EngravePainter(this.color, this.opacity, {this.cross = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1;
    const gap = 14.0;
    final n = ((size.width + size.height) / gap).ceil();
    for (var i = 0; i < n; i++) {
      final x = i * gap;
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), paint);
    }
    if (cross) {
      for (var i = 0; i < n; i++) {
        final x = i * gap - size.height;
        canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EngravePainter old) => old.color != color || old.opacity != opacity || old.cross != cross;
}

/// Bouclier de ligue (division) — dégradé vertical + bord blanc.
class _ShieldPainter extends CustomPainter {
  final Color top;
  final Color bottom;
  _ShieldPainter(this.top, this.bottom);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(2, 6)
      ..lineTo(w - 2, 6)
      ..lineTo(w - 2, h * 0.55)
      ..quadraticBezierTo(w - 2, h * 0.82, w * 0.5, h - 2)
      ..quadraticBezierTo(2, h * 0.82, 2, h * 0.55)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom])
          .createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawShadow(path, bottom.withValues(alpha: 0.6), 4, false);
    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.top != top || old.bottom != bottom;
}
