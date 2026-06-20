import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';
import '../../widgets/hi_button.dart';

/// Éditeur d'avatar : peau, cheveux (style + couleur), barbe. Création en quelques secondes.
class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends ConsumerState<AvatarEditorScreen> {
  AvatarConfig _config = const AvatarConfig(skinTone: 2, hairStyle: 1, hairColor: 1);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await ref.read(apiClientProvider).getAvatar();
      setState(() {
        _config = a;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateAvatar(_config);
      ref.invalidate(avatarProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rank = ref.watch(myProfileProvider).value?.index.rank ?? 'rookie';
    return Scaffold(
      appBar: AppBar(title: const Text('Mon avatar'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(HiSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: HiAvatar(config: _config, rank: rank, size: 160)),
                      const SizedBox(height: HiSpace.lg),
                      _label('Teint'),
                      _swatches(
                        AvatarPalettes.skin,
                        _config.skinTone,
                        (i) => setState(() => _config = _config.copyWith(skinTone: i)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _label('Couleur des cheveux'),
                      _swatches(
                        AvatarPalettes.hair,
                        _config.hairColor,
                        (i) => setState(() => _config = _config.copyWith(hairColor: i)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _label('Coupe'),
                      _chips(
                        AvatarPalettes.hairStyleLabels,
                        _config.hairStyle,
                        (i) => setState(() => _config = _config.copyWith(hairStyle: i)),
                      ),
                      const SizedBox(height: HiSpace.lg),
                      _label('Barbe'),
                      _chips(
                        AvatarPalettes.beardStyleLabels,
                        _config.beardStyle ?? 0,
                        (i) => setState(() => _config = _config.copyWith(beardStyle: i, clearBeard: i == 0)),
                      ),
                      const SizedBox(height: HiSpace.xl),
                      HiButton(label: 'Enregistrer mon avatar', loading: _saving, onPressed: _save),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t, style: const TextStyle(color: HiColors.textSecondary, fontSize: 13)),
      );

  Widget _swatches(List<Color> colors, int selected, ValueChanged<int> onTap) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(colors.length, (i) {
        final active = i == selected;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(color: active ? HiColors.brandPrimary : HiColors.strokeSubtle, width: active ? 3 : 1),
            ),
          ),
        );
      }),
    );
  }

  Widget _chips(List<String> labels, int selected, ValueChanged<int> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (i) {
        final active = i == selected;
        return ChoiceChip(
          label: Text(labels[i]),
          selected: active,
          showCheckmark: false,
          selectedColor: HiColors.brandPrimary,
          backgroundColor: HiColors.bgElevated2,
          labelStyle: TextStyle(color: active ? HiColors.textOnBrand : HiColors.textSecondary, fontWeight: FontWeight.w600),
          side: const BorderSide(color: HiColors.strokeSubtle),
          onSelected: (_) => onTap(i),
        );
      }),
    );
  }
}
