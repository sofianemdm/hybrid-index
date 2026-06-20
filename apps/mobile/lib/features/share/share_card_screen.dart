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
                  const Text('Aucun Index à partager.', style: TextStyle(color: HiColors.textTertiary))
                else ...[
                  RepaintBoundary(
                    key: _cardKey,
                    child: _Card(profile: profile, name: name),
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
                          ? const SizedBox(
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

class _Card extends StatelessWidget {
  final Profile profile;
  final String name;
  const _Card({required this.profile, required this.name});

  @override
  Widget build(BuildContext context) {
    final idx = profile.index;
    return Container(
      width: 340,
      height: 460,
      padding: const EdgeInsets.all(HiSpace.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121724), Color(0xFF0B0E14)],
        ),
        borderRadius: BorderRadius.circular(HiRadius.lg),
        border: Border.all(color: HiColors.brandPrimary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('HYBRID INDEX',
              style: TextStyle(color: HiColors.brandPrimary, fontWeight: FontWeight.w800, letterSpacing: 4, fontSize: 16)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: HiColors.textSecondary, fontSize: 14)),
          const Spacer(),
          ShaderMask(
            shaderCallback: (r) => HiColors.brandGradient.createShader(r),
            child: Text('${idx.value}',
                style: const TextStyle(color: Colors.white, fontSize: 110, fontWeight: FontWeight.w900, height: 1)),
          ),
          const SizedBox(height: 8),
          RankBadge(rank: idx.rank, fontSize: 16),
          const SizedBox(height: 12),
          Text('Meilleur que ${(idx.percentile * 100).clamp(0, 100).toStringAsFixed(0)} % de la population',
              textAlign: TextAlign.center, style: const TextStyle(color: HiColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Container(height: 1, color: HiColors.strokeSubtle),
          const SizedBox(height: 10),
          const Text('Et toi, c\'est combien ?',
              style: TextStyle(color: HiColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
