import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/hi_avatar.dart';

/// Bloc réutilisable de personnalisation d'avatar (aperçu + sélecteurs). Utilisé à l'onboarding
/// et dans les paramètres. Émet la nouvelle config à chaque changement.
class AvatarCustomizer extends StatelessWidget {
  final AvatarConfig config;
  final String rank;
  final ValueChanged<AvatarConfig> onChanged;
  const AvatarCustomizer({super.key, required this.config, required this.onChanged, this.rank = 'rookie'});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: HiAvatar(config: config, rank: rank, size: 150)),
        const SizedBox(height: HiSpace.lg),
        _label('Teint'),
        _swatches(AvatarPalettes.skin, config.skinTone, (i) => onChanged(config.copyWith(skinTone: i))),
        const SizedBox(height: HiSpace.lg),
        _label('Couleur des cheveux'),
        _swatches(AvatarPalettes.hair, config.hairColor, (i) => onChanged(config.copyWith(hairColor: i))),
        const SizedBox(height: HiSpace.lg),
        _label('Coupe'),
        _chips(AvatarPalettes.hairStyleLabels, config.hairStyle, (i) => onChanged(config.copyWith(hairStyle: i))),
        const SizedBox(height: HiSpace.lg),
        _label('Barbe'),
        _chips(AvatarPalettes.beardStyleLabels, config.beardStyle ?? 0,
            (i) => onChanged(config.copyWith(beardStyle: i, clearBeard: i == 0))),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: HiSpace.sm),
        child: Text(t, style: HiType.overline.copyWith(color: HiColors.textSecondary)),
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
          side: BorderSide(color: HiColors.strokeSubtle),
          onSelected: (_) => onTap(i),
        );
      }),
    );
  }
}
