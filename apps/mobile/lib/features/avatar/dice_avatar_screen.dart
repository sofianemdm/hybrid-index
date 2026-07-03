import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart'; // avatarProvider + myProfileProvider
import '../../data/api_client.dart';
import '../../data/dicebear.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/net_avatar_image.dart';
import '../../data/session.dart';
import '../../theme/haptics.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_skeleton.dart';
import '../../widgets/celebration.dart';
import '../../widgets/hi_avatar.dart';

// Hex 'rrggbb' → Color, SANS décalage de bits (web-safe) : on parse chaque composante (0-255).
Color _hexColor(String hex) => Color.fromARGB(
      255,
      int.parse(hex.substring(0, 2), radix: 16),
      int.parse(hex.substring(2, 4), radix: 16),
      int.parse(hex.substring(4, 6), radix: 16),
    );

/// Éditeur d'avatar premium (DiceBear avataaars) — RÉUTILISABLE : aperçu live, onglets de catégorie
/// (peau, coupe, couleur, barbe + couleur de barbe, lunettes, yeux, bouche, sourcils), « Surprends-moi ».
/// N'enregistre RIEN : émet l'`AvatarConfig` choisi via [onChanged] (l'appelant décide quoi en faire).
/// Utilisé à l'onboarding (création de compte) et dans les Réglages.
class DiceAvatarEditor extends StatefulWidget {
  final String sex; // 'male' | 'female' → coupes/barbe différenciées
  final AvatarConfig initial; // avatar de départ (options dice si déjà présentes)
  final String rank; // pour le cadre de rang de l'aperçu
  final ValueChanged<AvatarConfig> onChanged;

  const DiceAvatarEditor({
    super.key,
    required this.sex,
    required this.initial,
    this.rank = 'rookie',
    required this.onChanged,
  });

  @override
  State<DiceAvatarEditor> createState() => _DiceAvatarEditorState();
}

class _DiceAvatarEditorState extends State<DiceAvatarEditor> {
  final _rng = Random();
  late Map<String, String> _options;
  late List<DiceCategory> _categories;
  late String _seed;
  int _cat = 0; // catégorie active

  @override
  void initState() {
    super.initState();
    _categories = avataaarsCategoriesFor(widget.sex);
    _options = Map<String, String>.from(avataaarsDefaultsFor(widget.sex));
    final init = widget.initial;
    if (init.diceOptions != null && init.diceOptions!.isNotEmpty) {
      _options = {...avataaarsDefaultsFor(widget.sex), ...init.diceOptions!};
    }
    _seed = (init.diceSeed != null && init.diceSeed!.isNotEmpty)
        ? init.diceSeed!
        : _rng.nextInt(1000000000).toRadixString(36);
    // Émet l'état initial pour que l'appelant dispose tout de suite d'un avatar DiceBear complet
    // (style + seed + options) — y compris quand `initial` n'avait pas encore de données dice.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  AvatarConfig _build() => widget.initial.copyWith(
        diceStyle: kAvataaarsStyle,
        diceSeed: _seed,
        diceOptions: _options,
      );

  void _emit() => widget.onChanged(_build());

  void _surprise() {
    HiHaptics.tap();
    setState(() {
      for (final c in _categories) {
        _options[c.key] = c.options[_rng.nextInt(c.options.length)].value;
      }
      _options['facialHairColor'] = kBeardColors[_rng.nextInt(kBeardColors.length)].value;
    });
    _emit();
  }

  void _pick(String key, String value) {
    HiHaptics.tap();
    setState(() => _options[key] = value);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _build();
    final cat = _categories[_cat];
    // Aperçu + onglets FIXES en haut, options juste en dessous (Expanded) → la palette de couleurs /
    // les formes apparaissent immédiatement sous l'avatar, sans avoir à scroller.
    return Column(
      children: [
        const SizedBox(height: HiSpace.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _surprise,
            icon: const Icon(Icons.casino_rounded, size: 18),
            label: Text(AppLocalizations.of(context).avatarSurpriseMe),
          ),
        ),
        // Aperçu live (pop à chaque changement).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: HiAvatar(
            key: ValueKey('${_seed}_${_options.values.join('-')}'),
            config: preview,
            rank: widget.rank,
            size: 110,
          ),
        ),
        const SizedBox(height: HiSpace.sm),
        // Onglets en GRILLE (Wrap) : TOUTES les catégories visibles d'un coup, sur 2 lignes —
        // le défilement horizontal cachait Lunettes/Yeux/Bouche/Sourcils et personne ne devinait
        // qu'il fallait glisser (retour utilisateur 03/07).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [for (var i = 0; i < _categories.length; i++) _catChip(i)],
          ),
        ),
        const SizedBox(height: HiSpace.sm),
        // Options de la catégorie active : JUSTE sous l'avatar, occupent le reste et défilent si besoin.
        Expanded(child: _optionsArea(cat)),
      ],
    );
  }

  Widget _optionsArea(DiceCategory cat) {
    if (cat.key == 'facialHair') return _beardSection(cat); // styles + couleur de barbe
    return cat.isColor ? _colorGrid(cat) : _thumbGrid(cat);
  }

  Widget _catChip(int i) {
    final active = i == _cat;
    return GestureDetector(
      onTap: () {
        HiHaptics.tap();
        setState(() => _cat = i);
      },
      child: Container(
        // PAS d'alignment ici : dans un Wrap, un Container aligne s'etend a toute la largeur
        // (chips empilees pleine ligne). Le padding centre deja le texte.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? HiColors.brandGradient : null,
          color: active ? null : HiColors.bgElevated2,
          borderRadius: BorderRadius.circular(HiRadius.pill),
        ),
        child: Text(_categories[i].label,
            style: TextStyle(
                color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // Pastille de couleur réutilisable (peau, couleur de cheveux, couleur de barbe).
  Widget _colorDot(String key, DiceOption o, {double? size}) {
    final selected = _options[key] == o.value;
    return GestureDetector(
      onTap: () => _pick(key, o.value),
      child: Container(
        width: size,
        height: size,
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
  }

  // Pastilles de couleur (peau, couleur de cheveux).
  Widget _colorGrid(DiceCategory cat) {
    return GridView.count(
      crossAxisCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: HiSpace.lg),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: cat.options.map((o) => _colorDot(cat.key, o)).toList(),
    );
  }

  // Onglet « Barbe » : styles (vignettes) + rangée de couleurs de barbe.
  Widget _beardSection(DiceCategory cat) {
    final beardOff = _options['facialHair'] == 'none';
    return Column(
      children: [
        Expanded(child: _thumbGrid(cat)),
        Padding(
          padding: const EdgeInsets.fromLTRB(HiSpace.lg, HiSpace.sm, HiSpace.lg, HiSpace.md),
          child: Opacity(
            opacity: beardOff ? 0.4 : 1, // sans effet visible tant qu'aucune barbe n'est choisie
            child: Row(
              children: [
                Text(AppLocalizations.of(context).avatarColorLabel,
                    style: TextStyle(color: HiColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 14),
                for (final o in kBeardColors)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _colorDot('facialHairColor', o, size: 34),
                  ),
              ],
            ),
          ),
        ),
      ],
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
              // Cache disque sur mobile : rouvrir l'éditeur n'exige plus de re-télécharger toutes
              // les vignettes (elles s'affichent instantanément dès la 2e visite).
              child: NetAvatarImage(
                avataaarsUrl(options: opts, seed: _seed, size: 120),
                placeholder: (_) => Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.brandPrimary))),
                error: (_) => const SizedBox(),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Écran plein (Réglages) : enveloppe [DiceAvatarEditor] avec sauvegarde sur le compte + célébration.
class DiceAvatarScreen extends ConsumerStatefulWidget {
  const DiceAvatarScreen({super.key});

  @override
  ConsumerState<DiceAvatarScreen> createState() => _DiceAvatarScreenState();
}

class _DiceAvatarScreenState extends ConsumerState<DiceAvatarScreen> {
  AvatarConfig _base = const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  AvatarConfig _current = const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  String _sex = 'male';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sex = ref.read(sessionProvider).sex ?? 'male';
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await ref.read(apiClientProvider).getAvatar();
      if (!mounted) return;
      setState(() {
        _base = a;
        _current = a;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateAvatar(_current);
      ref.invalidate(avatarProvider);
      if (!mounted) return;
      HiHaptics.celebrate();
      await Celebration.show(
        context,
        title: AppLocalizations.of(context).avatarReadyTitle,
        subtitle: AppLocalizations.of(context).avatarReadyBody,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).avatarForgeTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const HiListSkeleton(count: 4, itemHeight: 96)
            : Column(
                children: [
                  Expanded(
                    child: DiceAvatarEditor(
                      sex: _sex,
                      initial: _base,
                      rank: rank,
                      onChanged: (c) => _current = c,
                    ),
                  ),
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
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: HiColors.textOnBrand))
                            : Text(AppLocalizations.of(context).avatarValidate),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
