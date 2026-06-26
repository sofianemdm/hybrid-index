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

/// Éditeur d'avatar premium (DiceBear avataaars) — création 100 % personnalisée en ~30 s :
/// peau, coupe, couleur, barbe, lunettes, yeux. Aperçu live, « Surprends-moi », sauvegarde compte.
class DiceAvatarScreen extends ConsumerStatefulWidget {
  const DiceAvatarScreen({super.key});

  @override
  ConsumerState<DiceAvatarScreen> createState() => _DiceAvatarScreenState();
}

// Hex 'rrggbb' → Color, SANS décalage de bits (web-safe) : on parse chaque composante (0-255).
Color _hexColor(String hex) => Color.fromARGB(
      255,
      int.parse(hex.substring(0, 2), radix: 16),
      int.parse(hex.substring(2, 4), radix: 16),
      int.parse(hex.substring(4, 6), radix: 16),
    );

class _DiceAvatarScreenState extends ConsumerState<DiceAvatarScreen> {
  final _rng = Random();
  AvatarConfig _base = const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  late Map<String, String> _options;
  late String _seed;
  int _cat = 0; // catégorie active
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _options = Map<String, String>.from(kAvataaarsDefaults);
    _seed = _rng.nextInt(1000000000).toRadixString(36);
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await ref.read(apiClientProvider).getAvatar();
      if (!mounted) return;
      setState(() {
        _base = a;
        if (a.diceOptions != null && a.diceOptions!.isNotEmpty) {
          _options = {...kAvataaarsDefaults, ...a.diceOptions!};
        }
        if (a.diceSeed != null && a.diceSeed!.isNotEmpty) _seed = a.diceSeed!;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _surprise() {
    HiHaptics.tap();
    setState(() {
      for (final c in kAvataaarsCategories) {
        _options[c.key] = c.options[_rng.nextInt(c.options.length)].value;
      }
    });
  }

  void _pick(String key, String value) {
    HiHaptics.tap();
    setState(() => _options[key] = value);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cfg = _base.copyWith(diceStyle: kAvataaarsStyle, diceSeed: _seed, diceOptions: _options);
      await ref.read(apiClientProvider).updateAvatar(cfg);
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
    final preview = _base.copyWith(diceStyle: kAvataaarsStyle, diceSeed: _seed, diceOptions: _options);
    final cat = kAvataaarsCategories[_cat];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forge ton athlète'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _surprise,
            icon: const Icon(Icons.casino_rounded, size: 18),
            label: const Text('Surprends-moi'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: HiColors.brandPrimary))
            : Column(
                children: [
                  const SizedBox(height: HiSpace.md),
                  // Aperçu live (pop à chaque changement).
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0)
                          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: HiAvatar(
                      key: ValueKey(_options.values.join('-')),
                      config: preview,
                      rank: rank,
                      size: 150,
                    ),
                  ),
                  const SizedBox(height: HiSpace.lg),
                  // Onglets de catégorie.
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
                      itemCount: kAvataaarsCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _catChip(i),
                    ),
                  ),
                  const SizedBox(height: HiSpace.md),
                  // Options de la catégorie active.
                  Expanded(
                    child: cat.isColor ? _colorGrid(cat) : _thumbGrid(cat),
                  ),
                  // Valider.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.sm, HiSpace.lg, HiSpace.md),
                    child: SizedBox(
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
                  ),
                ],
              ),
      ),
    );
  }

  Widget _catChip(int i) {
    final active = i == _cat;
    return GestureDetector(
      onTap: () {
        HiHaptics.tap();
        setState(() => _cat = i);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active ? HiColors.brandGradient : null,
          color: active ? null : HiColors.bgElevated2,
          borderRadius: BorderRadius.circular(HiRadius.pill),
        ),
        child: Text(kAvataaarsCategories[i].label,
            style: TextStyle(
                color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // Pastilles de couleur (peau, couleur de cheveux).
  Widget _colorGrid(DiceCategory cat) {
    return GridView.count(
      crossAxisCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: cat.options.map((o) {
        final selected = _options[cat.key] == o.value;
        return GestureDetector(
          onTap: () => _pick(cat.key, o.value),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hexColor(o.value),
              border: Border.all(
                color: selected ? HiColors.brandPrimary : HiColors.strokeSubtle,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Vignettes d'avatar (coupe, barbe, lunettes, yeux) : on voit l'effet sur SON avatar.
  Widget _thumbGrid(DiceCategory cat) {
    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: cat.options.map((o) {
        final selected = _options[cat.key] == o.value;
        final opts = {..._options, cat.key: o.value};
        return GestureDetector(
          onTap: () => _pick(cat.key, o.value),
          child: Container(
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
                avataaarsUrl(options: opts, seed: _seed, size: 120),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
                loadingBuilder: (ctx, child, p) => p == null
                    ? child
                    : const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
