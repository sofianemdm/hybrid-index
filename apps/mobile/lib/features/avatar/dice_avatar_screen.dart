import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart'; // avatarProvider + myProfileProvider
import '../../data/api_client.dart';
import '../../data/dicebear.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/celebration.dart';
import '../../widgets/hi_avatar.dart';

/// Création d'avatar premium (DiceBear) — Phase 1 : style + variations + « Surprends-moi ».
/// Rendu via Image.network (zéro dépendance). Sauvegarde le style + le seed sur le compte.
class DiceAvatarScreen extends ConsumerStatefulWidget {
  const DiceAvatarScreen({super.key});

  @override
  ConsumerState<DiceAvatarScreen> createState() => _DiceAvatarScreenState();
}

class _DiceAvatarScreenState extends ConsumerState<DiceAvatarScreen> {
  final _rng = Random();
  AvatarConfig _base = const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  String _style = kDiceBearDefaultStyle;
  late String _seed;
  late List<String> _variations;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _seed = _newSeed();
    _variations = List.generate(8, (_) => _newSeed());
    _variations[0] = _seed;
    _load();
  }

  // Borne SANS décalage de bits : `1 << 32` peut valoir 0 sur le web (dart2js) → nextInt(0) plante.
  String _newSeed() => _rng.nextInt(1000000000).toRadixString(36);

  void _shuffle() => setState(() {
        _variations = List.generate(8, (_) => _newSeed());
        _variations[0] = _seed; // garde l'avatar courant en tête
      });

  Future<void> _load() async {
    try {
      final a = await ref.read(apiClientProvider).getAvatar();
      if (!mounted) return;
      setState(() {
        _base = a;
        if (a.diceSeed != null && a.diceSeed!.isNotEmpty) {
          _seed = a.diceSeed!;
          _style = a.diceStyle ?? kDiceBearDefaultStyle;
          _variations[0] = _seed;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateAvatar(_base.copyWith(diceStyle: _style, diceSeed: _seed));
      ref.invalidate(avatarProvider);
      if (!mounted) return;
      HiHaptics.celebrate();
      await Celebration.show(
        context,
        title: 'Ton athlète est prêt !',
        subtitle: 'Il portera tes couleurs au classement.',
        intensity: CelebrationIntensity.medium,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rank = ref.watch(myProfileProvider).value?.index.rank ?? 'rookie';
    final preview = _base.copyWith(diceStyle: _style, diceSeed: _seed);
    return Scaffold(
      appBar: AppBar(title: const Text('Forge ton athlète'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: HiColors.brandPrimary))
            : ListView(
                padding: const EdgeInsets.all(HiSpace.lg),
                children: [
                  Center(
                    // L'avatar « pop » (scale + fondu) à chaque changement de style/visage → dopamine.
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: Tween<double>(begin: 0.85, end: 1.0)
                            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: HiAvatar(
                        key: ValueKey('$_style-$_seed'),
                        config: preview,
                        rank: rank,
                        size: 160,
                      ),
                    ),
                  ),
                  const SizedBox(height: HiSpace.sm),
                  Center(
                    child: Text('C\'est lui qui grimpera le classement.',
                        style: HiType.caption.copyWith(color: HiColors.textSecondary)),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  Text('STYLE',
                      style: HiType.caption
                          .copyWith(color: HiColors.textTertiary, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(height: HiSpace.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kDiceBearStyles.map((st) {
                      final active = st.id == _style;
                      return GestureDetector(
                        onTap: () {
                          HiHaptics.tap();
                          setState(() => _style = st.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: active ? HiColors.brandGradient : null,
                            color: active ? null : HiColors.bgElevated2,
                            borderRadius: BorderRadius.circular(HiRadius.pill),
                          ),
                          child: Text(st.label,
                              style: TextStyle(
                                  color: active ? HiColors.textOnBrand : HiColors.textSecondary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CHOISIS TON VISAGE',
                          style: HiType.caption.copyWith(
                              color: HiColors.textTertiary, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      TextButton.icon(
                        onPressed: () {
                          HiHaptics.tap();
                          _shuffle();
                        },
                        icon: const Icon(Icons.casino_rounded, size: 18),
                        label: const Text('Surprends-moi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: HiSpace.sm),
                  Wrap(spacing: 12, runSpacing: 12, children: _variations.map(_thumb).toList()),
                  const SizedBox(height: HiSpace.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiColors.brandPrimary,
                        foregroundColor: HiColors.textOnBrand,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Valider mon athlète'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _thumb(String seed) {
    final selected = seed == _seed;
    return GestureDetector(
      onTap: () {
        HiHaptics.tap();
        setState(() => _seed = seed);
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HiColors.bgElevated2,
          border: Border.all(
            color: selected ? HiColors.brandPrimary : HiColors.strokeSubtle,
            width: selected ? 3 : 1,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            diceBearUrl(style: _style, seed: seed, size: 128),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
            loadingBuilder: (ctx, child, p) => p == null
                ? child
                : const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
      ),
    );
  }
}
